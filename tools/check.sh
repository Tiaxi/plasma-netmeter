#!/usr/bin/env bash
# Runs the same checks as CI. Needs Qt 6 declarative dev tools, the Plasma 6
# QML modules the widget imports, kconfig_compiler_kf6, kpackagetool6, jq and
# xmllint. Usage: tools/check.sh [step...]   (steps: metadata config lint test install)
set -euo pipefail

cd "$(dirname "$0")/.."
PKG=package
QT_BIN=${QT_BIN:-/usr/lib64/qt6/bin}
KF_LIBEXEC=${KF_LIBEXEC:-/usr/libexec/kf6}

tool() {
    command -v "$1" 2>/dev/null || { [[ -x "$2/$1" ]] && echo "$2/$1"; } || {
        echo "error: $1 not found (looked in PATH and $2)" >&2
        return 1
    }
}

step_metadata() {
    echo "== metadata.json"
    jq -e '
        .KPackageStructure == "Plasma/Applet"
        and (.KPlugin.Id | type == "string" and test("^[a-z0-9.]+$"))
        and (.KPlugin.Name | type == "string" and length > 0)
        and (.KPlugin.Version | type == "string" and test("^[0-9]+(\\.[0-9]+)*$"))
        and (.KPlugin.License | type == "string" and length > 0)
    ' "$PKG/metadata.json" >/dev/null || {
        echo "metadata.json is missing a field or has an invalid one" >&2
        return 1
    }
}

step_config() {
    echo "== config/main.xml"
    local xml=$PKG/contents/config/main.xml
    xmllint --noout "$xml"

    # kconfig_compiler reports bad types and defaults on stderr but still exits 0.
    local compiler tmp
    compiler=$(tool kconfig_compiler_kf6 "$KF_LIBEXEC")
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' RETURN
    printf 'File=main.xml\nClassName=Check\n' >"$tmp/check.kcfgc"
    (cd "$tmp" && "$compiler" "$OLDPWD/$xml" check.kcfgc) 2>"$tmp/err" || true
    if [[ -s $tmp/err ]]; then
        sort -u "$tmp/err" >&2
        return 1
    fi

    # Every cfg_ property in the settings pages and every cfg.<key> read must
    # name an entry in main.xml, or the setting silently does nothing.
    local entries missing=0 key
    entries=$(grep -oE 'entry name="[^"]+"' "$xml" | cut -d'"' -f2 | sort -u)
    while read -r key; do
        grep -qxF "$key" <<<"$entries" && continue
        [[ $key == *Default ]] && grep -qxF "${key%Default}" <<<"$entries" && continue
        echo "unknown config key: $key" >&2
        missing=1
    done < <({
        grep -ohE '\bcfg_[A-Za-z0-9_]+' "$PKG"/contents/ui/*.qml | sed 's/^cfg_//'
        grep -ohE '\bcfg\.[A-Za-z0-9_]+' "$PKG"/contents/ui/*.qml | sed 's/^cfg\.//'
    } | sort -u)
    return $missing
}

step_lint() {
    echo "== qmllint"
    local qmllint
    qmllint=$(tool qmllint "$QT_BIN")
    # Config pages read cfg_* and the plasmoid context unqualified by design,
    # so that category is noise. A failed import means the widget won't load.
    "$qmllint" --import error --unqualified disable \
        "$PKG"/contents/ui/*.qml "$PKG"/contents/config/*.qml
}

step_test() {
    echo "== tests"
    local runner
    runner=$(tool qmltestrunner "$QT_BIN")
    QT_QPA_PLATFORM=${QT_QPA_PLATFORM:-offscreen} "$runner" -input tests
}

step_install() {
    echo "== kpackagetool6 install"
    local tmp id
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' RETURN
    id=$(jq -r .KPlugin.Id "$PKG/metadata.json")
    # A throwaway home so this never touches a real installation.
    env HOME="$tmp" XDG_DATA_HOME="$tmp/data" XDG_CONFIG_HOME="$tmp/config" \
        XDG_CACHE_HOME="$tmp/cache" \
        bash -c '
            kpackagetool6 -t Plasma/Applet -i "$1" &&
            kpackagetool6 -t Plasma/Applet --show "$2"
        ' _ "$PKG" "$id"
    [[ -f $tmp/data/plasma/plasmoids/$id/contents/ui/main.qml ]] || {
        echo "package did not install to the expected place" >&2
        return 1
    }
}

steps=("$@")
((${#steps[@]})) || steps=(metadata config lint test install)
for s in "${steps[@]}"; do
    "step_$s"
done
echo "All checks passed."
