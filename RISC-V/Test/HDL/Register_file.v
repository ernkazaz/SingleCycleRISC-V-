module Register_file #(parameter WIDTH=32)
(
    input clk, write_enable, reset,
    input [4:0] Source_select_0, Source_select_1, Debug_Source_select, Destination_select,
    input [WIDTH-1:0] DATA,
    output [WIDTH-1:0] out_0, out_1, Debug_out
);

wire [WIDTH-1:0] Reg_Out [31:1];
wire [31:0] Reg_enable;

assign Reg_enable = 32'b1 << Destination_select;

genvar i;
generate
    for (i = 1 ; i < 32 ; i = i + 1) begin : registers
        Register_rsten #(WIDTH) Reg (
            .clk(clk),
            .reset(reset),
            .we(Reg_enable[i] & write_enable),
            .DATA(DATA),
            .OUT(Reg_Out[i])
        );
    end
endgenerate

assign out_0     = (Source_select_0 == 5'd0)     ? 32'b0 : Reg_Out[Source_select_0];
assign out_1     = (Source_select_1 == 5'd0)     ? 32'b0 : Reg_Out[Source_select_1];
assign Debug_out = (Debug_Source_select == 5'd0) ? 32'b0 : Reg_Out[Debug_Source_select];

endmodule