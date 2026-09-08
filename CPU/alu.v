`include "adder.v"
`include "alu_ops.vh"

module alu_16bit (
  input      [ 3:0] op,
  input      [15:0] a,
  input      [15:0] b,
  output reg [15:0] out
);
  wire [15:0] add_out;
  wire [15:0] sub_out;
  wire [15:0] and_out;
  wire [15:0] or_out;
  wire [15:0] xor_out;
  wire [15:0] shl_out;
  wire [15:0] shr_out;

  adder_16bit add (
    a,
    b,
    add_out
  );

  subtracter_16bit sub (
    a,
    b,
    sub_out
  );

  always @(*) begin
    case (op)
      `ALU_OP_ADD:   out = add_out;
      `ALU_OP_SUB:   out = sub_out;
      `ALU_OP_AND:   out = a & b;
      `ALU_OP_OR:    out = a | b;
      `ALU_OP_XOR:   out = a ^ b;
      `ALU_OP_SHL:   out = a << b;
      `ALU_OP_SHR:   out = a >> b;
    endcase
  end

endmodule

module subtracter_16bit (
  input  [15:0] a,
  input  [15:0] b,
  output [15:0] out
);
  wire [15:0] b_ones_compliment = ~b;
  wire [15:0] b_twos_compliment;
  adder_16bit twos_compliment_adder (
    b_ones_compliment,
    16'd1,
    b_twos_compliment
  );
  adder_16bit adder (
    a,
    b_twos_compliment,
    out
  );

endmodule
