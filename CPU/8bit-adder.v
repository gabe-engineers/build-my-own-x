`include "add.v"

module adder_8bit (
    input  [7:0] a,
    input  [7:0] b,
    output [7:0] out
);
  wire [6:0] carry;

  full_adder b1 (
      a[0],
      b[0],
      1'b0,
      out[0],
      carry[0]
  );
  full_adder b2 (
      a[1],
      b[1],
      carry[0],
      out[1],
      carry[1]
  );
  full_adder b3 (
      a[2],
      b[2],
      carry[1],
      out[2],
      carry[2]
  );
  full_adder b4 (
      a[3],
      b[3],
      carry[2],
      out[3],
      carry[3]
  );
  full_adder b5 (
      a[4],
      b[4],
      carry[3],
      out[4],
      carry[4]
  );
  full_adder b6 (
      a[5],
      b[5],
      carry[4],
      out[5],
      carry[5]
  );
  full_adder b7 (
      a[6],
      b[6],
      carry[5],
      out[6],
      carry[6]
  );
  full_adder b8 (
      a[7],
      b[7],
      carry[6],
      out[7],
  );

endmodule
;
