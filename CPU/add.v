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
