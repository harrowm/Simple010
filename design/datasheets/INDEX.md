# Simple010 Component Datasheets

Datasheets for all active components on the Simple010 board.
LCSC numbers are for JLCPCB ordering. Mouser numbers are for Mouser ordering.

## ICs

| Ref | Value | LCSC | Mouser | Datasheet |
|-----|-------|------|--------|-----------|
| U1 | MC68010P — 68010 CPU | — | — | [MC68010.pdf](MC68010.pdf) |
| U2 | ATF1508AS — CPLD PLCC84 | — | — | [ATF1508AS.pdf](ATF1508AS.pdf) |
| U3, U4 | SST39SF040 — 4Mb Flash ROM PLCC-32 | — (PLCC-32 not stocked on LCSC) | 579-SST39SF040-70-4I-NHE | [SST39SF040.pdf](SST39SF040.pdf) |
| U5, U6 | AS6C4008-55PCN — 512K×8 SRAM | C1350141 (OOS) | 913-AS6C4008-55PCN | [AS6C4008.pdf](AS6C4008.pdf) |
| U8 | MCP2221A — USB↔UART/I²C bridge | C640876 | 579-MCP2221A-I/SL | [MCP2221A.pdf](MCP2221A.pdf) |
| U7 | USBLC6-2SC6 — USB ESD protection | C7519 | 511-USBLC6-2SC6 | [USBLC6-2SC6.pdf](USBLC6-2SC6.pdf) |
| U9 | LM809M3-4.63/NOPB — 4.63V reset supervisor SOT-23 | C2066444 | 595-LM809M3-4.63NOPB | [LM809.pdf](LM809.pdf) |

## Oscillators

| Ref | Value | LCSC | Mouser | Datasheet |
|-----|-------|------|--------|-----------|
| Y1 | SG-5032CAN 10MHz (ECS-3961-100) — CPU clock | C41361451 | ECS-3961-100-AU-TR | [ECS-3961_SG-5032CAN.pdf](ECS-3961_SG-5032CAN.pdf) |
| Y2 | SG-5032CAN 3.6864MHz (ECS-3961-036) — UART baud clock | C5382652 | ECS-3961-036-AU-TR | [ECS-3961_SG-5032CAN.pdf](ECS-3961_SG-5032CAN.pdf) |

## LEDs

| Ref | Value | LCSC | Mouser | Datasheet |
|-----|-------|------|--------|-----------|
| LED1, LED3 | LTST-C170KGKT — 0805 Green LED | C961277 | LTST-C170KGKT | [LTST-C170KGKT.pdf](LTST-C170KGKT.pdf) |
| LED2, LED4 | LTST-C170KRKT — 0805 Red LED | C961276 | LTST-C170KRKT | [LTST-C170KRKT.pdf](LTST-C170KRKT.pdf) |

## Switches & Connectors

| Ref | Value | LCSC | Mouser | Datasheet |
|-----|-------|------|--------|-----------|
| SW1 | XKB TS-1187A-B-A-B — 5.1×5.1mm SMD tact switch | C318884 | — | [TS-1187A_SW1.pdf](TS-1187A_SW1.pdf) |
| J3 | Korean Hroparts TYPE-C-31-M-12 — USB-C receptacle 16P | C165948 | — | [TYPE-C-31-M-12_USB-C.pdf](TYPE-C-31-M-12_USB-C.pdf) |

## Passives (all 0805 unless noted)

All passives are JLCPCB **Basic** parts — no extended part setup fees.
UNI-ROYAL resistors are sold as "Royalohm" on Mouser; search by manufacturer PN.

| Value | Refs | LCSC | Manufacturer PN | Mouser |
|-------|------|------|-----------------|--------|
| 100nF MLCC X7R | C1–C3, C5–C17, C20–C22, C24 | C49678 | Yageo CC0805KRX7R9BB104 | 603-CC0805KRX7R9BB104 |
| 100pF MLCC C0G/NP0 | C23 | C1790 | Samsung CL21C101JBANNNC | 187-CL21C101JBANNNC |
| 470nF MLCC X7R | C25 | C13967 | Samsung CL21B474KBFNNNE | 187-CL21B474KBFNNNE |
| 10µF MLCC X5R 25V | C4, C19 | C15850 | Samsung CL21A106KAYNNNE | 187-CL21A106KAYNNNE |
| 47µF MLCC X5R 10V **1206** | C18 | C96123 | Samsung CL31A476MPHNNNE | 187-CL31A476MPHNNNE |
| 1kΩ 1% | R3, R4, R19–R21 | C17513 | UNI-ROYAL 0805W8F1001T5E | 0805W8F1001T5E |
| 1.2kΩ 1% | R5 | C17379 | UNI-ROYAL 0805W8F1201T5E | 0805W8F1201T5E |
| 4.7kΩ 1% | R6–R15, R22 | C17673 | UNI-ROYAL 0805W8F4701T5E | 0805W8F4701T5E |
| 5.1kΩ 1% | R17, R18 | C27834 | UNI-ROYAL 0805W8F5101T5E | 0805W8F5101T5E |
| 10kΩ 1% | R1, R2 | C17414 | UNI-ROYAL 0805W8F1002T5E | 0805W8F1002T5E |
| 1MΩ 1% | R16 | C17514 | UNI-ROYAL 0805W8F1004T5E | 0805W8F1004T5E |

---

## Notes

**ATF1508AS LCSC:** The ATF1508AS-15JU84 (PLCC84, 5V, 15ns) is not stocked on LCSC/JLCPCB. Order directly from Microchip or via a distributor such as Mouser (556-AF1508AS15JU84) or DigiKey.

**MC68010P LCSC:** Not available on LCSC. Source from eBay/second-hand market, or Mouser (was stocked as NXP MC68010P10, now EOL).

**Mouser numbers** correspond to the same manufacturer as the LCSC part throughout. UNI-ROYAL resistors are listed on Mouser under the Royalohm brand; search by manufacturer PN (e.g. 0805W8F4701T5E).
