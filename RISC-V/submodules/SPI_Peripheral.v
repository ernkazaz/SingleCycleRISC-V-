module SPI_Peripheral (
    input  wire        clk,
    input  wire        rst,
    // Memory-mapped interface
    input  wire        we,
    input  wire [2:0]  addr,    // ALUResult[2:0]: byte offset from 0x400
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    // Nexys A7 ACL pins (match XDC exactly)
    output wire        ACL_SCLK,
    output wire        ACL_MOSI,
    input  wire        ACL_MISO,
    output wire        ACL_CSN
);
    // ── Internal registers ──────────────────────────────────────────
    reg [31:0] tx_data_reg;
    reg [7:0]  tx_len_reg;
    reg [7:0]  rx_len_reg;
    reg [31:0] rx_data_reg;

    // ── X_Start pulse: one cycle when addr=6 is written ────────────
    wire start_pulse = we && (addr == 3'd6);

    // ── Register writes ─────────────────────────────────────────────
    always @(posedge clk) begin
        if (rst) begin
            tx_data_reg <= 0;
            tx_len_reg  <= 0;
            rx_len_reg  <= 0;
        end else if (we) begin
            case (addr)
                3'd0: tx_data_reg <= wdata;       // SW  → 0x400
                3'd4: tx_len_reg  <= wdata[7:0];  // SB  → 0x404
                3'd5: rx_len_reg  <= wdata[7:0];  // SB  → 0x405
                default: ;
            endcase
        end
    end

    // ── Capture RX data when FSM signals done ───────────────────────
    wire        fsm_done;
    wire [31:0] fsm_rx_data;

    always @(posedge clk) begin
        if (rst)
            rx_data_reg <= 0;
        else if (fsm_done)
            rx_data_reg <= fsm_rx_data;
    end

    // ── Register reads ──────────────────────────────────────────────
    always @(*) begin
        case (addr)
            3'd0:    rdata = tx_data_reg;
            3'd4:    rdata = {24'b0, tx_len_reg};
            3'd5:    rdata = {24'b0, rx_len_reg};
            3'd8:    rdata = rx_data_reg;          // LW  ← 0x408
            default: rdata = 32'b0;
        endcase
    end

    // ── FSM instantiation ───────────────────────────────────────────
    SPI_FSM fsm (
        .clk      (clk),
        .rst      (rst),
        .start    (start_pulse),
        .tx_len   (tx_len_reg),
        .rx_len   (rx_len_reg),
        .tx_data  (tx_data_reg),
        .MISO     (ACL_MISO),
        .SCLK     (ACL_SCLK),
        .MOSI     (ACL_MOSI),
        .CS_N     (ACL_CSN),
        .rx_data  (fsm_rx_data),
        .done     (fsm_done),
        .clk_en   ()             // internal to FSM via SPI_Clk_Div
    );

endmodule