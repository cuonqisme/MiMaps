# Xiaomi Smart Band 9 symbol compatibility matrix

Status: **physical hardware testing pending**. Do not change `Works` to Yes until the exact glyph has appeared correctly on a real paired Smart Band 9.

Test context:

- App version/build:
- iPhone/iOS:
- Mi Fitness version:
- Band firmware:
- Test date:
- Phone locked/backgrounded:

| Symbol | Expected maneuver | Actual rendering | Works | Vibration | Vietnamese text | Approx. latency | Notes |
|---|---|---|---|---|---|---|---|
| ↑ | Straight | Pending | Untested | Untested | Untested | — | |
| ← | Left | Pending | Untested | Untested | Untested | — | |
| → | Right | Pending | Untested | Untested | Untested | — | |
| ↖ | Slight left | Pending | Untested | Untested | Untested | — | |
| ↗ | Slight right | Pending | Untested | Untested | Untested | — | |
| ● | Destination | Pending | Untested | Untested | Untested | — | |

The app intentionally does not send `↰`, `↱`, `↶`, `↷`, `⟳`, angle brackets, or carets because earlier Mi Band 9 testing rendered some of them as square glyphs. These maneuvers use the safe arrows above and always include an explicit Vietnamese label:

| Maneuver | Band symbol | Required label |
|---|---|---|
| Sharp left | ← | `Rẽ gấp trái` |
| Sharp right | → | `Rẽ gấp phải` |
| U-turn left | ← | `Quay đầu trái` |
| U-turn right | → | `Quay đầu phải` |
| Roundabout | ↑ | `Vòng xuyến` or `Lối ra N` |

Also record results for 30 m, 80 m, 200 m, 500 m, 1 km, 2 km and road names `Trần Phú`, `Lê Thánh Tông`, and `QL18`.
