module gates;

reg a;
reg b;

wire and_out;
wire or_out;
wire xor_out;

and_gate and_dut (
  a,
  b,
  and_out
);

or_gate or_dut (
  a,
  b,
  or_out
);

xor_gate xor_dut (
  a,
  b,
  xor_out
);

initial begin
  a = 0; b = 0;
  #10;
  if (and_out !== 0) $display("FAIL: 0 & 0");
  if (or_out !== 0) $display("FAIL: 0 | 0");
  if (xor_out !== 0) $display("FAIL: 0 ^ 0");

  a = 0; b = 1;
  #10;
  if (and_out !== 0) $display("FAIL: 0 & 1");
  if (or_out !== 1) $display("FAIL: 0 | 1");
  if (xor_out !== 1) $display("FAIL: 0 ^ 1");

  a = 1; b = 0;
  #10;
  if (and_out !== 0) $display("FAIL: 1 & 0");
  if (or_out !== 1) $display("FAIL: 1 | 0");
  if (xor_out !== 1) $display("FAIL: 1 ^ 0");

  a = 1; b = 1;
  #10;
  if (and_out !== 1) $display("FAIL: 1 & 1");
  if (or_out !== 1) $display("FAIL: 1 | 1");
  if (xor_out !== 0) $display("FAIL: 1 ^ 1");

  $display("Tests finished");
  $finish;
end



endmodule
