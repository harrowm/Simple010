// Testbench for cpld.v — address decoder and interrupt encoder
//
// Run with:
//   iverilog -DSIMULATION -o tb_cpld tb_cpld.v cpld.v && vvp tb_cpld
//
// 68010 FC encoding:
//   FC=3'b101 — supervisor data   (normal data R/W)
//   FC=3'b110 — supervisor program (instruction fetch)
//   FC=3'b111 — CPU space         (interrupt acknowledge — blocks memory)
//
// 68010 active-low IPL encoding (IPL2:IPL1:IPL0):
//   3'b111 = no interrupt (level 0)
//   3'b101 = level 2  (~2 = ~3'b010)
//   3'b100 = level 3  (~3 = ~3'b011)
//   3'b011 = level 4  (~4 = ~3'b100)
//   3'b010 = level 5  (~5 = ~3'b101)
//   3'b001 = level 6  (~6 = ~3'b110)

`timescale 1ns/1ps
`default_nettype none

module tb_cpld;

// ----------------------------------------------------------------
// Clocks
// ----------------------------------------------------------------
reg SYS_CLK  = 0;
reg UART_CLK = 0;
always #62  SYS_CLK  = ~SYS_CLK;   // ~8 MHz
always #135 UART_CLK = ~UART_CLK;  // ~3.7 MHz

// ----------------------------------------------------------------
// DUT inputs
// ----------------------------------------------------------------
reg        HWRST;
reg [23:0] ADDR;
reg        AS, RW, UDS, LDS;
reg [2:0]  FC;
reg        LGEXP;
reg        nIRQ2_drv, nIRQ3_drv, nIRQ5_drv, nIRQ6_drv;
reg        RXA;
reg        SPI_MISO;
reg  [7:0] D_drv;
reg        D_oe;

// ----------------------------------------------------------------
// DUT outputs / inout wires
// ----------------------------------------------------------------
wire HALT, RESET;
wire DTACK, BERR;
wire nEVENRAMSEL, nODDRAMSEL, nEVENROMSEL, nODDROMSEL, nEXPSEL;
wire WR, nIOSEL;
wire [7:0] D;
wire TXA;
wire SPI_MOSI, SPI_SCK, SPI_nCS, SPI_nCS1, LED_RED, LED_GREEN;
wire IPL0, IPL1, IPL2;

// Pull-ups on open-drain/tristate signals
tri1 DTACK_pu;
tri1 BERR_pu;
assign DTACK_pu = DTACK;
assign BERR_pu  = BERR;

// Open-collector IRQ lines (1 = deasserted via pull-up, 0 = asserted)
wire nIRQ2 = nIRQ2_drv;
wire nIRQ3 = nIRQ3_drv;
wire nIRQ5 = nIRQ5_drv;
wire nIRQ6 = nIRQ6_drv;

assign D = D_oe ? D_drv : 8'hzz;

// ----------------------------------------------------------------
// DUT instantiation
// ----------------------------------------------------------------
cpld dut (
    .SYS_CLK  (SYS_CLK),
    .UART_CLK (UART_CLK),
    .A1  (ADDR[1]),  .A2  (ADDR[2]),  .A3  (ADDR[3]),  .A4  (ADDR[4]),
    .A18 (ADDR[18]), .A19 (ADDR[19]), .A20 (ADDR[20]),
    .A21 (ADDR[21]), .A22 (ADDR[22]), .A23 (ADDR[23]),
    .AS(AS), .RW(RW), .UDS(UDS), .LDS(LDS),
    .FC0(FC[0]), .FC1(FC[1]), .FC2(FC[2]),
    .HWRST(HWRST),
    .HALT(HALT), .RESET(RESET), .DTACK(DTACK), .BERR(BERR),
    .nEVENRAMSEL(nEVENRAMSEL), .nODDRAMSEL(nODDRAMSEL),
    .nEVENROMSEL(nEVENROMSEL), .nODDROMSEL(nODDROMSEL),
    .nEXPSEL(nEXPSEL),
    .LGEXP(LGEXP),
    .WR(WR), .nIOSEL(nIOSEL),
    .D(D),
    .TXA(TXA), .RXA(RXA),
    .SPI_MOSI(SPI_MOSI), .SPI_MISO(SPI_MISO), .SPI_SCK(SPI_SCK),
    .SPI_nCS(SPI_nCS), .SPI_nCS1(SPI_nCS1),
    .LED_RED(LED_RED), .LED_GREEN(LED_GREEN),
    .nIRQ2(nIRQ2), .nIRQ3(nIRQ3), .nIRQ5(nIRQ5), .nIRQ6(nIRQ6),
    .IPL0(IPL0), .IPL1(IPL1), .IPL2(IPL2)
);

// ----------------------------------------------------------------
// Helpers
// ----------------------------------------------------------------
integer pass_count = 0;
integer fail_count = 0;

