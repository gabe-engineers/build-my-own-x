`include "program_counter.v"

module program_counter_tb;

  reg         clk;
  reg         reset;
  reg         advance;
  reg         write_enable;
  reg  [15:0] write_data;
  wire [15:0] data_out;

  program_counter dut (
    .clk         (clk),
    .reset       (reset),
    .advance     (advance),
    .write_enable(write_enable),
    .write_data  (write_data),
    .data_out    (data_out)
  );


  task test_case(input [8:0] test_number, input tc_reset, input tc_advance, input tc_write_enable,
                 input [15:0] tc_write_data, input [15:0] expected_data_out);

    begin

      reset        = tc_reset;
      advance      = tc_advance;
      write_enable = tc_write_enable;
      write_data   = tc_write_data;

      clk = 0;
      #10;
      clk = 1;
      #10;

      if (data_out != expected_data_out) begin
        $display(
            "Failed Test Case #%d - reset: %d, advance: %d, write_enable: %d, write_data: %d | data_out: %d, expected_data_out: %d",
            test_number, reset, advance, write_enable, write_data, data_out, expected_data_out);
      end

    end

  endtask

  initial begin

    // Reset initializes PC to zero
    test_case(.test_number(1), .tc_reset(1'b1), .tc_advance(1'b0), .tc_write_enable(1'b0),
              .tc_write_data(16'h0000), .expected_data_out(16'h0000));

    // Hold after reset
    test_case(.test_number(2), .tc_reset(1'b0), .tc_advance(1'b0), .tc_write_enable(1'b0),
              .tc_write_data(16'hAAAA), .expected_data_out(16'h0000));

    // Advance: 0 -> 1
    test_case(.test_number(3), .tc_reset(1'b0), .tc_advance(1'b1), .tc_write_enable(1'b0),
              .tc_write_data(16'h0000), .expected_data_out(16'h0001));

    // Advance again: 1 -> 2
    test_case(.test_number(4), .tc_reset(1'b0), .tc_advance(1'b1), .tc_write_enable(1'b0),
              .tc_write_data(16'h0000), .expected_data_out(16'h0002));

    // Hold should retain current PC
    test_case(.test_number(5), .tc_reset(1'b0), .tc_advance(1'b0), .tc_write_enable(1'b0),
              .tc_write_data(16'hFFFF), .expected_data_out(16'h0002));

    // Explicit write: PC = 0x1234
    test_case(.test_number(6), .tc_reset(1'b0), .tc_advance(1'b0), .tc_write_enable(1'b1),
              .tc_write_data(16'h1234), .expected_data_out(16'h1234));

    // Hold written value
    test_case(.test_number(7), .tc_reset(1'b0), .tc_advance(1'b0), .tc_write_enable(1'b0),
              .tc_write_data(16'h0000), .expected_data_out(16'h1234));

    // Advance after write: 0x1234 -> 0x1235
    test_case(.test_number(8), .tc_reset(1'b0), .tc_advance(1'b1), .tc_write_enable(1'b0),
              .tc_write_data(16'h0000), .expected_data_out(16'h1235));

    // Write should beat advance
    test_case(.test_number(9), .tc_reset(1'b0), .tc_advance(1'b1), .tc_write_enable(1'b1),
              .tc_write_data(16'hABCD), .expected_data_out(16'hABCD));

    // Reset should beat write and advance
    test_case(.test_number(10), .tc_reset(1'b1), .tc_advance(1'b1), .tc_write_enable(1'b1),
              .tc_write_data(16'hFFFF), .expected_data_out(16'h0000));

    // Write maximum value
    test_case(.test_number(11), .tc_reset(1'b0), .tc_advance(1'b0), .tc_write_enable(1'b1),
              .tc_write_data(16'hFFFF), .expected_data_out(16'hFFFF));

    // Advance wraps: 0xFFFF -> 0x0000
    test_case(.test_number(12), .tc_reset(1'b0), .tc_advance(1'b1), .tc_write_enable(1'b0),
              .tc_write_data(16'h0000), .expected_data_out(16'h0000));

    // Explicit write of zero
    test_case(.test_number(13), .tc_reset(1'b0), .tc_advance(1'b0), .tc_write_enable(1'b1),
              .tc_write_data(16'h0000), .expected_data_out(16'h0000));

    // Write arbitrary pattern
    test_case(.test_number(14), .tc_reset(1'b0), .tc_advance(1'b0), .tc_write_enable(1'b1),
              .tc_write_data(16'hA5A5), .expected_data_out(16'hA5A5));

    // Advance arbitrary pattern
    test_case(.test_number(15), .tc_reset(1'b0), .tc_advance(1'b1), .tc_write_enable(1'b0),
              .tc_write_data(16'h0000), .expected_data_out(16'hA5A6));

    $finish;

  end

endmodule
