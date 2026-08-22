module add;

reg a;
reg b;
reg carry_in;

wire out;
wire carry_out;

full_adder dut (
  a,
  b,
  carry_in,
  out,
  carry_out
);

task test_case(
  input test_a,
  input test_b,
  input test_carry_in,
  input expected_out,
  input expected_carry,
);

  begin
      a = test_a;
      b = test_b;
      carry_in = test_carry_in;

      #10;

      if (out !== expected_out || carry_out !== expected_carry)
          $display(
              "FAIL: a=%b b=%b cin=%b | got out=%b carry=%b | expected out=%b carry=%b",
              a, b, carry_in,
              out, carry_out,
              expected_out, expected_carry
          );
  end
endtask

initial begin;
  test_case(0, 0, 0, 0, 0);
  test_case(0, 1, 0, 1, 0);
  test_case(1, 0, 0, 1, 0);
  test_case(1, 1, 0, 0, 1);

  test_case(0, 0, 1, 1, 0);
  test_case(0, 1, 1, 0, 1);
  test_case(1, 0, 1, 0, 1);
  test_case(1, 1, 1, 1, 1);

  $display("Tests finished");
$finish;
end;

endmodule;
