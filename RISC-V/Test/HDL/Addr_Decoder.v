module Addr_Decoder (
    input  wire [31:0] ADDR,
    input  wire        WE,
    output wire        ram_we,
    output wire        spi_we,
    output wire        spi_sel   // high when reading from SPI region
);
    assign spi_sel = (ADDR >= 32'h00000400);
    assign ram_we  = WE & ~spi_sel;
    assign spi_we  = WE &  spi_sel;
endmodule