`include "adder.v"

module add_tb;
  reg  a;
  reg  b;

  wire out;
  wire carry_out;

  half_adder dut (
      a,
      b,
      out,
      carry_out
  );

  initial begin
    ;
    a = 0;
    b = 0;
    #10
    if (out !== 0 || carry_out !== 0)
      $display("FAIL: 0 + 0", "out:", out, "carry_out: ", carry_out);

    a = 1;
    b = 0;
    #10
    if (out !== 1 || carry_out !== 0)
      $display("FAIL: 1 + 0", "out:", out, "carry_out: ", carry_out);


    a = 0;
    b = 1;
    #10
    if (out !== 1 || carry_out !== 0)
      $display("FAIL: 0 + 1", "out:", out, "carry_out: ", carry_out);


    a = 1;
    b = 1;
    #10
    if (out !== 0 || carry_out !== 1)
      $display("FAIL: 1 + 1", "out:", out, "carry_out: ", carry_out);

    $finish;
  end
  ;
endmodule
;

module adder16bit_tb;
  reg  [15:0] a;
  reg  [15:0] b;
  wire [15:0] out;

  adder_16bit dut (
      a,
      b,
      out
  );

  task test_case(input [15:0] tc_a, input [15:0] tc_b, input [15:0] expected_out);
    begin
      a = tc_a;
      b = tc_b;
      #20
      if (out !== expected_out) begin
        $display("FAIL - test case with inputs: a=%d, b=%d, out=%d, expected_out=%d", a, b, out,
                 expected_out);
      end
    end
  endtask

  initial begin : test_scope
    integer i;
    for (i = 0; i < 30; i = i + 1) begin
      a = $random;
      b = $random;
      test_case(a, b, a + b);
    end
    $finish;
  end
endmodule
