`include "register_file.v"

module register_file_tb;

  reg         clk;
  reg         reset;
  reg         write_enable;
  reg  [ 2:0] write_addr;
  reg  [15:0] write_data;
  reg  [ 2:0] read_addr_a;
  reg  [ 2:0] read_addr_b;
  wire [15:0] read_data_a;
  wire [15:0] read_data_b;
  wire [15:0] write_reg_data;

  register_file dut (
      .clk         (clk),
      .reset       (reset),
      .write_enable(write_enable),
      .write_addr  (write_addr),
      .write_data  (write_data),
      .read_addr_a (read_addr_a),
      .read_addr_b (read_addr_b),
      .read_data_a (read_data_a),
      .read_data_b (read_data_b),
      .write_reg_data(write_reg_data)
  );

  task test_case(input [15:0] test_number, input tc_reset, input tc_write_enable,
                 input [2:0] tc_write_addr, input [15:0] tc_write_data, input [2:0] tc_read_addr_a,
                 input [2:0] tc_read_addr_b, input [15:0] expected_a, input [15:0] expected_b,
                 input [15:0] expected_write_reg_data);
    begin
      reset        = tc_reset;
      write_enable = tc_write_enable;
      write_addr   = tc_write_addr;
      write_data   = tc_write_data;
      read_addr_a  = tc_read_addr_a;
      read_addr_b  = tc_read_addr_b;

      clk          = 1'b0;
      #10;
      clk = 1'b1;
      #10;

      if (read_data_a !== expected_a || read_data_b !== expected_b ||
          write_reg_data !== expected_write_reg_data) begin
        $display(
            "FAILED Test #%d: reset=%b we=%b wa=%d wd=%h ra=%d rb=%d | got a=%h b=%h write_reg=%h | expected a=%h b=%h write_reg=%h",
            test_number, reset, write_enable, write_addr, write_data, read_addr_a, read_addr_b,
            read_data_a, read_data_b, write_reg_data, expected_a, expected_b, expected_write_reg_data);
      end
    end
  endtask

  initial begin

    // Initial state is zero 
    test_case(.test_number(0), .tc_reset(0), .tc_write_enable(0), .tc_write_addr(3'd0),
              .tc_write_data(16'h0000), .tc_read_addr_a(3'd0), .tc_read_addr_b(3'd7),
              .expected_a(16'h0000), .expected_b(16'h0000), .expected_write_reg_data(16'h0000));

    // Resets still keeps it at zero
    test_case(.test_number(1), .tc_reset(1), .tc_write_enable(0), .tc_write_addr(3'd0),
              .tc_write_data(16'h0000), .tc_read_addr_a(3'd0), .tc_read_addr_b(3'd7),
              .expected_a(16'h0000), .expected_b(16'h0000), .expected_write_reg_data(16'h0000));

    // Write register 3
    test_case(.test_number(2), .tc_reset(0), .tc_write_enable(1), .tc_write_addr(3'd3),
              .tc_write_data(16'h4242), .tc_read_addr_a(3'd3), .tc_read_addr_b(3'd0),
              .expected_a(16'h4242), .expected_b(16'h0000), .expected_write_reg_data(16'h4242));

    // Write register 6; register 3 must survive
    test_case(.test_number(3), .tc_reset(0), .tc_write_enable(1), .tc_write_addr(3'd6),
              .tc_write_data(16'hAAAA), .tc_read_addr_a(3'd3), .tc_read_addr_b(3'd6),
              .expected_a(16'h4242), .expected_b(16'hAAAA), .expected_write_reg_data(16'hAAAA));

    // Read them in the opposite order
    test_case(.test_number(4), .tc_reset(0), .tc_write_enable(0), .tc_write_addr(3'd0),
              .tc_write_data(16'hFFFF), .tc_read_addr_a(3'd6), .tc_read_addr_b(3'd3),
              .expected_a(16'hAAAA), .expected_b(16'h4242), .expected_write_reg_data(16'h0000));

    // Disabled write must do nothing
    test_case(.test_number(5), .tc_reset(0), .tc_write_enable(0), .tc_write_addr(3'd3),
              .tc_write_data(16'h9999), .tc_read_addr_a(3'd3), .tc_read_addr_b(3'd6),
              .expected_a(16'h4242), .expected_b(16'hAAAA), .expected_write_reg_data(16'h4242));

    // Overwrite one register only
    test_case(.test_number(6), .tc_reset(0), .tc_write_enable(1), .tc_write_addr(3'd3),
              .tc_write_data(16'hFFFF), .tc_read_addr_a(3'd3), .tc_read_addr_b(3'd6),
              .expected_a(16'hFFFF), .expected_b(16'hAAAA), .expected_write_reg_data(16'hFFFF));

    // Both read ports can read the same register
    test_case(.test_number(7), .tc_reset(0), .tc_write_enable(0), .tc_write_addr(3'd0),
              .tc_write_data(16'h0000), .tc_read_addr_a(3'd6), .tc_read_addr_b(3'd6),
              .expected_a(16'hAAAA), .expected_b(16'hAAAA), .expected_write_reg_data(16'h0000));

    // Reset clears registers regardless of previous contents
    test_case(.test_number(8), .tc_reset(1), .tc_write_enable(0), .tc_write_addr(3'd0),
              .tc_write_data(16'h0000), .tc_read_addr_a(3'd3), .tc_read_addr_b(3'd6),
              .expected_a(16'h0000), .expected_b(16'h0000), .expected_write_reg_data(16'h0000));

    // Reset should beat a simultaneous write
    test_case(.test_number(9), .tc_reset(1), .tc_write_enable(1), .tc_write_addr(3'd5),
              .tc_write_data(16'hCCCC), .tc_read_addr_a(3'd5), .tc_read_addr_b(3'd6),
              .expected_a(16'h0000), .expected_b(16'h0000), .expected_write_reg_data(16'h0000));

    // write_reg_data reports the value that was just written to the selected register.
    test_case(.test_number(10), .tc_reset(0), .tc_write_enable(1), .tc_write_addr(3'd7),
              .tc_write_data(16'h1357), .tc_read_addr_a(3'd0), .tc_read_addr_b(3'd7),
              .expected_a(16'h0000), .expected_b(16'h1357), .expected_write_reg_data(16'h1357));

    // A disabled write leaves write_reg_data at the selected register's stored value.
    test_case(.test_number(11), .tc_reset(0), .tc_write_enable(0), .tc_write_addr(3'd7),
              .tc_write_data(16'hDEAD), .tc_read_addr_a(3'd7), .tc_read_addr_b(3'd0),
              .expected_a(16'h1357), .expected_b(16'h0000), .expected_write_reg_data(16'h1357));

    // write_reg_data tracks a different write address independently of the read ports.
    test_case(.test_number(12), .tc_reset(0), .tc_write_enable(1), .tc_write_addr(3'd0),
              .tc_write_data(16'h8001), .tc_read_addr_a(3'd0), .tc_read_addr_b(3'd7),
              .expected_a(16'h8001), .expected_b(16'h1357), .expected_write_reg_data(16'h8001));

    // Retargeting the write address without writing exposes that register's prior value.
    test_case(.test_number(13), .tc_reset(0), .tc_write_enable(0), .tc_write_addr(3'd7),
              .tc_write_data(16'h0000), .tc_read_addr_a(3'd0), .tc_read_addr_b(3'd7),
              .expected_a(16'h8001), .expected_b(16'h1357), .expected_write_reg_data(16'h1357));

    $finish;
  end
endmodule
