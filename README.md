# Simple010

A 68010 single-board computer based on the [rosco_m68k r2](https://github.com/rosco-m68k/rosco_m68k) design. Simple010 replaces the six discrete glue-logic ICs from that design with a single **ATF1508AS PLCC84 CPLD**, reducing board complexity while adding hardware SPI acceleration for SD card access.

## Hardware overview

| Item | Detail |
|------|--------|
| CPU | Motorola MC68010P at 10 MHz |
| RAM | 1 MB — two AS6C4008-55PCN SRAMs (even/odd byte lanes) |
| ROM | Two SST39SF040 4Mb flash (even/odd byte lanes) |
| CPLD | ATF1508AS PLCC84 — replaces IC2/IC3/IC4/IC5/IC6/IC7 from rosco_m68k r2 |
| USB/serial | MCP2221A — USB-CDC serial to UART A, USB-SPI to SD card |
| PCB | 4-layer, 100 × 100 mm, JLCPCB stackup (F.Cu / GND / PWR / B.Cu) |

### Memory map

| Range | Device |
|-------|--------|
| `$000000–$0FFFFF` | 1 MB SRAM |
| `$100000–$DFFFFF` | Expansion bus (DTACK from `LGEXP`) |
| `$E00000–$EFFFFF` | Flash ROM |
| `$F00000–$FFFFFF` | I/O — CPLD UART at `$F00000`, register select via A1–A4 |

### CPLD functional blocks

The CPLD (`code/cpld/cpld.v`) implements:

1. **Glue logic** — HALT/RESET open-drain drivers, CPU-space gating, boot flag
2. **Address decoder** — RAM, ROM, expansion, and I/O selects; DTACK; WR
3. **Watchdog** — 16-cycle timeout, asserts BERR open-drain
4. **UART A** — fixed 115200 8N1, XR68C681-compatible register map
5. **GPIO / OPR** — XR68C681 output port emulation; drives SPI CS, LEDs, MOSI, SCK
6. **SPI RX accelerator** — hardware-assisted SD card byte receive at ~1.843 MHz
7. **Interrupt priority encoder** — replaces 74LS148; encodes IRQ2/3/5/6 + UART RX into IPL2:1:0

Resource utilisation: **122/128 macro cells (95%)**.

## Repository layout

```
design/          KiCad 10 schematic and PCB
  Simple010.kicad_sch   top-level (references four sub-sheets)
  CPU.kicad_sch         MC68010P, oscillator, expansion connector
  Memory.kicad_sch      SRAM, ROM, write-enable jumper
  CPLD.kicad_sch        ATF1508AS, JTAG header, LEDs, pull-ups
  USB.kicad_sch         MCP2221A, SD card, reset supervisor, power LEDs
  datasheets/           component datasheets and parts index (INDEX.md)

code/cpld/       ATF1508AS Verilog RTL and testbench
  cpld.v                RTL source with //PIN: preassignment comments
  tb_cpld.v             testbench (120 assertions)
  build.sh              synthesis → fit → pin check → simulation
  cpld.jed              program this into the device
  cpld.fit / cpld.pin   fitter log and pin placement

rosco/           rosco_m68k firmware (git clone), modified for Simple010
```

## CPLD build

Requires [`atf15xx_yosys`](https://github.com/hoglet67/atf15xx_yosys.git) cloned into `~/atf15xx_yosys`, and `iverilog`/`vvp` on PATH.

```sh
cd code/cpld && ./build.sh
```

Expected output: `122/128 MCs used` and `120/120 tests passed`.

To run the testbench without re-synthesising:

```sh
cd code/cpld && iverilog -DSIMULATION -o tb_cpld tb_cpld.v cpld.v && vvp tb_cpld
```

The `-DSIMULATION` flag is required — without it 2 of 120 tests fail due to a cross-clock-domain handshake that behaves differently under deterministic simulation timing.

## Firmware

The firmware is the standard rosco_m68k r2 firmware cloned into `rosco/`, with minimal changes for Simple010 hardware.

### CPLD compatibility

The CPLD's UART emulates the XR68C681 (MC68681) at the register level. The existing rosco firmware DUART detection and initialisation code works without modification: the CPLD returns `0x0F` from the IVR register at reset, exactly as the real XR68C681 does.

### Simple010-specific changes

**File:** `rosco/rosco_m68k/code/firmware/rosco_m68k_firmware/stage1/main1.c`

At startup, after printing the standard CPU and memory information, the firmware reads the CPLD detection register and prints additional messages:

```
MC68010 CPU @ 10.0MHz with 1048576 bytes RAM
Simple010 CPLD v1 detected
  SPI RX accelerator present
```

**Detection mechanism:** reading byte address `0xF00005` (`DUART_R_MISR` in `machine.h`) returns a fixed capability byte from the CPLD:

| Bit | Mask | Meaning |
|-----|------|---------|
| 7 | `0x80` | CPLD present (always 1) |
| 6 | `0x40` | SPI RX accelerator available |
| 1–0 | `0x03` | Bitstream version (currently 1) |

The combined value is `0xC1`. On the original XR68C681, this register is MISR (masked interrupt status), which reads ~`0x00` at boot — so the detection is safe on original rosco hardware and the CPLD messages simply do not appear.

> **Address note:** the CPLD's `uart_sel` is gated on `~LDS` (lower data strobe), so the access must target the **odd** byte address `0xF00005`. Reading even address `0xF00004` (upper data strobe / UDS) will not reach the CPLD.

### SPI RX accelerator

The CPLD includes a hardware SPI byte-receive engine clocked at ~1.843 MHz (UART_CLK ÷ 2). Firmware triggers a receive by writing any value to `$F00008`, then polls the `spi_busy` flag in the status register (`$F00003` bit 2), then reads the received byte from `$F00008`. This reduces per-byte bus traffic from ~24 cycles to 2 cycles compared to bit-banging.

## Parts and ordering

See [`design/datasheets/INDEX.md`](design/datasheets/INDEX.md) for a full BOM with LCSC and Mouser part numbers.

Key sourcing notes:
- **ATF1508AS-15JU84** — not on LCSC; order from Microchip direct, Mouser (556-AF1508AS15JU84), or DigiKey
- **MC68010P** — EOL; source from eBay or second-hand market
- **SST39SF040 PLCC-32** — not stocked on LCSC; use Mouser (579-SST39SF040-70-4I-NHE)

## Acknowledgements

Simple010 is based on the [rosco_m68k](https://github.com/rosco-m68k/rosco_m68k) project by Ross Bamford and contributors. The schematic topology, memory map, and firmware are derived from the rosco_m68k r2 mainboard design.
