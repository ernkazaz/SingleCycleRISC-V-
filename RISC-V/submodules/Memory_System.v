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
    // SPI pins - connect directly to top-level ports
    output wire        ACL_SCLK,
    output wire        ACL_MOSI,
    input  wire        ACL_MISO,
    output wire        ACL_CSN
);
    wire        ram_we, spi_we, spi_sel;
    wire [31:0] ram_rd, spi_rd;

    // ── Address decode ──────────────────────────────────────────────
    Addr_Decoder dec (
        .ADDR    (ADDR),
        .WE      (WE),
        .ram_we  (ram_we),
        .spi_we  (spi_we),
        .spi_sel (spi_sel)
    );

    // ── Data memory ─────────────────────────────────────────────────
    Memory #(.DEPTH(DEPTH), .ADDR_WIDTH(ADDR_WIDTH)) Data_mem (
        .clk    (clk),
        .WE     (ram_we),
        .funct3 (funct3),
        .ADDR   (ADDR),
        .WD     (WD),
        .RD     (ram_rd)
    );

    // ── SPI peripheral ──────────────────────────────────────────────
    SPI_Peripheral spi (
        .clk      (clk),
        .rst      (rst),
        .we       (spi_we),
        .addr     (ADDR[2:0]),   // byte offset within peripheral space
        .wdata    (WD),
        .rdata    (spi_rd),
        .ACL_SCLK (ACL_SCLK),
        .ACL_MOSI (ACL_MOSI),
        .ACL_MISO (ACL_MISO),
        .ACL_CSN  (ACL_CSN)
    );

    // ── ReadData mux ────────────────────────────────────────────────
    Mux_2to1 #(.WIDTH(32)) RD_Mux (
        .select       (spi_sel),
        .input_0      (ram_rd),
        .input_1      (spi_rd),
        .output_value (RD)
    );

endmodule