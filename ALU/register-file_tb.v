module register_file_tb;

  reg clk;
  reg reset;
  reg write_enable;
  reg [2:0] write_addr;
  reg [7:0] write_data;
  reg [2:0] read_addr_a;
  reg [2:0] read_addr_b;
  wire [7:0] read_data_a;
  wire [7:0] read_data_b;

  register_file dut (
      .clk(clk),
      .reset(reset),
      .write_enable(write_enable),
      .write_addr(write_addr),
      .write_data(write_data),
      .read_addr_a(read_addr_a),
      .read_addr_b(read_addr_b),
      .read_data_a(read_data_a),
      .read_data_b(read_data_b)
  );

  task test_case(input tc_reset, input tc_write_enable, input [2:0] tc_write_addr,
                 input [7:0] tc_write_data, input [2:0] tc_read_addr_a, input [2:0] tc_read_addr_b,
                 input [7:0] expected_a, input [7:0] expected_b);
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

      if (read_data_a !== expected_a || read_data_b !== expected_b) begin
        $display(
            "FAIL: reset=%b we=%b wa=%d wd=%h ra=%d rb=%d | got a=%h b=%h | expected a=%h b=%h",
            reset, write_enable, write_addr, write_data, read_addr_a, read_addr_b, read_data_a,
            read_data_b, expected_a, expected_b);
      end
    end
  endtask

  initial begin
    // Clear everything first
    test_case(1, 0, 3'd0, 8'h00, 3'd0, 3'd7, 8'h00, 8'h00);

    // Write register 3
    test_case(0, 1, 3'd3, 8'h42, 3'd3, 3'd0, 8'h42, 8'h00);

    // Write register 6; register 3 must survive
    test_case(0, 1, 3'd6, 8'hAA, 3'd3, 3'd6, 8'h42, 8'hAA);

    // Read them in the opposite order
    test_case(0, 0, 3'd0, 8'hFF, 3'd6, 3'd3, 8'hAA, 8'h42);

    // Disabled write must do nothing
    test_case(0, 0, 3'd3, 8'h99, 3'd3, 3'd6, 8'h42, 8'hAA);

    // Overwrite one register only
    test_case(0, 1, 3'd3, 8'hFF, 3'd3, 3'd6, 8'hFF, 8'hAA);

    // Both read ports can read the same register
    test_case(0, 0, 3'd0, 8'h00, 3'd6, 3'd6, 8'hAA, 8'hAA);

    // Reset clears registers regardless of previous contents
    test_case(1, 0, 3'd0, 8'h00, 3'd3, 3'd6, 8'h00, 8'h00);

    // Reset should beat a simultaneous write
    test_case(1, 1, 3'd5, 8'hCC, 3'd5, 3'd6, 8'h00, 8'h00);

    $finish;
  end
endmodule
