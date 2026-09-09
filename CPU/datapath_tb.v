`include "datapath.v"

module datapath_16bit_tb;
  reg         clk;
  reg         reset;
  reg         write_enable;
  reg         writeback_select;
  reg  [ 3:0] alu_op;
  reg  [15:0] immediate;
  reg  [ 2:0] read_addr_a;
  reg  [ 2:0] read_addr_b;
  reg  [ 2:0] write_addr;
  wire [15:0] write_reg_data;

  // Writeback select codes
  localparam WRITEBACK_SELECT_ALU = 0;
  localparam WRITEBACK_SELECT_IMMEDIATE = 1;

  datapath_16bit dut (
      .clk             (clk),
      .reset           (reset),
      .write_enable    (write_enable),
      .writeback_select(writeback_select),
      .alu_op          (alu_op),
      .immediate       (immediate),
      .read_addr_a     (read_addr_a),
      .read_addr_b     (read_addr_b),
      .write_addr      (write_addr),
      .write_reg_data  (write_reg_data)
  );

  task test_case(input [15:0] test_number, input tc_reset, input tc_write_enable,
                 input tc_writeback_select, input [3:0] tc_alu_op, input [15:0] tc_immediate,
                 input [2:0] tc_read_addr_a, input [2:0] tc_read_addr_b, input [2:0] tc_write_addr,
                 input [15:0] expected_write_reg_data);
    begin

      reset            = tc_reset;
      write_enable     = tc_write_enable;
      writeback_select = tc_writeback_select;
      alu_op           = tc_alu_op;
      immediate        = tc_immediate;
      read_addr_a      = tc_read_addr_a;
      read_addr_b      = tc_read_addr_b;
      write_addr       = tc_write_addr;

      clk = 0;
      #10;
      clk = 1;
      #10;

      if (write_reg_data !== expected_write_reg_data)
        $display(
            "FAILED Test #%d - reset: %d, write_enable: %d, writeback_select: %d, alu_op: %d, immediate: %d, read_addr_a: %d, read_addr_b: %d, write_addr: %d | write_reg_data: %d, expected_write_reg_data: %d"
                ,
            test_number,
            reset,
            write_enable,
            writeback_select,
            alu_op,
            immediate,
            read_addr_a,
            read_addr_b,
            write_addr,
            write_reg_data,
            expected_write_reg_data
        );
    end

  endtask


  initial begin
    // ------------------------------------------------------------
    // Reset first so this section starts from known state
    // ------------------------------------------------------------
    test_case(.test_number(0), .tc_reset(1), .tc_write_enable(0),
              .tc_writeback_select(WRITEBACK_SELECT_ALU), .tc_alu_op(`ALU_OP_ADD),
              .tc_immediate(16'd0), .tc_read_addr_a(3'd0), .tc_read_addr_b(3'd1),
              .tc_write_addr(3'd0), .expected_write_reg_data(16'd0));


    // ------------------------------------------------------------
    // Load two different registers with immediates
    // r1 = 12
    // ------------------------------------------------------------
    test_case(.test_number(1), .tc_reset(0), .tc_write_enable(1),
              .tc_writeback_select(WRITEBACK_SELECT_IMMEDIATE),
              .tc_alu_op(`ALU_OP_ADD),  // don't care
              .tc_immediate(16'd12), .tc_read_addr_a(3'd0),  // don't care
              .tc_read_addr_b(3'd0),  // don't care
              .tc_write_addr(3'd1), .expected_write_reg_data(16'd12));

    // r2 = 7
    test_case(.test_number(2), .tc_reset(0), .tc_write_enable(1),
              .tc_writeback_select(WRITEBACK_SELECT_IMMEDIATE), .tc_alu_op(`ALU_OP_ADD),
              .tc_immediate(16'd7), .tc_read_addr_a(3'd0), .tc_read_addr_b(3'd0),
              .tc_write_addr(3'd2), .expected_write_reg_data(16'd7));


    // ------------------------------------------------------------
    // r3 = r1 + r2 = 19
    // ------------------------------------------------------------
    test_case(.test_number(3), .tc_reset(0), .tc_write_enable(1),
              .tc_writeback_select(WRITEBACK_SELECT_ALU), .tc_alu_op(`ALU_OP_ADD),
              .tc_immediate(16'd0), .tc_read_addr_a(3'd1), .tc_read_addr_b(3'd2),
              .tc_write_addr(3'd3), .expected_write_reg_data(16'd19));


    // ------------------------------------------------------------
    // Prove that r3 really got written:
    // r4 = r3 - r2 = 12
    // ------------------------------------------------------------
    test_case(.test_number(4), .tc_reset(0), .tc_write_enable(1),
              .tc_writeback_select(WRITEBACK_SELECT_ALU), .tc_alu_op(`ALU_OP_SUB),
              .tc_immediate(16'd0), .tc_read_addr_a(3'd3), .tc_read_addr_b(3'd2),
              .tc_write_addr(3'd4), .expected_write_reg_data(16'd12));


    // ------------------------------------------------------------
    // Underflow:
    // r5 = r2 - r1 = 7 - 12 = -5 = 65531 in 16 bits
    // ------------------------------------------------------------
    test_case(.test_number(5), .tc_reset(0), .tc_write_enable(1),
              .tc_writeback_select(WRITEBACK_SELECT_ALU), .tc_alu_op(`ALU_OP_SUB),
              .tc_immediate(16'd0), .tc_read_addr_a(3'd2), .tc_read_addr_b(3'd1),
              .tc_write_addr(3'd5), .expected_write_reg_data(16'd65531));


    // ------------------------------------------------------------
    // Bitwise operation:
    // r6 = 12 XOR 7 = 11
    // ------------------------------------------------------------
    test_case(.test_number(6), .tc_reset(0), .tc_write_enable(1),
              .tc_writeback_select(WRITEBACK_SELECT_ALU), .tc_alu_op(`ALU_OP_XOR),
              .tc_immediate(16'd0), .tc_read_addr_a(3'd1), .tc_read_addr_b(3'd2),
              .tc_write_addr(3'd6), .expected_write_reg_data(16'd11));


    // ------------------------------------------------------------
    // write_enable = 0.
    // ALU computes 19, but r7 must NOT receive it, so write_reg_data remains zero.
    // ------------------------------------------------------------
    test_case(.test_number(7), .tc_reset(0), .tc_write_enable(0),
              .tc_writeback_select(WRITEBACK_SELECT_ALU), .tc_alu_op(`ALU_OP_ADD),
              .tc_immediate(16'd0), .tc_read_addr_a(3'd1), .tc_read_addr_b(3'd2),
              .tc_write_addr(3'd7), .expected_write_reg_data(16'd0));


    // ------------------------------------------------------------
    // Now use r7. Since previous write was disabled,
    // r7 should still be zero.
    // r0 = r7 + r7 = 0
    // ------------------------------------------------------------
    test_case(.test_number(8), .tc_reset(0), .tc_write_enable(1),
              .tc_writeback_select(WRITEBACK_SELECT_ALU), .tc_alu_op(`ALU_OP_ADD),
              .tc_immediate(16'd0), .tc_read_addr_a(3'd7), .tc_read_addr_b(3'd7),
              .tc_write_addr(3'd0), .expected_write_reg_data(16'd0));


    // ------------------------------------------------------------
    // Overwrite an existing register:
    // r1 = 200
    // ------------------------------------------------------------
    test_case(.test_number(9), .tc_reset(0), .tc_write_enable(1),
              .tc_writeback_select(WRITEBACK_SELECT_IMMEDIATE), .tc_alu_op(`ALU_OP_ADD),
              .tc_immediate(16'd200), .tc_read_addr_a(3'd0), .tc_read_addr_b(3'd0),
              .tc_write_addr(3'd1), .expected_write_reg_data(16'd200));


    // ------------------------------------------------------------
    // Verify overwrite:
    // r0 = r1 + r2 = 200 + 7 = 207
    // ------------------------------------------------------------
    test_case(.test_number(10), .tc_reset(0), .tc_write_enable(1),
              .tc_writeback_select(WRITEBACK_SELECT_ALU), .tc_alu_op(`ALU_OP_ADD),
              .tc_immediate(16'd0), .tc_read_addr_a(3'd1), .tc_read_addr_b(3'd2),
              .tc_write_addr(3'd0), .expected_write_reg_data(16'd207));

    $display("Tests finished");
    $finish;

  end

endmodule
