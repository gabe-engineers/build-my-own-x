`include "register.v"

module register_tb;

  reg         reset;
  reg         write_enable;
  reg         clk;
  reg  [15:0] data_in;
  wire [15:0] data_out;

  register dut (
    clk,
    reset,
    write_enable,
    data_in,
    data_out
  );

  task test_case(input tc_reset, input tc_write_enable, input [15:0] tc_data_in,
                 input [15:0] expected_out);
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
    test_case(1'b1, 1'b0, 16'hAAAA, 16'h0000);

    // Normal write
    test_case(1'b0, 1'b1, 16'h4242, 16'h4242);

    // Write disabled: should retain old value
    test_case(1'b0, 1'b0, 16'h9999, 16'h4242);

    // Write another value
    test_case(1'b0, 1'b1, 16'hFFFF, 16'hFFFF);

    // Hold again
    test_case(1'b0, 1'b0, 16'h0000, 16'hFFFF);

    // Writing zero should actually write zero
    test_case(1'b0, 1'b1, 16'h0000, 16'h0000);

    // Another arbitrary pattern
    test_case(1'b0, 1'b1, 16'b1010101010101010, 16'b1010101010101010);

    // Reset should override write_enable
    test_case(1'b1, 1'b1, 16'hFFFF, 16'h0000);

    // After reset, disabled write should retain zero
    test_case(1'b0, 1'b0, 16'hCCCC, 16'h0000);

    $display("Tests finished");
    $finish;
  end

endmodule
