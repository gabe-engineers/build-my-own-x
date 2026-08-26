module adder8bit_tb;
  reg  [7:0] a;
  reg  [7:0] b;
  wire [7:0] out;

  adder_8bit dut (
      a,
      b,
      out
  );

  task test_case(input [7:0] tc_a, input [7:0] tc_b, input [7:0] expected_out);
    begin
      a = tc_a;
      b = tc_b;
      #20
      if (out !== expected_out) begin
        $display("FAIL - test case with inputs: a=%b, b=%b, out=%b, expected_out=%b", a, b, out,
                 expected_out);
      end
    end
  endtask

  initial begin
    test_case(8'd0, 8'd0, 8'd0);
    test_case(8'd1, 8'd1, 8'd2);
    test_case(8'd5, 8'd7, 8'd12);
    test_case(8'd10, 8'd20, 8'd30);
    test_case(8'd50, 8'd75, 8'd125);
    test_case(8'd100, 8'd100, 8'd200);

    test_case(8'd127, 8'd1, 8'd128);
    test_case(8'd200, 8'd55, 8'd255);

    // 8-bit overflow / wraparound
    test_case(8'd255, 8'd1, 8'd0);
    test_case(8'd200, 8'd100, 8'd44);
    test_case(8'd255, 8'd255, 8'd254);
    $display("Tests finished");
    $finish;
  end
endmodule
