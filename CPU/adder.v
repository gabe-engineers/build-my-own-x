`include "gates.v"

module half_adder (
  input  a,
  input  b,
  output out,
  output carry
);
  xor_gate out_xor (
    a,
    b,
    out
  );
  and_gate carry_and (
    a,
    b,
    carry
  );
endmodule


module full_adder (
  input  a,
  input  b,
  input  carry_in,
  output out,
  output carry_out
);
  wire half_out;
  wire half_carry_out_1;
  wire half_carry_out_2;

  half_adder ha_1 (
    a,
    b,
    half_out,
    half_carry_out_1
  );

  half_adder ha_2 (
    half_out,
    carry_in,
    out,
    half_carry_out_2
  );

  xor_gate carry_out_xor (
    half_carry_out_1,
    half_carry_out_2,
    carry_out
  );
endmodule

module adder_16bit (
  input  [15:0] a,
  input  [15:0] b,
  output [15:0] out
);
  wire [15:0] carry;

  genvar i;

  generate
    for (i = 0; i < 16; i = i + 1) begin : ADDERS
      full_adder b1 (
        a[i],
        b[i],
        i > 0 ? carry[i-1] : 1'b0,
        out[i],
        carry[i]
      );
    end
  endgenerate

endmodule
