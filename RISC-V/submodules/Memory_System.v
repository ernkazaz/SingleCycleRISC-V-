module MemorySystem #(
    parameter DEPTH      = 256,
    parameter ADDR_WIDTH = 32
)(
    input  wire        clk, rst,
    input  wire        WE,
    input  wire [2:0]  funct3,
    input  wire [ADDR_WIDTH-1:0] ADDR,
    input  wire [31:0] WD,
    output wire [31:0] RD,
    output wire        ACL_SCLK,
    output wire        ACL_MOSI,
    input  wire        ACL_MISO,
    output wire        ACL_CSN
);

    // ── Address decode ───────────────────────────────────────────────────
    // SPI peripheral occupies 0x400-0x40F (16 bytes)
    wire spi_sel = (ADDR[31:4] == 28'h0000040);   // ADDR[31:4] == 0x0000040
    wire ram_we  = WE & ~spi_sel;
    wire spi_we  = WE &  spi_sel;

    // ── Data RAM ─────────────────────────────────────────────────────────
    wire [31:0] ram_rd;
    Memory #(.DEPTH(DEPTH), .ADDR_WIDTH(ADDR_WIDTH)) Data_mem (
        .clk    (clk),
        .WE     (ram_we),
        .funct3 (funct3),
        .ADDR   (ADDR),
        .WD     (WD),
        .RD     (ram_rd)
    );

    // ── SPI peripheral ───────────────────────────────────────────────────
    wire [31:0] spi_rd;
    SPI_Peripheral spi (
        .clk      (clk),
        .rst      (rst),
        .we       (spi_we),
        .addr     (ADDR[3:0]),   // 4-bit offset covers 0x0..0xF
        .wdata    (WD),
        .rdata    (spi_rd),
        .ACL_SCLK (ACL_SCLK),
        .ACL_MOSI (ACL_MOSI),
        .ACL_MISO (ACL_MISO),
        .ACL_CSN  (ACL_CSN)
    );

    // ── ReadData mux ─────────────────────────────────────────────────────
    assign RD = spi_sel ? spi_rd : ram_rd;

endmodule