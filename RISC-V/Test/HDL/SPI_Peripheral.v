// SPI_Peripheral - memory-mapped SPI master
// Address map (offset from 0x400, using ADDR[3:0]):
//   0x0 (offset 0) : TX_Data   [31:0]  - SW
//   0x4 (offset 4) : TX_Length [7:0]   - SB
//   0x5 (offset 5) : RX_Length [7:0]   - SB
//   0x6 (offset 6) : X_Start   (write) - SB  (starts transaction)
//   0x8 (offset 8) : RX_Data   [31:0]  - LW
//
// NOTE: Memory_System must pass ADDR[3:0] (not [2:0]) to cover offset 8.

module SPI_Peripheral (
    input  wire        clk,
    input  wire        rst,
    // Memory-mapped interface
    input  wire        we,
    input  wire [3:0]  addr,    // ADDR[3:0]: byte offset from 0x400
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    // Nexys A7 ACL pins
    output wire        ACL_SCLK,
    output wire        ACL_MOSI,
    input  wire        ACL_MISO,
    output wire        ACL_CSN
);

    reg [31:0] tx_data_reg;
    reg [7:0]  tx_len_reg;
    reg [7:0]  rx_len_reg;
    reg [31:0] rx_data_reg;

    // X_Start: one-cycle pulse when offset 6 is written
    wire start_pulse = we && (addr == 4'd6);

    // Register writes
    always @(posedge clk) begin
        if (rst) begin
            tx_data_reg <= 0;
            tx_len_reg  <= 0;
            rx_len_reg  <= 0;
        end else if (we) begin
            case (addr)
                4'd0: tx_data_reg <= wdata;        // SW  -> 0x400
                4'd4: tx_len_reg  <= wdata[7:0];   // SB  -> 0x404
                4'd5: rx_len_reg  <= wdata[7:0];   // SB  -> 0x405
                // addr 6 handled by start_pulse; no data register
                default: ;
            endcase
        end
    end

    // Capture RX data when FSM signals done
    wire        fsm_done;
    wire [31:0] fsm_rx_data;

    always @(posedge clk) begin
        if (rst)
            rx_data_reg <= 0;
        else if (fsm_done)
            rx_data_reg <= fsm_rx_data;
    end

    // Register reads (combinational)
    always @(*) begin
        case (addr)
            4'd0:    rdata = tx_data_reg;
            4'd4:    rdata = {24'b0, tx_len_reg};
            4'd5:    rdata = {24'b0, rx_len_reg};
            4'd8:    rdata = rx_data_reg;           // LW <- 0x408
            default: rdata = 32'b0;
        endcase
    end

    // FSM instantiation
    SPI_FSM fsm (
        .clk     (clk),
        .rst     (rst),
        .start   (start_pulse),
        .tx_len  (tx_len_reg),
        .rx_len  (rx_len_reg),
        .tx_data (tx_data_reg),
        .MISO    (ACL_MISO),
        .SCLK    (ACL_SCLK),
        .MOSI    (ACL_MOSI),
        .CS_N    (ACL_CSN),
        .rx_data (fsm_rx_data),
        .done    (fsm_done),
        .clk_en  ()
    );

endmodule