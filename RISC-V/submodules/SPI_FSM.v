module SPI_FSM (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire [7:0]  tx_len,
    input  wire [7:0]  rx_len,
    input  wire [31:0] tx_data,   // little-endian word: byte 0 at [7:0]
    input  wire        MISO,
    output reg         SCLK,
    output reg         MOSI,
    output reg         CS_N,
    output reg  [31:0] rx_data,
    output reg         done,
    output wire        clk_en
);

    localparam IDLE  = 2'd0,
               LOAD  = 2'd1,
               SHIFT = 2'd2,
               DONE  = 2'd3;

    reg [1:0]  state;
    reg [5:0]  total_bits;   // (tx_len + rx_len) * 8
    reg [5:0]  tx_bits;      // tx_len * 8
    reg [5:0]  bit_idx;      // counts completed bits
    reg [31:0] shift_tx;     // MSB is the next bit to send
    reg [31:0] shift_rx;     // LSB receives each new MISO bit
    reg        phase;        // 0 = high phase (SCLK=1, sample), 1 = low phase (SCLK=0, shift)

    wire tick;

    assign clk_en = (state == SHIFT);

    SPI_Clk_Div #(.CLK_DIV(50)) clk_div (
        .clk  (clk),
        .rst  (rst),
        .en   (clk_en),
        .tick (tick)
    );

    // Re-pack helper: given a 32-bit little-endian word and byte count n,
    // arrange so byte[0] is at bits [31:24], byte[1] at [23:16], etc.
    // (Only bytes 0..n-1 are relevant; the rest are don't-care.)
    function [31:0] repack;
        input [31:0] d;
        input [7:0]  n;   // number of TX bytes (1..4)
        begin
            case (n)
                8'd1: repack = {d[7:0],   24'b0};
                8'd2: repack = {d[7:0],   d[15:8],  16'b0};
                8'd3: repack = {d[7:0],   d[15:8],  d[23:16], 8'b0};
                default: repack = {d[7:0], d[15:8], d[23:16], d[31:24]};
            endcase
        end
    endfunction

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
            done <= 0;

            case (state)

                IDLE: begin
                    SCLK <= 0;
                    MOSI <= 0;
                    CS_N <= 1;
                    if (start) state <= LOAD;
                end

                LOAD: begin
                    total_bits <= (tx_len + rx_len) << 3;
                    tx_bits    <= tx_len << 3;
                    // Repack so byte 0 sits at MSB for MSB-first transmission
                    shift_tx   <= repack(tx_data, tx_len);
                    shift_rx   <= 0;
                    bit_idx    <= 0;
                    phase      <= 0;
                    CS_N       <= 0;          // assert CS (active low)
                    // Pre-drive MOSI with the first TX bit before SCLK rises
                    MOSI       <= (tx_len > 0) ? tx_data[7] : 1'b0;
                    state      <= SHIFT;
                end

                SHIFT: begin
                    if (tick) begin
                        if (!phase) begin
                            // ── Rising edge: SCLK goes high, slave samples MOSI ──
                            SCLK  <= 1;
                            // Sample MISO (Mode 0: sample on rising edge)
                            shift_rx <= {shift_rx[30:0], MISO};
                            phase <= 1;
                        end else begin
                            // ── Falling edge: SCLK goes low, advance shift register ──
                            SCLK     <= 0;
                            shift_tx <= {shift_tx[30:0], 1'b0};
                            bit_idx  <= bit_idx + 1;
                            phase    <= 0;

                            if (bit_idx + 1 == total_bits) begin
                                // All bits done
                                rx_data <= shift_rx;
                                state   <= DONE;
                            end else begin
                                // Drive next MOSI bit (set-up before next rising edge)
                                if (bit_idx + 1 < tx_bits)
                                    MOSI <= shift_tx[30]; // next bit after the shift
                                else
                                    MOSI <= 1'b0;         // dummy during RX phase
                            end
                        end
                    end
                end

                DONE: begin
                    CS_N  <= 1;
                    SCLK  <= 0;
                    MOSI  <= 0;
                    done  <= 1;   // one-cycle pulse
                    state <= IDLE;
                end

            endcase
        end
    end

endmodule