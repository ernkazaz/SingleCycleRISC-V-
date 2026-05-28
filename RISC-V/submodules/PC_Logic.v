module PC_Logic(
    input  wire       Branch,
    input  wire       Zero,
    input  wire [1:0] Jump,
    output wire [1:0] PCSrc
);

    // PCSrc mapping for your Datapath's Mux_4to1:
    // 2'b00: PCPlus4
    // 2'b01: PCTarget (Used for Branches and JAL)
    // 2'b10: ALUResult (Used exclusively for JALR)

    assign PCSrc = (Jump == 2'b10)                   ? 2'b10 : // JALR takes priority
                   (Jump == 2'b01 || (Branch & Zero)) ? 2'b01 : // JAL or Successful BEQ
                                                       2'b00;  // Default path
                                                       
endmodule