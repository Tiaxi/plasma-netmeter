.pragma library

// All rates come in as bytes per second.

function _units(bits, binary) {
    if (bits)
        return binary ? ["bps", "Kibps", "Mibps", "Gibps", "Tibps"] : ["bps", "kbps", "Mbps", "Gbps", "Tbps"];
    return binary ? ["B", "KiB", "MiB", "GiB", "TiB"] : ["B", "kB", "MB", "GB", "TB"];
}

// Short single-letter units for the panel.
function _short(bits) {
    return bits ? ["b", "k", "M", "G", "T"] : ["B", "K", "M", "G", "T"];
}

// Split a value into [mantissa, unitIndex] with at most 3 integer digits.
function _split(v, binary) {
    const base = binary ? 1024 : 1000;
    let i = 0;
    while (v >= 999.5 && i < 4) {
        v /= base;
        i++;
    }
    return [v, i];
}

function _num(v, unitIndex) {
    if (unitIndex === 0)
        return Math.round(v).toString();
    if (v < 9.995)
        return v.toFixed(2);
    if (v < 99.95)
        return v.toFixed(1);
    return Math.round(v).toString();
}

// Panel text: { num: "12.3", unit: "M" }
// decimals < 0: automatic (3 significant digits); otherwise fixed decimals
// (plain bytes/bits are always shown as integers).
function compact(bytesPerSec, bits, binary, decimals) {
    const v0 = Math.max(0, bytesPerSec) * (bits ? 8 : 1);
    if (decimals === undefined || decimals < 0) {
        const s = _split(v0, binary);
        return { num: _num(s[0], s[1]), unit: _short(bits)[s[1]] };
    }
    const base = binary ? 1024 : 1000;
    let v = v0, i = 0;
    // Move to the next unit once the rounded text would need 4 integer digits.
    while (i < 4 && Number(v.toFixed(i === 0 ? 0 : decimals)) >= 1000) {
        v /= base;
        i++;
    }
    return { num: v.toFixed(i === 0 ? 0 : decimals), unit: _short(bits)[i] };
}

function _suffix(bits) {
    return bits ? "" : "/s";
}

// Full text: "12.3 MB/s" or "98.4 Mbps"
function rate(bytesPerSec, bits, binary) {
    const s = _split(Math.max(0, bytesPerSec) * (bits ? 8 : 1), binary);
    return _num(s[0], s[1]) + " " + _units(bits, binary)[s[1]] + _suffix(bits);
}

// Axis label: like rate() but trims trailing zeros ("10 Mbit/s", "2.5 MB/s")
function axis(bytesPerSec, bits, binary) {
    const s = _split(Math.max(0, bytesPerSec) * (bits ? 8 : 1), binary);
    const n = parseFloat(s[0].toPrecision(3)).toString();
    return n + " " + _units(bits, binary)[s[1]] + _suffix(bits);
}

// Data amount: "1.23 GB"
function size(bytes, binary) {
    const s = _split(Math.max(0, bytes), binary);
    return _num(s[0], s[1]) + " " + _units(false, binary)[s[1]];
}

// A "nice" grid step (in bytes/s) so that `lines` steps cover maxBytes,
// with round labels in the display unit system.
function niceStep(maxBytes, lines, bits, binary) {
    const mul = bits ? 8 : 1;
    const base = binary ? 1024 : 1000;
    const raw = Math.max(maxBytes * mul / lines, 1);
    let p = Math.pow(base, Math.max(0, Math.floor(Math.log(raw) / Math.log(base))));
    const m = raw / p; // 1 .. base
    const mags = Math.pow(10, Math.floor(Math.log10(m)));
    const f = m / mags;
    const nice = f <= 1 ? 1 : f <= 2 ? 2 : f <= 2.5 ? 2.5 : f <= 5 ? 5 : 10;
    return nice * mags * p / mul;
}

function ago(seconds) {
    seconds = Math.round(seconds);
    if (seconds < 60)
        return "-" + seconds + "s";
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return "-" + m + "m" + (s ? " " + s + "s" : "");
}
