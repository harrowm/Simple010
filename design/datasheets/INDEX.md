# Simple010 Component Datasheets

Datasheets for all active components on the Simple010 board.
LCSC numbers are for JLCPCB ordering. Mouser numbers are for Mouser ordering.

## ICs

| Ref | Value | LCSC | Mouser | Datasheet |
|-----|-------|------|--------|-----------|
| U10 | MC68010P — 68010 CPU | — | — | [MC68010.pdf](MC68010.pdf) |
| U2 | ATF1508AS — CPLD PLCC84 | — | — | [ATF1508AS.pdf](ATF1508AS.pdf) |
| U14, U15 | SST39SF040 — 4Mb Flash ROM | — | — | [SST39SF040.pdf](SST39SF040.pdf) |
| U16, U17 | AS6C4008-55PCN — 512K×8 SRAM | C62646 | 913-AS6C4008-55PCN | [AS6C4008.pdf](AS6C4008.pdf) |
| U1 | MCP2221A — USB↔UART/I²C bridge | C640876 | 579-MCP2221A-I/SL | [MCP2221A.pdf](MCP2221A.pdf) |
| U9 | USBLC6-2SC6 — USB ESD protection | C7519 | 511-USBLC6-2SC6 | [USBLC6-2SC6.pdf](USBLC6-2SC6.pdf) |
| U11 | UM809SS — 2.93V reset supervisor SOT-23 | — | — | [UM809SS.pdf](UM809SS.pdf) |

## Oscillators

| Ref | Value | LCSC | Mouser | Datasheet |
|-----|-------|------|--------|-----------|
| Y4 | SG-5032CAN 10MHz (ECS-3961-100) — CPU clock | C41361451 | ECS-3961-100-AU-TR | [ECS-3961_SG-5032CAN.pdf](ECS-3961_SG-5032CAN.pdf) |
| Y3 | SG-5032CAN 3.6864MHz (ECS-3961-036) — UART baud clock | C5382652 | ECS-3961-036-AU-TR | [ECS-3961_SG-5032CAN.pdf](ECS-3961_SG-5032CAN.pdf) |

## LEDs

| Ref | Value | LCSC | Mouser | Datasheet |
|-----|-------|------|--------|-----------|
| LED1, LED9 | LTST-C170KGKT — 0805 Green LED | C961277 | LTST-C170KGKT | [LTST-C170KGKT.pdf](LTST-C170KGKT.pdf) |
| LED2, LED10 | LTST-C170KRKT — 0805 Red LED | C961276 | LTST-C170KRKT | [LTST-C170KRKT.pdf](LTST-C170KRKT.pdf) |

## Switches & Connectors

| Ref | Value | LCSC | Mouser | Datasheet |
|-----|-------|------|--------|-----------|
| SW1 | XKB TS-1187A-B-A-B — 5.1×5.1mm SMD tact switch | C318884 | — | [TS-1187A_SW1.pdf](TS-1187A_SW1.pdf) |
| J3 | Korean Hroparts TYPE-C-31-M-12 — USB-C receptacle 16P | C165948 | — | [TYPE-C-31-M-12_USB-C.pdf](TYPE-C-31-M-12_USB-C.pdf) |

## Passives (0805, Yageo/KEMET/Samsung)

| Value | LCSC | Mouser |
|-------|------|--------|
| 100nF MLCC X7R | C1711 / C49678 | CL21B104KBCNNNC / 603-CC0805KRX7R9BB104 |
| 100pF MLCC NP0 | C62768 | 603-CC0805JRNPO9BN101 |
| 470nF MLCC X7R | C106846 | 603-CC0805KKX7R8BB474 |
| 10uF MLCC X5R | C89827 | 603-CC0805KKX5R7BB106 |
| 47uF electrolytic | C135808 | J32MLB7476MPPDTJ |
| 1kΩ 1% | C17512 | ERJ-6ENF1001V |
| 1.2kΩ 1% | C17512 | CRCW08051K20FKEA |
| 4.7kΩ 1% | C17515 | ERJ-6ENF4701V |
| 5.1kΩ 1% | C84375 | 603-RC0805FR-075K1L |
| 10kΩ 1% | C84376 | 603-RC0805FR-0710KL |
| 1MΩ 1% | C107700 | 603-RC0805FR-071ML |

---

## Notes

**ATF1508AS LCSC:** The ATF1508AS-15JU84 (PLCC84, 5V, 15ns) is not stocked on LCSC/JLCPCB. Order directly from Microchip or via a distributor such as Mouser (556-AF1508AS15JU84) or DigiKey.

**MC68010P LCSC:** Not available on LCSC. Source from eBay/second-hand market, or Mouser (was stocked as NXP MC68010P10, now EOL).
