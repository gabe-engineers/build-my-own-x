`include "ram.v"

module memory_tb;

  reg        clk;
  reg [ 8:0] address;
  reg        write_enable;
  reg [15:0] write_data;
  reg [15:0] read_data;

  task test_case(input [7:0] test_number, input [8:0] tc_address, input tc_write_enable,
                 input [15:0] tc_write_data, input [15:0] expected_read_data);
    begin
      address      = tc_address;
      write_enable = tc_write_enable;
      write_data   = tc_write_data;

      clk = 0;
      #10;
      clk = 1;
      #10;

      if (read_data != expected_read_data)
        $display(
            "Failed Test Case #%d - tc_address: %d, tc_write_enable: %d, tc_write_data: %d | read_data: %d, expected_read_data: %d"
                ,
            test_number,
            tc_address,
            tc_write_enable,
            tc_write_data,
            expected_read_data
        );
    end
  endtask

  initial begin

    // Write/read lowest address
    test_case(.test_number(8'd1), .tc_address(9'd0), .tc_write_enable(1'b1),
              .tc_write_data(16'h1234), .expected_read_data(16'h1234));

    // Hold address 0; disabled write must not change it
    test_case(.test_number(8'd2), .tc_address(9'd0), .tc_write_enable(1'b0),
              .tc_write_data(16'hFFFF), .expected_read_data(16'h1234));

    // Write a different location
    test_case(.test_number(8'd3), .tc_address(9'd1), .tc_write_enable(1'b1),
              .tc_write_data(16'hABCD), .expected_read_data(16'hABCD));

    // Verify address 0 was not affected by writing address 1
    test_case(.test_number(8'd4), .tc_address(9'd0), .tc_write_enable(1'b0),
              .tc_write_data(16'h0000), .expected_read_data(16'h1234));

    // Verify address 1 still contains its value
    test_case(.test_number(8'd5), .tc_address(9'd1), .tc_write_enable(1'b0),
              .tc_write_data(16'h0000), .expected_read_data(16'hABCD));

    // Write arbitrary middle address
    test_case(.test_number(8'd6), .tc_address(9'd256), .tc_write_enable(1'b1),
              .tc_write_data(16'hA5A5), .expected_read_data(16'hA5A5));

    // Write highest valid address
    test_case(.test_number(8'd7), .tc_address(9'd511), .tc_write_enable(1'b1),
              .tc_write_data(16'hDEAD), .expected_read_data(16'hDEAD));

    // Verify neighboring address is independent
    test_case(.test_number(8'd8), .tc_address(9'd510), .tc_write_enable(1'b1),
              .tc_write_data(16'hBEEF), .expected_read_data(16'hBEEF));

    // Make sure address 511 survived write to 510
    test_case(.test_number(8'd9), .tc_address(9'd511), .tc_write_enable(1'b0),
              .tc_write_data(16'h0000), .expected_read_data(16'hDEAD));

    // Overwrite an existing location
    test_case(.test_number(8'd10), .tc_address(9'd1), .tc_write_enable(1'b1),
              .tc_write_data(16'h5555), .expected_read_data(16'h5555));

    // Verify overwrite persisted
    test_case(.test_number(8'd11), .tc_address(9'd1), .tc_write_enable(1'b0),
              .tc_write_data(16'hAAAA), .expected_read_data(16'h5555));

    // Writing zero is a real write
    test_case(.test_number(8'd12), .tc_address(9'd256), .tc_write_enable(1'b1),
              .tc_write_data(16'h0000), .expected_read_data(16'h0000));

    // Verify zero persisted
    test_case(.test_number(8'd13), .tc_address(9'd256), .tc_write_enable(1'b0),
              .tc_write_data(16'hFFFF), .expected_read_data(16'h0000));

    // Interesting full-width bit pattern
    test_case(.test_number(8'd14), .tc_address(9'd42), .tc_write_enable(1'b1),
              .tc_write_data(16'b1010101010101010), .expected_read_data(16'b1010101010101010));

    // Opposite bit pattern in another location
    test_case(.test_number(8'd15), .tc_address(9'd43), .tc_write_enable(1'b1),
              .tc_write_data(16'b0101010101010101), .expected_read_data(16'b0101010101010101));

    // Return to address 42 and verify isolation
    test_case(.test_number(8'd16), .tc_address(9'd42), .tc_write_enable(1'b0),
              .tc_write_data(16'h0000), .expected_read_data(16'hAAAA));

    $finish;
  end

endmodule

