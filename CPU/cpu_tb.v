`include "isa.vh"
`include "cpu.v"

module cpu_tb;
  reg         clk;
  reg         reset;
  reg  [15:0] mem_read_data;
  wire [ 8:0] mem_address;
  wire [15:0] mem_write_data;
  wire        mem_write_enable;
  wire        halted;

  cpu dut (
      .clk             (clk),
      .reset           (reset),
      .mem_read_data   (mem_read_data),
      .mem_address     (mem_address),
      .mem_write_data  (mem_write_data),
      .mem_write_enable(mem_write_enable),
      .halted          (halted)
  );

  task test_case(input [7:0] test_number, input [15:0] tc_instruction, input [15:0] tc_load_data,
                 input expected_mem_write_enable, input [8:0] expected_mem_address,
                 input [15:0] expected_mem_write_data, input expected_halted);
    reg        observed_mem_write_enable;
    reg [ 8:0] observed_mem_address;
    reg [15:0] observed_mem_write_data;
    begin
      mem_read_data = tc_instruction;

      // FETCH
      clk = 0;
      #10;
      clk = 1;
      #10;

      // DECODE and EXECUTE
      clk = 0;
      #10;
      clk = 1;
      #10;

      // extra MEMORY cycle
      if (tc_instruction[15:12] == `OP_LOAD || tc_instruction[15:12] == `OP_STORE) begin
        clk = 0;
        mem_read_data = tc_load_data;
        #10;

        observed_mem_write_enable = mem_write_enable;
        observed_mem_address = mem_address;
        observed_mem_write_data = mem_write_data;

        clk = 1;
        #10;
      end else begin
        observed_mem_write_enable = mem_write_enable;
        observed_mem_address = mem_address;
        observed_mem_write_data = mem_write_data;
      end

      if (observed_mem_write_enable !== expected_mem_write_enable ||
          halted !== expected_halted ||
          (expected_mem_write_enable &&
           (observed_mem_address !== expected_mem_address ||
            observed_mem_write_data !== expected_mem_write_data))) begin
        $fatal(
            1,
            "Test case #%d failed - instruction: %h | write_enable: %d, address: %d, write_data: %d, halted: %d | expected write_enable: %d, address: %d, write_data: %d, halted: %d",
            test_number, tc_instruction, observed_mem_write_enable, observed_mem_address,
            observed_mem_write_data, halted, expected_mem_write_enable, expected_mem_address,
            expected_mem_write_data, expected_halted);
      end
    end
  endtask

  initial begin
    clk = 0;
    reset = 1;
    mem_read_data = 16'b0;
    #10;
    clk = 1;
    #10;
    reset = 0;

    // LDI R1, 0x05A
    test_case(.test_number(1), .tc_instruction({`OP_LDI, 3'd1, 9'h05A}), .tc_load_data(16'b0),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    $stop;

    // STORE R1, [100] proves that LDI wrote 0x05A to R1.
    test_case(.test_number(2), .tc_instruction({`OP_STORE, 3'd1, 9'd100}), .tc_load_data(16'b0),
              .expected_mem_write_enable(1'b1), .expected_mem_address(9'd100),
              .expected_mem_write_data(16'h005A), .expected_halted(1'b0));

    // LOAD R2, [100] using the value previously produced by LDI.
    test_case(.test_number(3), .tc_instruction({`OP_LOAD, 3'd2, 9'd100}), .tc_load_data(16'h005A),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'd100),
              .expected_mem_write_data(16'b0), .expected_halted(1'b0));

    // STORE R2, [101] proves that LOAD wrote 0x05A to R2.
    test_case(.test_number(4), .tc_instruction({`OP_STORE, 3'd2, 9'd101}), .tc_load_data(16'b0),
              .expected_mem_write_enable(1'b1), .expected_mem_address(9'd101),
              .expected_mem_write_data(16'h005A), .expected_halted(1'b0));

    test_case(.test_number(5), .tc_instruction({`OP_HALT, 12'b0}), .tc_load_data(16'b0),
              .expected_mem_write_enable(1'b0), .expected_mem_address(9'b0),
              .expected_mem_write_data(16'b0), .expected_halted(1'b1));

    $finish;
  end

endmodule
