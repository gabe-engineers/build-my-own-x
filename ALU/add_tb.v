module add_tb;

reg a;
reg b;

wire out;
wire carry_out;

half_adder dut (
  a,
  b,
  out,
  carry_out
);

initial begin;
 a = 0; b = 0; #10
 if (out !== 0 || carry_out !== 0) $display("FAIL: 0 + 0", "out:", out, "carry_out: ", carry_out);

 a = 1; b = 0; #10
 if (out !== 1 || carry_out !== 0) $display("FAIL: 1 + 0", "out:", out, "carry_out: ", carry_out);
 

 a = 0; b = 1; #10
 if (out !== 1 || carry_out !== 0) $display("FAIL: 0 + 1", "out:", out, "carry_out: ", carry_out);


 a = 1; b = 1; #10
 if (out !== 0 || carry_out !== 1) $display("FAIL: 1 + 1", "out:", out, "carry_out: ", carry_out);

$finish;
end;
endmodule;
