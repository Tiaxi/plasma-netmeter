import QtQuick
import QtTest
import "../package/contents/ui/Format.js" as Fmt

TestCase {
    name: "Format"

    function test_rate_data() {
        return [
            { tag: "zero", bytes: 0, bits: false, binary: false, expected: "0 B/s" },
            { tag: "negative clamps to zero", bytes: -5, bits: false, binary: false, expected: "0 B/s" },
            { tag: "just below unit switch", bytes: 999, bits: false, binary: false, expected: "999 B/s" },
            { tag: "unit switch", bytes: 1000, bits: false, binary: false, expected: "1.00 kB/s" },
            { tag: "two decimals", bytes: 1234567, bits: false, binary: false, expected: "1.23 MB/s" },
            { tag: "one decimal", bytes: 12345678, bits: false, binary: false, expected: "12.3 MB/s" },
            { tag: "no decimals", bytes: 123456789, bits: false, binary: false, expected: "123 MB/s" },
            { tag: "rounds up into next unit", bytes: 999600, bits: false, binary: false, expected: "1.00 MB/s" },
            { tag: "bits", bytes: 1e6, bits: true, binary: false, expected: "8.00 Mbps" },
            { tag: "binary", bytes: 1024, bits: false, binary: true, expected: "1.00 KiB/s" },
            { tag: "binary bits", bytes: 128 * 1024, bits: true, binary: true, expected: "1.00 Mibps" },
            { tag: "stops at tera", bytes: 5e15, bits: false, binary: false, expected: "5000 TB/s" }
        ];
    }

    function test_rate(data) {
        compare(Fmt.rate(data.bytes, data.bits, data.binary), data.expected);
    }

    function test_compact_data() {
        return [
            { tag: "auto", bytes: 12345678, decimals: -1, num: "12.3", unit: "M" },
            { tag: "auto when undefined", bytes: 12345678, decimals: undefined, num: "12.3", unit: "M" },
            { tag: "auto plain bytes", bytes: 512, decimals: -1, num: "512", unit: "B" },
            { tag: "fixed 0", bytes: 12345678, decimals: 0, num: "12", unit: "M" },
            { tag: "fixed 2", bytes: 12345678, decimals: 2, num: "12.35", unit: "M" },
            { tag: "plain bytes stay integers", bytes: 500, decimals: 2, num: "500", unit: "B" },
            { tag: "rounding past 1000 switches unit", bytes: 999999, decimals: 1, num: "1.0", unit: "M" },
            { tag: "negative clamps to zero", bytes: -1, decimals: 1, num: "0", unit: "B" }
        ];
    }

    function test_compact(data) {
        const r = Fmt.compact(data.bytes, false, false, data.decimals);
        compare(r.num, data.num);
        compare(r.unit, data.unit);
    }

    function test_compact_bits() {
        const r = Fmt.compact(1e6, true, false);
        compare(r.num, "8.00");
        compare(r.unit, "M");
    }

    function test_axis_data() {
        return [
            { tag: "trims trailing zeros", bytes: 2.5e6, bits: false, expected: "2.5 MB/s" },
            { tag: "whole number", bytes: 1e6, bits: false, expected: "1 MB/s" },
            { tag: "bits", bytes: 1.25e6, bits: true, expected: "10 Mbps" },
            { tag: "zero", bytes: 0, bits: false, expected: "0 B/s" }
        ];
    }

    function test_axis(data) {
        compare(Fmt.axis(data.bytes, data.bits, false), data.expected);
    }

    function test_size_data() {
        return [
            { tag: "bytes", bytes: 42, binary: false, expected: "42 B" },
            { tag: "decimal giga", bytes: 1.5e9, binary: false, expected: "1.50 GB" },
            { tag: "binary giga", bytes: 1.5 * 1024 * 1024 * 1024, binary: true, expected: "1.50 GiB" },
            { tag: "has no /s suffix", bytes: 2e6, binary: false, expected: "2.00 MB" }
        ];
    }

    function test_size(data) {
        compare(Fmt.size(data.bytes, data.binary), data.expected);
    }

    function test_niceStep_data() {
        return [
            { tag: "2.5 step", max: 1e6, lines: 4, bits: false, binary: false, expected: 250000 },
            { tag: "2 step", max: 1e6, lines: 5, bits: false, binary: false, expected: 200000 },
            { tag: "rounds up to 10", max: 3e6, lines: 4, bits: false, binary: false, expected: 1e6 },
            { tag: "exact power of base", max: 4e6, lines: 4, bits: false, binary: false, expected: 1e6 },
            { tag: "empty graph", max: 0, lines: 4, bits: false, binary: false, expected: 1 },
            { tag: "bits give round bit labels", max: 1e6, lines: 4, bits: true, binary: false, expected: 250000 },
            { tag: "binary", max: 4 * 1024 * 1024, lines: 4, bits: false, binary: true, expected: 1024 * 1024 }
        ];
    }

    function test_niceStep(data) {
        const step = Fmt.niceStep(data.max, data.lines, data.bits, data.binary);
        fuzzyCompare(step, data.expected, data.expected * 1e-9);
        // The steps must always cover the whole range.
        verify(step * data.lines >= data.max * (1 - 1e-9));
    }

    function test_ago_data() {
        return [
            { tag: "zero", seconds: 0, expected: "-0s" },
            { tag: "seconds", seconds: 42, expected: "-42s" },
            { tag: "rounds to a minute", seconds: 59.6, expected: "-1m" },
            { tag: "minutes and seconds", seconds: 125, expected: "-2m 5s" },
            { tag: "whole minutes", seconds: 3600, expected: "-60m" }
        ];
    }

    function test_ago(data) {
        compare(Fmt.ago(data.seconds), data.expected);
    }
}