task check_sig;
    input [256:0] msg;
    input         got;
    input         expected;
    begin
        if (got === expected) begin
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL  %s: got %b expected %b", msg, got, expected);
            fail_count = fail_count + 1;
        end
    end
endtask

task check_asserted;   // active-low signal is low
    input [256:0] msg;
    input         sig;
    begin check_sig(msg, sig, 1'b0); end
endtask

task check_deasserted; // active-low signal is high (or Z with pull-up)
    input [256:0] msg;
    input         sig;
    begin
        if (sig === 1'b1 || sig === 1'bz) pass_count = pass_count + 1;
        else begin
            $display("FAIL  %s: expected deasserted (1/z), got %b", msg, sig);
            fail_count = fail_count + 1;
        end
    end
endtask

task bus_read;
    input [23:0] addr;
    input [2:0]  fc;
    begin
        ADDR = addr; FC = fc; RW = 1; UDS = 0; LDS = 0; AS = 0;
        #10;
    end
endtask

task bus_idle;
    begin
        AS = 1; UDS = 1; LDS = 1; RW = 1; LGEXP = 0;
        #10;
    end
endtask

task do_reset;
    begin
        HWRST = 0;
        @(posedge SYS_CLK); @(posedge SYS_CLK);
        HWRST = 1;
        @(posedge SYS_CLK); @(posedge SYS_CLK);
    end
endtask

// ----------------------------------------------------------------
// Initial state
// ----------------------------------------------------------------
initial begin
    AS = 1; RW = 1; UDS = 1; LDS = 1; FC = 3'b101;
    ADDR = 24'h0; LGEXP = 0;
    nIRQ2_drv = 1; nIRQ3_drv = 1; nIRQ5_drv = 1; nIRQ6_drv = 1;
    RXA = 1; SPI_MISO = 1; D_drv = 8'h0; D_oe = 0; HWRST = 1;
end

// ----------------------------------------------------------------
// Tests
// ----------------------------------------------------------------
initial begin
    $dumpfile("tb_cpld.vcd");
    $dumpvars(0, tb_cpld);

    // ==========================================================
    // RESET
    // ==========================================================
    $display("\n--- Reset ---");
    HWRST = 0; #50;
    check_sig("HALT driven low during reset", HALT, 1'b0);
    check_sig("RESET driven low during reset", RESET, 1'b0);
    @(posedge SYS_CLK); @(posedge SYS_CLK);
    HWRST = 1;
    @(posedge SYS_CLK); @(posedge SYS_CLK);
    check_sig("HALT released after reset", HALT, 1'bz);
    check_sig("RESET released after reset", RESET, 1'bz);

    // ==========================================================
    // WR
    // ==========================================================
    $display("\n--- WR ---");
    RW = 1; #5; check_sig("WR=0 when RW=1 (read)", WR, 1'b0);
    RW = 0; #5; check_sig("WR=1 when RW=0 (write)", WR, 1'b1);
    RW = 1;

    // ==========================================================
    // BOOT MODE — after reset, boot_r=0: ROM shadow active, RAM restricted
    // ==========================================================
    $display("\n--- Boot mode ---");
    do_reset;

    // ROM shadow: reads to $000000-$03FFFF select ROM (not RAM)
    bus_read(24'h000000, 3'b101);
    check_asserted  ("nEVENROMSEL: ROM shadow at $000000 in boot mode", nEVENROMSEL);
    check_deasserted("nEVENRAMSEL: RAM reads blocked at $000000 in boot mode", nEVENRAMSEL);
    check_asserted  ("DTACK: ROM shadow responds", DTACK);
    bus_idle;

    // RAM reads are blocked in boot shadow area (low 256K)
    bus_read(24'h020000, 3'b101);
    check_deasserted("nEVENRAMSEL: RAM read blocked at $020000 in boot mode", nEVENRAMSEL);
    bus_idle;

    // RAM writes work everywhere (including shadow area) in boot mode
    ADDR = 24'h000000; FC = 3'b101; RW = 0; UDS = 0; LDS = 0; AS = 0; #10;
    check_asserted("nEVENRAMSEL: RAM write at $000000 works in boot mode", nEVENRAMSEL);
    bus_idle;

    // Upper RAM ($080000) readable in boot mode (A19 set)
    bus_read(24'h080000, 3'b101);
    check_asserted("nEVENRAMSEL: upper RAM ($080000) readable in boot mode", nEVENRAMSEL);
    bus_idle;

    // ==========================================================
    // BOOT EXIT — supervisor data access to $E00000 clears boot flag
    // ==========================================================
    $display("\n--- Boot exit ---");
    bus_read(24'hE00000, 3'b101);   // rom_fetch = FC=101 + $E00000 range
    @(posedge SYS_CLK); @(posedge SYS_CLK);
    bus_idle;

    // After boot exit: ROM shadow gone, RAM fully open
    bus_read(24'h000000, 3'b101);
    check_deasserted("nEVENROMSEL: no ROM shadow at $000000 post-boot", nEVENROMSEL);
    check_asserted  ("nEVENRAMSEL: RAM reads at $000000 open post-boot", nEVENRAMSEL);
    check_asserted  ("DTACK: RAM responds post-boot", DTACK);
    bus_idle;

    // ==========================================================
    // ADDRESS DECODER (post-boot)
    // ==========================================================
    $display("\n--- Address decoder (post-boot) ---");

    // RAM: $000000–$0FFFFF
    bus_read(24'h000000, 3'b101);
    check_asserted  ("nEVENRAMSEL: $000000", nEVENRAMSEL);
    check_asserted  ("nODDRAMSEL:  $000000", nODDRAMSEL);
    check_deasserted("nEVENROMSEL: not ROM at $000000", nEVENROMSEL);
    check_deasserted("nEXPSEL:     not EXP at $000000", nEXPSEL);
    check_asserted  ("DTACK:       RAM responds",        DTACK);
    bus_idle;

    bus_read(24'h0FFFFE, 3'b101);
    check_asserted("nEVENRAMSEL: top of RAM $0FFFFE", nEVENRAMSEL);
    bus_idle;

    // ROM: $E00000–$EFFFFF
    bus_read(24'hE00000, 3'b101);
    check_asserted  ("nEVENROMSEL: $E00000", nEVENROMSEL);
    check_asserted  ("nODDROMSEL:  $E00000", nODDROMSEL);
    check_deasserted("nEVENRAMSEL: not RAM at $E00000", nEVENRAMSEL);
    check_asserted  ("DTACK:       ROM responds",        DTACK);
    bus_idle;

    bus_read(24'hE80000, 3'b101);
    check_asserted("nEVENROMSEL: $E80000 in ROM range", nEVENROMSEL);
    bus_idle;

    // Expansion: $100000–$DFFFFF
    bus_read(24'h100000, 3'b101);
    check_asserted  ("nEXPSEL: $100000", nEXPSEL);
    check_deasserted("nEVENRAMSEL: not RAM at $100000", nEVENRAMSEL);
    check_deasserted("DTACK: no DTACK without LGEXP",   DTACK);
    bus_idle;

    // Expansion with LGEXP asserted
    ADDR = 24'h100000; FC = 3'b101; RW = 1; UDS = 0; LDS = 0; AS = 0; LGEXP = 1; #10;
    check_asserted("DTACK: expansion responds with LGEXP", DTACK);
    bus_idle;

    // IO: $F00000–$FFFFFF — nIOSEL active
    ADDR = 24'hF00000; FC = 3'b101; AS = 0; #10;
    check_asserted  ("nIOSEL: $F00000 in IO range",     nIOSEL);
    check_deasserted("nEVENRAMSEL: not RAM at IO addr", nEVENRAMSEL);
    check_deasserted("nEXPSEL: not EXP at IO addr",     nEXPSEL);
    bus_idle;

    // ==========================================================
    // CPU SPACE (FC=111) must block all memory
    // ==========================================================
    $display("\n--- CPU space blocked (FC=111) ---");

    bus_read(24'h000000, 3'b111);
    check_deasserted("nEVENRAMSEL: RAM blocked FC=111", nEVENRAMSEL);
    check_deasserted("DTACK:       no response FC=111", DTACK);
    bus_idle;

    bus_read(24'hE00000, 3'b111);
    check_deasserted("nEVENROMSEL: ROM blocked FC=111", nEVENROMSEL);
    check_deasserted("DTACK:       no response FC=111", DTACK);
    bus_idle;

    // ==========================================================
    // INTERRUPT PRIORITY ENCODER
    // Input: nIRQx active-low (0=asserted).
    // Output: IPL2:IPL1:IPL0 active-low binary level (~level).
    //   level 2 → ~2 = ~010 = 3'b101 → IPL2=1,IPL1=0,IPL0=1
    //   level 3 → ~3 = ~011 = 3'b100 → IPL2=1,IPL1=0,IPL0=0
    //   level 5 → ~5 = ~101 = 3'b010 → IPL2=0,IPL1=1,IPL0=0
    //   level 6 → ~6 = ~110 = 3'b001 → IPL2=0,IPL1=0,IPL0=1
    // ==========================================================
    $display("\n--- IPL encoder ---");

    // No interrupt → IPL=3'b111
    nIRQ2_drv=1; nIRQ3_drv=1; nIRQ5_drv=1; nIRQ6_drv=1; #10;
    check_sig("IPL2 idle", IPL2, 1'b1);
    check_sig("IPL1 idle", IPL1, 1'b1);
    check_sig("IPL0 idle", IPL0, 1'b1);

    // nIRQ2 → level 2 → IPL=101 (IPL2=1,IPL1=0,IPL0=1)
    nIRQ2_drv=0; #10;
    check_sig("IPL2: level 2", IPL2, 1'b1);
    check_sig("IPL1: level 2", IPL1, 1'b0);
    check_sig("IPL0: level 2", IPL0, 1'b1);
    nIRQ2_drv=1; #10;

    // nIRQ3 → level 3 → IPL=100 (IPL2=1,IPL1=0,IPL0=0)
    nIRQ3_drv=0; #10;
    check_sig("IPL2: level 3", IPL2, 1'b1);
    check_sig("IPL1: level 3", IPL1, 1'b0);
    check_sig("IPL0: level 3", IPL0, 1'b0);
    nIRQ3_drv=1; #10;

    // nIRQ5 → level 5 → IPL=010 (IPL2=0,IPL1=1,IPL0=0)
    nIRQ5_drv=0; #10;
    check_sig("IPL2: level 5", IPL2, 1'b0);
    check_sig("IPL1: level 5", IPL1, 1'b1);
    check_sig("IPL0: level 5", IPL0, 1'b0);
    nIRQ5_drv=1; #10;

    // nIRQ6 → level 6 → IPL=001 (IPL2=0,IPL1=0,IPL0=1)
    nIRQ6_drv=0; #10;
    check_sig("IPL2: level 6", IPL2, 1'b0);
    check_sig("IPL1: level 6", IPL1, 1'b0);
    check_sig("IPL0: level 6", IPL0, 1'b1);
    nIRQ6_drv=1; #10;

    // Priority: nIRQ6 (level 6) beats nIRQ2 (level 2)
    nIRQ6_drv=0; nIRQ2_drv=0; #10;
    check_sig("IPL2 priority: nIRQ6 wins", IPL2, 1'b0);
    check_sig("IPL1 priority: nIRQ6 wins", IPL1, 1'b0);
    check_sig("IPL0 priority: nIRQ6 wins", IPL0, 1'b1);
    nIRQ6_drv=1; nIRQ2_drv=1; #10;

    // Priority: nIRQ5 (level 5) beats nIRQ3 (level 3)
    nIRQ5_drv=0; nIRQ3_drv=0; #10;
    check_sig("IPL2 priority: nIRQ5>nIRQ3", IPL2, 1'b0);
    check_sig("IPL1 priority: nIRQ5>nIRQ3", IPL1, 1'b1);
    check_sig("IPL0 priority: nIRQ5>nIRQ3", IPL0, 1'b0);
    nIRQ5_drv=1; nIRQ3_drv=1; #10;

    // ==========================================================
    // ODD BYTE SELECTS (LDS-only cycles)
    // ==========================================================
    $display("\n--- Odd byte selects ---");

    // Odd RAM: LDS asserted, UDS deasserted, post-boot
    ADDR=24'h000001; FC=3'b101; RW=1; UDS=1; LDS=0; AS=0; #10;
    check_asserted  ("nODDRAMSEL:  LDS-only RAM read",  nODDRAMSEL);
    check_deasserted("nEVENRAMSEL: UDS not asserted",   nEVENRAMSEL);
    bus_idle;

    // Odd ROM: LDS-only at $E00001
    ADDR=24'hE00001; FC=3'b101; RW=1; UDS=1; LDS=0; AS=0; #10;
    check_asserted  ("nODDROMSEL:  LDS-only ROM read",  nODDROMSEL);
    check_deasserted("nEVENROMSEL: UDS not asserted",   nEVENROMSEL);
    bus_idle;

    // ==========================================================
    // nIOSEL NEGATIVE — not asserted outside IO range
    // ==========================================================
    $display("\n--- nIOSEL negative checks ---");

    ADDR=24'hE00000; FC=3'b101; AS=0; #10;
    check_deasserted("nIOSEL: not active at $E00000 (ROM)", nIOSEL);
    bus_idle;

    ADDR=24'h000000; FC=3'b101; AS=0; #10;
    check_deasserted("nIOSEL: not active at $000000 (RAM)", nIOSEL);
    bus_idle;

    ADDR=24'hEFFFFF; FC=3'b101; AS=0; #10;
    check_deasserted("nIOSEL: not active at $EFFFFF (top ROM)", nIOSEL);
    bus_idle;

    // ==========================================================
    // UART REGISTER READS (combinational dbus_out, no UART_CLK needed)
    // UART read: FC=101, addr in $F00000 range, LDS=0 (odd byte), RW=1
    // reg_sel = {A4,A3,A2,A1}
    // ==========================================================
    $display("\n--- UART register reads ---");

    // Register addresses: offset is byte address; A1:A4 select register.
    // LDS=0 for odd-byte access (UART on odd byte lane).
    // Do NOT set individual ADDR bits after setting the full address — they conflict.

    // CPLDID at $F00004 (offset $04, reg_sel=0010): must read 0xC1
    ADDR=24'hF00004; FC=3'b101; RW=1; UDS=1; LDS=0; AS=0; #10;
    check_asserted("nIOSEL: CPLDID addr in IO range", nIOSEL);
    check_asserted("DTACK: UART responds for CPLDID read", DTACK);
    if (D === 8'hC1)
        pass_count = pass_count + 1;
    else begin
        $display("FAIL  CPLDID: got 0x%02X expected 0xC1", D);
        fail_count = fail_count + 1;
    end
    bus_idle;

    // IVR at $F00018 (offset $18, reg_sel=1100): must read 0x0F
    ADDR=24'hF00018; FC=3'b101; RW=1; UDS=1; LDS=0; AS=0; #10;
    check_asserted("DTACK: UART responds for IVR read", DTACK);
    if (D === 8'h0F)
        pass_count = pass_count + 1;
    else begin
        $display("FAIL  IVR: got 0x%02X expected 0x0F", D);
        fail_count = fail_count + 1;
    end
    bus_idle;

    // SRA at $F00002 (offset $02, reg_sel=0001): bit4=TXRDY, bit2=spi_busy, bit0=RXRDY
    // After reset: TX idle → TXRDY=1, no RX data → RXRDY=0, spi_busy=0
    ADDR=24'hF00002; FC=3'b101; RW=1; UDS=1; LDS=0; AS=0; #10;
    check_asserted("DTACK: UART responds for SRA read", DTACK);
    check_sig("SRA bit4 TXRDY=1 (TX idle)",    D[4], 1'b1);
    check_sig("SRA bit0 RXRDY=0 (no RX data)", D[0], 1'b0);
    check_sig("SRA bit2 spi_busy=0 (idle)",    D[2], 1'b0);
    bus_idle;

    // IP at $F0001A (offset $1A, reg_sel=1101): bit2=SPI_MISO
    // SPI_MISO held high (1) in testbench
    ADDR=24'hF0001A; FC=3'b101; RW=1; UDS=1; LDS=0; AS=0; #10;
    check_sig("IP bit2 = SPI_MISO (1)", D[2], 1'b1);
    bus_idle;

    // ==========================================================
    // OPR REGISTER — SETCMD/RESETCMD
    // SETCMD at offset $1C (A4:A3:A2:A1 = 1110): writes set bits (drive pin low)
    // RESETCMD at offset $1E (A4:A3:A2:A1 = 1111): writes clear bits (drive pin high)
    // opr_n bits: bit2=SPI_nCS, bit3=LED_RED, bit4=SPI_SCK (opr), bit5=LED_GREEN,
    //             bit6=SPI_MOSI, bit7=SPI_nCS1
    // Output pin = ~opr_n: opr_n=0 → pin high; opr_n=1 → pin low
    // ==========================================================
    $display("\n--- OPR register (SETCMD/RESETCMD) ---");

    // After reset: all opr_n = 0 → all output pins high
    check_sig("SPI_nCS  high after reset (opr2n=0)", SPI_nCS,  1'b1);
    check_sig("LED_RED  high after reset (opr3n=0)", LED_RED,  1'b1);
    check_sig("LED_GREEN high after reset (opr5n=0)", LED_GREEN, 1'b1);
    check_sig("SPI_MOSI high after reset (opr6n=0)", SPI_MOSI, 1'b1);
    check_sig("SPI_nCS1 high after reset (opr7n=0)", SPI_nCS1, 1'b1);

    // SETCMD at $F0001C (offset $1C, reg_sel=1110): set bits → assert pins (drive low)
    ADDR=24'hF0001C; FC=3'b101; RW=0; UDS=1; LDS=0; AS=0;
    D_oe=1; D_drv=8'h04;   // set bit2 → opr2n=1 → SPI_nCS=0
    @(posedge SYS_CLK); #5;
    bus_idle; D_oe=0; #10;
    check_sig("SPI_nCS low after SETCMD bit2", SPI_nCS, 1'b0);

    // RESETCMD at $F0001E (offset $1E, reg_sel=1111): clear bits → deassert pins (drive high)
    ADDR=24'hF0001E; FC=3'b101; RW=0; UDS=1; LDS=0; AS=0;
    D_oe=1; D_drv=8'h04;   // clear bit2 → opr2n=0 → SPI_nCS=1
    @(posedge SYS_CLK); #5;
    bus_idle; D_oe=0; #10;
    check_sig("SPI_nCS high after RESETCMD bit2", SPI_nCS, 1'b1);

    // SETCMD: set bit3 (LED_RED) and bit6 (SPI_MOSI) simultaneously
    ADDR=24'hF0001C; FC=3'b101; RW=0; UDS=1; LDS=0; AS=0;
    D_oe=1; D_drv=8'h48;   // bits 3 and 6
    @(posedge SYS_CLK); #5;
    bus_idle; D_oe=0; #10;
    check_sig("LED_RED  low after SETCMD bit3",  LED_RED,  1'b0);
    check_sig("SPI_MOSI low after SETCMD bit6",  SPI_MOSI, 1'b0);
    check_sig("SPI_nCS1 unchanged (still high)", SPI_nCS1, 1'b1);

    // RESETCMD clears all bits
    ADDR=24'hF0001E; FC=3'b101; RW=0; UDS=1; LDS=0; AS=0;
    D_oe=1; D_drv=8'hFF;
    @(posedge SYS_CLK); #5;
    bus_idle; D_oe=0; #10;
    check_sig("LED_RED  high after RESETCMD all", LED_RED,  1'b1);
    check_sig("SPI_MOSI high after RESETCMD all", SPI_MOSI, 1'b1);

    // ==========================================================
    // WATCHDOG (BERR)
    // wdq increments every SYS_CLK while AS is asserted.
    // pberr fires when wdq reaches 4'hF (16 clocks), driving BERR low.
    // pberr and wdq clear the clock after AS is deasserted.
    //
    // Test uses expansion address ($200000) with LGEXP=0 so the CPLD
    // never asserts DTACK — the bus cycle stalls, watchdog fires.
    // ==========================================================
    $display("\n--- Watchdog (BERR) ---");

    // Verify BERR idle before test
    check_deasserted("BERR idle before watchdog test", BERR);

    // Assert bus cycle with no DTACK response — expansion without LGEXP
    ADDR=24'h200000; FC=3'b101; RW=1; UDS=0; LDS=0; AS=0; LGEXP=0;

    // Wait for 18 SYS_CLK cycles (need 16 for timeout, 18 to be safe)
    repeat(18) @(posedge SYS_CLK); #5;
    check_asserted("BERR fires after watchdog timeout (18 clocks)", BERR);

    // Release bus — wdq and pberr clear on next clock
    bus_idle;
    @(posedge SYS_CLK); @(posedge SYS_CLK); #5;
    check_deasserted("BERR released after AS deasserted", BERR);

    // Verify watchdog resets cleanly — a short bus cycle should not fire BERR
    ADDR=24'h200000; FC=3'b101; RW=1; UDS=0; LDS=0; AS=0; LGEXP=0;
    repeat(5) @(posedge SYS_CLK);   // 5 clocks — well below threshold
    bus_idle;
    @(posedge SYS_CLK); #5;
    check_deasserted("BERR not fired for short (5-clock) cycle", BERR);

    // ==========================================================
    // UART TX — write 0x55 to TBA, verify 8N1 bit-stream on TXA
    // 0x55 = 01010101, LSB-first: d0=1, d1=0, d2=1, d3=0, d4=1, d5=0, d6=1, d7=0
    // Frame: start(0), d0(1), d1(0), d2(1), d3(0), d4(1), d5(0), d6(1), d7(0), stop(1)
    //
    // baud_ctr is free-running so the start bit may be < 32 UART_CLK cycles.
    // Use @(negedge TXA) to catch start, @(posedge TXA) to sync to the bit 0
    // boundary (d0=1 for 0x55), then count exactly 32 UART_CLK per bit thereafter.
    // ==========================================================
    $display("\n--- UART TX ---");

    check_sig("TXA idle high before TX write", TXA, 1'b1);

    // Write 0x55 to TBA (offset $06, reg_sel = 4'b0011)
    ADDR=24'hF00006; FC=3'b101; RW=0; UDS=1; LDS=0; AS=0;
    D_oe=1; D_drv=8'h55;
    @(posedge SYS_CLK); #5;
    bus_idle; D_oe=0;

    // Wait for start bit (tx_load sampled by UART_CLK; TXA falls when tx_busy asserts)
    @(negedge TXA);
    check_sig("TXA: start bit = 0", TXA, 1'b0);

    // TXRDY should be 0 while transmitting
    ADDR=24'hF00002; FC=3'b101; RW=1; UDS=1; LDS=0; AS=0; #10;
    check_sig("SRA TXRDY=0 during TX", D[4], 1'b0);
    bus_idle;

    // Synchronise to bit boundary: d0 of 0x55 = 1, so TXA rises at start of bit 0
    @(posedge TXA);

    // Sample each bit in mid-period (16 UART_CLK cycles into each 32-cycle bit)
    repeat(16) @(posedge UART_CLK); #2;
    check_sig("TXA: d0 of 0x55 = 1", TXA, 1'b1);

    repeat(32) @(posedge UART_CLK); #2;
    check_sig("TXA: d1 of 0x55 = 0", TXA, 1'b0);

    repeat(32) @(posedge UART_CLK); #2;
    check_sig("TXA: d2 of 0x55 = 1", TXA, 1'b1);

    repeat(32) @(posedge UART_CLK); #2;
    check_sig("TXA: d3 of 0x55 = 0", TXA, 1'b0);

    repeat(32) @(posedge UART_CLK); #2;
    check_sig("TXA: d4 of 0x55 = 1", TXA, 1'b1);

    repeat(32) @(posedge UART_CLK); #2;
    check_sig("TXA: d5 of 0x55 = 0", TXA, 1'b0);

    repeat(32) @(posedge UART_CLK); #2;
    check_sig("TXA: d6 of 0x55 = 1", TXA, 1'b1);

    repeat(32) @(posedge UART_CLK); #2;
    check_sig("TXA: d7 of 0x55 = 0", TXA, 1'b0);

    repeat(32) @(posedge UART_CLK); #2;
    check_sig("TXA: stop bit = 1",   TXA, 1'b1);

    // Wait for tx_busy to clear (one more bit_en after stop bit)
    repeat(48) @(posedge UART_CLK); #5;
    check_sig("TXA idle after TX complete", TXA, 1'b1);

    // TXRDY must return to 1
    ADDR=24'hF00002; FC=3'b101; RW=1; UDS=1; LDS=0; AS=0; #10;
    check_sig("SRA TXRDY=1 after TX complete", D[4], 1'b1);
    bus_idle;

    // ==========================================================
    // UART RX — drive 0x55 on RXA, verify RXRDY, RBA read, UART IRQ
    // 0x55 = 01010101: LSB-first stream = 1,0,1,0,1,0,1,0
    // Frame: start(0) d0(1) d1(0) d2(1) d3(0) d4(1) d5(0) d6(1) d7(0) stop(1)
    // Each bit = 32 UART_CLK cycles. rx_sctr sampling at centre-bit (rx_sctr==7
    // with samp_en=baud_ctr[0] gives 16x oversampling, centre ≈ 14 UART_CLK
    // from each bit edge).
    // UART IRQ: rx_ready=1 asserts internal level-4 interrupt → IPL=011
    //   level 4 → ~4 = ~3'b100 = 3'b011 → IPL2=0, IPL1=1, IPL0=1
    // ==========================================================
    $display("\n--- UART RX ---");

    // RXA is already 1 (idle). Wait a few UART_CLK cycles so rx_seen_high sets.
    repeat(8) @(posedge UART_CLK);

    // Transmit 0x55 = 01010101, LSB first, 8N1
    RXA = 0; repeat(32) @(posedge UART_CLK);   // start bit
    RXA = 1; repeat(32) @(posedge UART_CLK);   // d0 = 1
    RXA = 0; repeat(32) @(posedge UART_CLK);   // d1 = 0
    RXA = 1; repeat(32) @(posedge UART_CLK);   // d2 = 1
    RXA = 0; repeat(32) @(posedge UART_CLK);   // d3 = 0
    RXA = 1; repeat(32) @(posedge UART_CLK);   // d4 = 1
    RXA = 0; repeat(32) @(posedge UART_CLK);   // d5 = 0
    RXA = 1; repeat(32) @(posedge UART_CLK);   // d6 = 1
    RXA = 0; repeat(32) @(posedge UART_CLK);   // d7 = 0
    RXA = 1; repeat(32) @(posedge UART_CLK);   // stop bit
    // rx_ready is set during stop bit; allow a few cycles for it to propagate
    repeat(8) @(posedge UART_CLK); #5;

    // Check SRA RXRDY=1
    ADDR=24'hF00002; FC=3'b101; RW=1; UDS=1; LDS=0; AS=0; #10;
    check_sig("SRA RXRDY=1 after byte received", D[0], 1'b1);
    bus_idle;

    // UART IRQ: rx_ready → level 4 internal IRQ → IPL2:1:0 = 011
    #10;
    check_sig("IPL2=0: UART RX level 4", IPL2, 1'b0);
    check_sig("IPL1=1: UART RX level 4", IPL1, 1'b1);
    check_sig("IPL0=1: UART RX level 4", IPL0, 1'b1);

    // Read RBA — verify received byte is 0x55
    ADDR=24'hF00006; FC=3'b101; RW=1; UDS=1; LDS=0; AS=0; #10;
    if (D === 8'h55)
        pass_count = pass_count + 1;
    else begin
        $display("FAIL  RBA: got 0x%02X expected 0x55", D);
        fail_count = fail_count + 1;
    end
    @(posedge SYS_CLK); #5;  // ensure cpu_rd_clr toggle is registered
    bus_idle;

    // Wait for cpu_rd_pulse to propagate through 2-FF sync and clear rx_ready
    repeat(6) @(posedge UART_CLK); #5;
    ADDR=24'hF00002; FC=3'b101; RW=1; UDS=1; LDS=0; AS=0; #10;
    check_sig("SRA RXRDY=0 after RBA read", D[0], 1'b0);
    bus_idle;

    // IPL returns to no-interrupt after RXRDY clears
    #10;
    check_sig("IPL2=1: no IRQ after RBA read", IPL2, 1'b1);
    check_sig("IPL1=1: no IRQ after RBA read", IPL1, 1'b1);
    check_sig("IPL0=1: no IRQ after RBA read", IPL0, 1'b1);

    // ==========================================================
    // SPI ACCELERATOR — write SPIRX trigger, poll spi_busy, read result
    // SPI Mode 0 (CPOL=0/CPHA=0): SCK idle low, sample on rising edge, MSB first.
    // Transfer: 16 UART_CLK cycles (SCK = UART_CLK/2 = 1.843 MHz, 8 bits × 2 clk).
    // Trigger: write any value to SPIRX ($F00008, reg_sel=0100).
    // Poll:    SRA bit2 = spi_busy_s1 (synced spi_busy → SYS_CLK, clears when done).
    // Result:  read SPIRX after spi_busy=0 for received byte.
    //
    // Timing from trigger write:
    //   +3 UART_CLK: toggle sync (2 FFs + edge detect) → spi_start fires
    //   +16 UART_CLK: 8 bits transferred
    //   +2 SYS_CLK: spi_busy_s0/s1 sync back to SYS_CLK domain
    //   Wait 32 UART_CLK + 4 SYS_CLK for margin.
    // ==========================================================
    $display("\n--- SPI accelerator ---");

    // --- Test 1: MISO=1 throughout → receive 0xFF ---
    SPI_MISO = 1;

    // Verify idle: SRA spi_busy=0 before trigger
    ADDR=24'hF00002; FC=3'b101; RW=1; UDS=1; LDS=0; AS=0; #10;
    check_sig("SRA spi_busy=0 before trigger", D[2], 1'b0);
    bus_idle;

    // Write to SPIRX to trigger (value ignored)
    ADDR=24'hF00008; FC=3'b101; RW=0; UDS=1; LDS=0; AS=0;
    D_oe=1; D_drv=8'h00;
    @(posedge SYS_CLK); #5;
    bus_idle; D_oe=0;

    // Check spi_busy=1 shortly after trigger (5 UART_CLK sync + 2 SYS_CLK sync)
    repeat(5) @(posedge UART_CLK);
    repeat(2) @(posedge SYS_CLK); #5;
    ADDR=24'hF00002; FC=3'b101; RW=1; UDS=1; LDS=0; AS=0; #10;
    check_sig("SRA spi_busy=1 during transfer", D[2], 1'b1);
    bus_idle;

    // Wait for transfer to complete: 16 UART_CLK transfer + 2 SYS_CLK sync
    repeat(32) @(posedge UART_CLK);
    repeat(4) @(posedge SYS_CLK); #5;
    ADDR=24'hF00002; FC=3'b101; RW=1; UDS=1; LDS=0; AS=0; #10;
    check_sig("SRA spi_busy=0 after transfer", D[2], 1'b0);
    bus_idle;

    // Read SPIRX — expect 0xFF (MISO was 1 throughout)
    ADDR=24'hF00008; FC=3'b101; RW=1; UDS=1; LDS=0; AS=0; #10;
    if (D === 8'hFF)
        pass_count = pass_count + 1;
    else begin
        $display("FAIL  SPIRX (MISO=1): got 0x%02X expected 0xFF", D);
        fail_count = fail_count + 1;
    end
    bus_idle;

    // --- Test 2: MISO=0 throughout → receive 0x00 ---
    SPI_MISO = 0;

    ADDR=24'hF00008; FC=3'b101; RW=0; UDS=1; LDS=0; AS=0;
    D_oe=1; D_drv=8'h00;
    @(posedge SYS_CLK); #5;
    bus_idle; D_oe=0;

    repeat(32) @(posedge UART_CLK);
    repeat(4) @(posedge SYS_CLK); #5;
    ADDR=24'hF00002; FC=3'b101; RW=1; UDS=1; LDS=0; AS=0; #10;
    check_sig("SRA spi_busy=0 after 2nd transfer", D[2], 1'b0);
    bus_idle;

    ADDR=24'hF00008; FC=3'b101; RW=1; UDS=1; LDS=0; AS=0; #10;
    if (D === 8'h00)
        pass_count = pass_count + 1;
    else begin
        $display("FAIL  SPIRX (MISO=0): got 0x%02X expected 0x00", D);
        fail_count = fail_count + 1;
    end
    bus_idle;

    SPI_MISO = 1;  // restore idle

    // ==========================================================
    // Summary
    // ==========================================================
    $display("\n=== Results: %0d passed, %0d failed ===\n", pass_count, fail_count);
    if (fail_count == 0) $display("ALL TESTS PASSED");
    else                 $display("FAILURES DETECTED");
    $finish;
end

initial begin #500000; $display("TIMEOUT"); $finish; end

endmodule
