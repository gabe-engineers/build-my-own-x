module register_8bit_tb;

  reg reset;
  reg write_enable;
  reg clk;
  reg [7:0] data_in;
  wire [7:0] data_out;

  register_8bit dut (
      clk,
      reset,
      write_enable,
      data_in,
      data_out
  );

  task test_case(input tc_reset, input tc_write_enable, input [7:0] tc_data_in,
                 input [7:0] expected_out);
    begin
      reset        = tc_reset;
      write_enable = tc_write_enable;
      data_in      = tc_data_in;

      clk          = 1'b0;
      #10;
      clk = 1'b1;
      #10;

      if (data_out !== expected_out) begin
        $display("FAIL - reset=%b write_enable=%b data_in=%b | data_out=%b expected=%b", reset,
                 write_enable, data_in, data_out, expected_out);
      end
    end
  endtask

  initial begin
    clk = 0;

    // Reset should initialize register to zero
    test_case(1'b1, 1'b0, 8'hAA, 8'h00);

    // Normal write
    test_case(1'b0, 1'b1, 8'h42, 8'h42);

    // Write disabled: should retain old value
    test_case(1'b0, 1'b0, 8'h99, 8'h42);

    // Write another value
    test_case(1'b0, 1'b1, 8'hFF, 8'hFF);

    // Hold again
    test_case(1'b0, 1'b0, 8'h00, 8'hFF);

    // Writing zero should actually write zero
    test_case(1'b0, 1'b1, 8'h00, 8'h00);

    // Another arbitrary pattern
    test_case(1'b0, 1'b1, 8'b10101010, 8'b10101010);

    // Reset should override write_enable
    test_case(1'b1, 1'b1, 8'hFF, 8'h00);

    // After reset, disabled write should retain zero
    test_case(1'b0, 1'b0, 8'hCC, 8'h00);

    $display("Tests finished");
    $finish;
  end

endmodule
