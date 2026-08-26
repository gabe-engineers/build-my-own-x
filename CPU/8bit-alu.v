`include "8bit-adder.v"
`include "alu_ops.vh"

module alu_8bit (
    input [2:0] op,
    input [7:0] a,
    input [7:0] b,
    output reg [7:0] out
);
  wire [7:0] add_out;
  wire [7:0] sub_out;
  wire [7:0] and_out;
  wire [7:0] or_out;
  wire [7:0] xor_out;
  wire [7:0] shl_out;
  wire [7:0] shr_out;

  adder_8bit add (
      a,
      b,
      add_out
  );

  subtracter_8bit sub (
      a,
      b,
      sub_out
  );

  always @(*) begin
    case (op)
      `ALU_OP_ADD: out = add_out;
      `ALU_OP_SUB: out = sub_out;
      `ALU_OP_AND: out = a & b;
      `ALU_OP_OR: out = a | b;
      `ALU_OP_XOR: out = a ^ b;
      `ALU_OP_SHL: out = a << b;
      `ALU_OP_SHR: out = a >> b;
      `ALU_OP_ZEROS: out = 8'd0;
    endcase
  end

endmodule

module subtracter_8bit (
    input  [7:0] a,
    input  [7:0] b,
    output [7:0] out
);
  wire [7:0] b_ones_compliment = ~b;
  wire [7:0] b_twos_compliment;
  adder_8bit twos_compliment_adder (
      b_ones_compliment,
      8'd1,
      b_twos_compliment
  );
  adder_8bit adder (
      a,
      b_twos_compliment,
      out
  );

endmodule
