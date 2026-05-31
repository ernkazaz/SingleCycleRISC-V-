module SPI_FSM (
    input  wire        clk,
    input  wire        rst,
    // Start trigger (from register file write to X_Start)
    input  wire        start,
    // Transaction parameters
    input  wire [7:0]  tx_len,      // number of TX bytes
    input  wire [7:0]  rx_len,      // number of RX bytes
    input  wire [31:0] tx_data,     // data to send (little-endian, MSB sent first)
    // MISO line
    input  wire        MISO,
    // Outputs to pin driver
    output reg         SCLK,
    output reg         MOSI,
    output reg         CS_N,        // active low
    // Captured RX data
    output reg  [31:0] rx_data,
    output reg         done,        // pulses high for one cycle when complete
    // Clock divider enable
    output wire        clk_en
);
    localparam IDLE = 2'd0,
               LOAD = 2'd1,
               SHIFT= 2'd2,
               DONE = 2'd3;

    reg [1:0]  state;
    reg [5:0]  total_bits;   // (tx_len + rx_len) * 8
    reg [5:0]  tx_bits;      // tx_len * 8
    reg [5:0]  bit_idx;      // current bit position (0 = first bit out)
    reg [31:0] shift_tx;     // shift register - MSB shifts out first
    reg [31:0] shift_rx;     // accumulates MISO bits
    reg        phase;        // 0 = drive/rise, 1 = fall

    wire tick;

    // Clock divider enabled only during SHIFT state
    assign clk_en = (state == SHIFT);

    SPI_Clk_Div #(.CLK_DIV(50)) clk_div (
        .clk  (clk),
        .rst  (rst),
        .en   (clk_en),
        .tick (tick)
    );

    always @(posedge clk) begin
        if (rst) begin
            state      <= IDLE;
            SCLK       <= 0;
            MOSI       <= 0;
            CS_N       <= 1;
            done       <= 0;
            bit_idx    <= 0;
            phase      <= 0;
            shift_tx   <= 0;
            shift_rx   <= 0;
            rx_data    <= 0;
            total_bits <= 0;
            tx_bits    <= 0;
        end else begin
            done <= 0;   // default: not done

            case (state)

                IDLE: begin
                    SCLK  <= 0;
                    MOSI  <= 0;
                    CS_N  <= 1;
                    if (start) begin
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    // Prepare shift register and counters, assert CS_N
                    total_bits <= (tx_len + rx_len) << 3;
                    tx_bits    <= tx_len << 3;
                    // Pack TX data: send byte 0 first (little-endian on wire = low byte first)
                    // tx_data[7:0] goes out first, so pre-arrange MSB of shift reg
                    shift_tx   <= tx_data;
                    shift_rx   <= 0;
                    bit_idx    <= 0;
                    phase      <= 0;
                    CS_N       <= 0;    // assert chip select
                    state      <= SHIFT;
                end

                SHIFT: begin
                    if (tick) begin
                        if (!phase) begin
                            // ── Rising edge of SCLK ──────────────────
                            // Drive MOSI: during TX bits send real data,
                            // during RX bits send 0x00 (dummy)
                            if (bit_idx < tx_bits)
                                // Send LSB of current TX byte first
                                // shift_tx rotates: [31:0] → MSB out
                                MOSI <= shift_tx[31];
                            else
                                MOSI <= 1'b0;

                            SCLK  <= 1;
                            // Sample MISO on rising edge (Mode 0)
                            shift_rx <= {shift_rx[30:0], MISO};
                            phase    <= 1;
                        end else begin
                            // ── Falling edge of SCLK ─────────────────
                            SCLK      <= 0;
                            shift_tx  <= {shift_tx[30:0], 1'b0}; // advance TX shift reg
                            bit_idx   <= bit_idx + 1;
                            phase     <= 0;

                            if (bit_idx + 1 == total_bits) begin
                                // Capture only the RX portion of shift_rx
                                // RX bits are the last (rx_len*8) bits shifted in
                                rx_data <= shift_rx;
                                state   <= DONE;
                            end
                        end
                    end
                end

                DONE: begin
                    CS_N  <= 1;    // de-assert chip select
                    SCLK  <= 0;
                    MOSI  <= 0;
                    done  <= 1;    // one-cycle pulse
                    state <= IDLE;
                end

            endcase
        end
    end
endmodule