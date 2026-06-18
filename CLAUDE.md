# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Simple010** is a 68010 single-board computer (SBC) based on the [rosco_m68k r2](https://github.com/rosco-m68k/rosco_m68k) design. It acknowledges and builds on the rosco_m68k project, replacing six discrete glue-logic ICs from that design (IC2 address decoder, IC3 DUART select, IC4 XR68C681 UART, IC5 glue logic, IC6 watchdog, IC7 74LS148 interrupt priority encoder) with a single **ATF1508AS PLCC84 CPLD**.

The repository contains two independent areas:
- `design/` — KiCad 10 schematics and PCB layout
- `code/cpld/` — Verilog RTL for the CPLD, testbench, and build artifacts

## CPLD Build

### Prerequisites

- [`atf15xx_yosys`](https://github.com/hoglet67/atf15xx_yosys.git) cloned into `~/atf15xx_yosys`
- `iverilog` and `vvp` on PATH

### Commands

```sh
# Full build: synthesis → fit → pin check → simulation
cd code/cpld && ./build.sh

# Simulation only (no re-synthesis)
cd code/cpld && iverilog -DSIMULATION -o tb_cpld tb_cpld.v cpld.v && vvp tb_cpld
```

Expected output when passing: `122/128 MCs used` and `120/120 tests passed`.

The `-DSIMULATION` flag is required for all simulation runs — without it, 2 of 120 tests fail due to a cross-clock-domain handshake that behaves differently under deterministic sim timing vs hardware.

### Build outputs

| File | Purpose |
|------|---------|
| `cpld.jed` | Program this into the ATF1508AS |
| `cpld.fit` | Fitter log — resource usage, final pin placement |
| `cpld.pin` | Pin placement summary |
| `tb_cpld.vcd` | Waveform dump from last simulation run |

## Hardware Architecture

### CPU and memory map (identical to rosco_m68k r2)

- **CPU**: Motorola MC68010P at 10 MHz (SG-5032CAN oscillator)
- **RAM**: 1 MB — two AS6C4008-55PCN SRAMs (even/odd byte lanes), `$000000–$0FFFFF`
- **ROM**: SST39SF040 flash (even/odd pair), `$E00000–$EFFFFF`
- **Expansion**: `$100000–$DFFFFF` — DTACK sourced from `LGEXP` signal on expansion bus
- **I/O**: `$F00000–$FFFFFF` — CPLD-internal UART at `$F00000`, register select via A1–A4

### CPLD (ATF1508AS PLCC84)

The CPLD implements the entire system glue in `code/cpld/cpld.v`:

**Two clock domains:**
- `SYS_CLK` (pin 2, GCK) — 10 MHz; clocks address decode, watchdog, GPIO, SPI sync FFs
- `UART_CLK` (pin 83, GCK) — 3.6864 MHz; clocks UART baud logic and SPI state machine
- `HWRST` (pin 1, GCLRn) — hardware reset button, used as async clear for all reset-sensitive FFs

**Functional blocks inside the CPLD:**
1. **Glue logic** — HALT/RESET open-drain drivers, CPUSP (CPU-space gating), boot flag
2. **Address decoder** — generates `nEVENRAMSEL`, `nODDRAMSEL`, `nEVENROMSEL`, `nODDROMSEL`, `nEXPSEL`, `nIOSEL`, `DTACK`, `WR`
3. **Watchdog** — 16-cycle SYS_CLK timeout, asserts `BERR` open-drain
4. **UART A** — fixed 115200 8N1 TX/RX, XR68C681-compatible register map at UART offsets
5. **GPIO/OPR** — XR68C681 output port emulation; drives `SPI_nCS`, `SPI_nCS1`, `LED_RED`, `LED_GREEN`, `SPI_MOSI`, `SPI_SCK`
6. **SPI RX accelerator** — hardware-assisted SD card byte receive at 1.843 MHz (UART_CLK/2); reduces per-byte bus traffic from ~24 to 2 cycles
7. **Interrupt priority encoder** — replaces 74LS148; encodes `nIRQ2/3/5/6` + UART RX into 68010 `IPL2:IPL1:IPL0`

**CPLD detection register:** Reading `$F00005` (= `DUART_R_MISR`, the odd/LDS byte address) returns `0xC1` (CPLD present + SPI accelerator + version 1). The CPLD's `uart_sel` is gated on `~LDS`, so the access **must** target the odd address `0xF00005` — reading even address `0xF00004` (UDS) will not reach the CPLD. The original XR68C681 maps this register to MISR (masked interrupt status), which reads ~0x00 at boot, so firmware can distinguish CPLD from original chip with a single read.

**Resource utilisation:** 122/128 macro cells (95%). The device is nearly full — adding significant new logic will likely not fit. The fitter requires `-strategy Cascade_Logic ON -strategy Foldback_Logic ON` to route within the ATF1508AS block fanin limit of 40 unique inputs.

### Address lines A6–A17

These are **not connected to the CPLD** (freed up pins for IPL/IRQ signals). The UART select uses a relaxed decode that only checks the IO range and `~LDS` — this is intentional and safe because nothing else occupies `$F00000–$FFFFFF`.

### External pull-ups required

`nIRQ2/3/5/6` are open-collector expansion bus lines. External 4.7 kΩ pull-ups to VCC are required on the board (R15–R18). The ATF1508AS has no internal pull-ups.

### USB / serial interface

The USB schematic (`design/USB.kicad_sch`) includes an **MCP2221A** USB bridge providing:
- USB-CDC serial → connected to `TXDA`/`RXDA` (CPLD UART A)
- SPI/I²C pins (GP0–GP3, SCL, SDA) are **unconnected**

The SD card SPI interface (`SPICLK`, `SPICS`, `SPIMOSI`, `SPIMISO`) connects directly between J8 and the CPLD (U2). A second CS line (`SPICS2`) is available on J1, also driven by the CPLD.

### KiCad design structure

The top-level schematic (`design/Simple010.kicad_sch`) references four sub-sheets:
- `CPU.kicad_sch` — MC68010P, clock oscillator, bus expansion connector
- `Memory.kicad_sch` — RAM (AS6C4008), ROM (SST39SF040), write-enable jumper
- `CPLD.kicad_sch` — ATF1508AS with decoupling, JTAG connector, LEDs, IRQ pull-ups, UART clock oscillator
- `USB.kicad_sch` — MCP2221A USB bridge, SD card connector, reset supervisor, power LEDs

Custom CPLD symbol: `design/libs/ATF1508AS.kicad_sym`.

### JTAG

JTAG is left **ON** in the current bitstream (pins 14 TDI, 23 TMS, 62 TCK, 71 TDO). A 2×5 JTAG header is present on the CPLD schematic.

## Cross-domain handshake pattern

Two signals (`tx_load`, `cpu_rd_rba`) cross from SYS_CLK to UART_CLK domain. In synthesis they are 1-SYS_CLK pulses (~100 ns). In simulation they are held until the UART_CLK domain acknowledges (via the `SIMULATION` macro). This split is intentional — do not unify the branches without understanding the timing implications.
