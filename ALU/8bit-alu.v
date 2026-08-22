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
      // ADD
      3'b000: out = add_out;

      // SUB
      3'b001: out = sub_out;

      // AND
      3'b010: out = a & b;

      // OR
      3'b011: out = a | b;
      // XOR
      3'b100: out = a ^ b;
      // SHL
      3'b101: out = a << b;
      // SHR
      3'b110: out = a >> b;
      // ZERO
      3'b111: out = 8'b00000000;
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
      8'b00000001,
      b_twos_compliment
  );
  adder_8bit adder (
      a,
      b_twos_compliment,
      out
  );

endmodule
