module SPI_Clk_Div #(
    parameter CLK_DIV = 50   // 100MHz / (2*50) = 1MHz SCLK
)(
    input  wire clk,
    input  wire rst,
    input  wire en,          // only counts when transaction active
    output reg  tick         // one-cycle pulse at each half-period
);
    reg [5:0] cnt;

    always @(posedge clk) begin
        if (rst || !en) begin
            cnt  <= 0;
            tick <= 0;
        end else begin
            tick <= 0;
            if (cnt == CLK_DIV - 1) begin
                cnt  <= 0;
                tick <= 1;
            end else
                cnt <= cnt + 1;
        end
    end
endmodule