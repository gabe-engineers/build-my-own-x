`include "decoder.v"

module decoder_tb;

  reg  [15:0] instruction_data;
  wire [ 4:0] opcode;
  wire [ 2:0] dst_reg;
  wire [ 2:0] src_reg_a;
  wire [ 2:0] src_reg_b;
  wire [15:0] immediate;
  wire [ 8:0] address;

  decoder dut (
    instruction_data,
    opcode,
    dst_reg,
    src_reg_a,
    src_reg_b,
    immediate,
    address
  );

  task test_case(input [7:0] test_number, input [15:0] tc_instruction_data,
                 input [4:0] expected_opcode, input [2:0] expected_dst_reg,
                 input [2:0] expected_src_reg_a, input [2:0] expected_reg_b,
                 input [15:0] expected_immediate, input [8:0] expected_address);
    begin
      instruction_data = tc_instruction_data;

      #10;

      if (opcode != expected_opcode || dst_reg != expected_dst_reg ||
          src_reg_a != expected_src_reg_a || src_reg_b != expected_reg_b ||
          immediate != expected_immediate || address != expected_address) begin
        $display(
            "Test case #%d failed - instruction_data: %h | got opcode=%h dst_reg=%b src_reg_a=%h src_reg_b=%h immediate=%h address=%h | expected opcode=%h dst_reg=%b src_reg_a=%h src_reg_b=%h immediate=%h address=%h",
            test_number, instruction_data, opcode, dst_reg, src_reg_a, src_reg_b, immediate,
            address, expected_opcode, expected_dst_reg, expected_src_reg_a, expected_reg_b,
            expected_immediate, expected_address);
      end
    end
  endtask

  initial begin
    // LDI R3, 0x12A
    test_case(.test_number(1), .tc_instruction_data(16'b0000_011_100101010),
              .expected_opcode(`OP_LDI), .expected_dst_reg(8'd3), .expected_src_reg_a(8'd0),
              .expected_reg_b(8'd0), .expected_immediate(16'h012A), .expected_address(9'd0));

    // MOV R4, R1
    test_case(.test_number(2), .tc_instruction_data(16'b0001_100_001_000000),
              .expected_opcode(`OP_MOV), .expected_dst_reg(8'd4), .expected_src_reg_a(8'd1),
              .expected_reg_b(8'd0), .expected_immediate(16'd0), .expected_address(9'd0));

    // ADD R1, R2, R3
    test_case(.test_number(3), .tc_instruction_data(16'b0010_001_010_011_000),
              .expected_opcode(`OP_ADD), .expected_dst_reg(8'd1), .expected_src_reg_a(8'd2),
              .expected_reg_b(8'd3), .expected_immediate(16'd0), .expected_address(9'd0));

    // SUB R7, R0, R6
    test_case(.test_number(4), .tc_instruction_data(16'b0011_111_000_110_000),
              .expected_opcode(`OP_SUB), .expected_dst_reg(8'd7), .expected_src_reg_a(8'd0),
              .expected_reg_b(8'd6), .expected_immediate(16'd0), .expected_address(9'd0));

    // AND R0, R1, R7
    test_case(.test_number(5), .tc_instruction_data(16'b0100_000_001_111_000),
              .expected_opcode(`OP_AND), .expected_dst_reg(8'd0), .expected_src_reg_a(8'd1),
              .expected_reg_b(8'd7), .expected_immediate(16'd0), .expected_address(9'd0));

    // OR R3, R2, R5
    test_case(.test_number(6), .tc_instruction_data(16'b0101_011_010_101_000),
              .expected_opcode(`OP_OR), .expected_dst_reg(8'd3), .expected_src_reg_a(8'd2),
              .expected_reg_b(8'd5), .expected_immediate(16'd0), .expected_address(9'd0));

    // XOR R7, R7, R7
    test_case(.test_number(7), .tc_instruction_data(16'b0110_111_111_111_000),
              .expected_opcode(`OP_XOR), .expected_dst_reg(8'd7), .expected_src_reg_a(8'd7),
              .expected_reg_b(8'd7), .expected_immediate(16'd0), .expected_address(9'd0));

    // SHL R4, R4, R1
    test_case(.test_number(8), .tc_instruction_data(16'b0111_100_100_001_000),
              .expected_opcode(`OP_SHL), .expected_dst_reg(8'd4), .expected_src_reg_a(8'd4),
              .expected_reg_b(8'd1), .expected_immediate(16'd0), .expected_address(9'd0));

    // SHR R2, R7, R3
    test_case(.test_number(9), .tc_instruction_data(16'b1000_010_111_011_000),
              .expected_opcode(`OP_SHR), .expected_dst_reg(8'd2), .expected_src_reg_a(8'd7),
              .expected_reg_b(8'd3), .expected_immediate(16'd0), .expected_address(9'd0));

    // MUL R6, R5, R4
    test_case(.test_number(10), .tc_instruction_data(16'b1001_110_101_100_000),
              .expected_opcode(`OP_MUL), .expected_dst_reg(8'd6), .expected_src_reg_a(8'd5),
              .expected_reg_b(8'd4), .expected_immediate(16'd0), .expected_address(9'd0));

    // LOAD R5, [0x155]
    test_case(.test_number(11), .tc_instruction_data(16'b1010_101_101010101),
              .expected_opcode(`OP_LOAD), .expected_dst_reg(8'd5), .expected_src_reg_a(8'd0),
              .expected_reg_b(8'd0), .expected_immediate(16'd0), .expected_address(9'h155));

    // STORE R7, [0x1FF]
    test_case(.test_number(12), .tc_instruction_data(16'b1011_111_111111111),
              .expected_opcode(`OP_STORE), .expected_dst_reg(8'd7), .expected_src_reg_a(8'd0),
              .expected_reg_b(8'd0), .expected_immediate(16'd0), .expected_address(9'h1FF));

    // CMP R3, R6
    test_case(.test_number(13), .tc_instruction_data(16'b1100_011_110_000000),
              .expected_opcode(`OP_CMP), .expected_dst_reg(8'd0), .expected_src_reg_a(8'd3),
              .expected_reg_b(8'd6), .expected_immediate(16'd0), .expected_address(9'd0));

    // JMP 0x155
    test_case(.test_number(14), .tc_instruction_data(16'b1101_000_101010101),
              .expected_opcode(`OP_JMP), .expected_dst_reg(8'd0), .expected_src_reg_a(8'd0),
              .expected_reg_b(8'd0), .expected_immediate(16'd0), .expected_address(9'h155));

    // JZ 0x123
    test_case(.test_number(15), .tc_instruction_data(16'b1110_000_100100011),
              .expected_opcode(`OP_JZ), .expected_dst_reg(8'd0), .expected_src_reg_a(8'd0),
              .expected_reg_b(8'd0), .expected_immediate(16'd0), .expected_address(9'h123));

    // HALT
    test_case(.test_number(16), .tc_instruction_data(16'b1111_000000000000),
              .expected_opcode(`OP_HALT), .expected_dst_reg(8'd0), .expected_src_reg_a(8'd0),
              .expected_reg_b(8'd0), .expected_immediate(16'd0), .expected_address(9'd0));

    // LDI boundary: R0, immediate 0
    test_case(.test_number(17), .tc_instruction_data(16'b0000_000_000000000),
              .expected_opcode(`OP_LDI), .expected_dst_reg(8'd0), .expected_src_reg_a(8'd0),
              .expected_reg_b(8'd0), .expected_immediate(16'd0), .expected_address(9'd0));

    // LDI boundary: R7, max 9-bit immediate
    test_case(.test_number(18), .tc_instruction_data(16'b0000_111_111111111),
              .expected_opcode(`OP_LDI), .expected_dst_reg(8'd7), .expected_src_reg_a(8'd0),
              .expected_reg_b(8'd0), .expected_immediate(16'h01FF), .expected_address(9'd0));

    // LOAD boundary: R0, address 0
    test_case(.test_number(19), .tc_instruction_data(16'b1010_000_000000000),
              .expected_opcode(`OP_LOAD), .expected_dst_reg(8'd0), .expected_src_reg_a(8'd0),
              .expected_reg_b(8'd0), .expected_immediate(16'd0), .expected_address(9'd0));

    // STORE boundary: R7, max address
    test_case(.test_number(20), .tc_instruction_data(16'b1011_111_111111111),
              .expected_opcode(`OP_STORE), .expected_dst_reg(8'd7), .expected_src_reg_a(8'd0),
              .expected_reg_b(8'd0), .expected_immediate(16'd0), .expected_address(9'h1FF));

    // ADD: all registers different, high values
    test_case(.test_number(21), .tc_instruction_data(16'b0010_111_110_101_000),
              .expected_opcode(`OP_ADD), .expected_dst_reg(8'd7), .expected_src_reg_a(8'd6),
              .expected_reg_b(8'd5), .expected_immediate(16'd0), .expected_address(9'd0));

    // ADD: unused bits are all 1s
    // Decoder should ignore bits [2:0]
    test_case(.test_number(22), .tc_instruction_data(16'b0010_001_010_011_111),
              .expected_opcode(`OP_ADD), .expected_dst_reg(8'd1), .expected_src_reg_a(8'd2),
              .expected_reg_b(8'd3), .expected_immediate(16'd0), .expected_address(9'd0));

    // CMP: unused bits all 1s
    test_case(.test_number(23), .tc_instruction_data(16'b1100_101_010_111111),
              .expected_opcode(`OP_CMP), .expected_dst_reg(8'd0), .expected_src_reg_a(8'd5),
              .expected_reg_b(8'd2), .expected_immediate(16'd0), .expected_address(9'd0));

    // MOV: unused bits all 1s
    test_case(.test_number(24), .tc_instruction_data(16'b0001_111_000_111111),
              .expected_opcode(`OP_MOV), .expected_dst_reg(8'd7), .expected_src_reg_a(8'd0),
              .expected_reg_b(8'd0), .expected_immediate(16'd0), .expected_address(9'd0));

    // JMP address 0
    test_case(.test_number(25), .tc_instruction_data(16'b1101_000_000000000),
              .expected_opcode(`OP_JMP), .expected_dst_reg(8'd0), .expected_src_reg_a(8'd0),
              .expected_reg_b(8'd0), .expected_immediate(16'd0), .expected_address(9'd0));

    // JMP max address
    test_case(.test_number(26), .tc_instruction_data(16'b1101_000_111111111),
              .expected_opcode(`OP_JMP), .expected_dst_reg(8'd0), .expected_src_reg_a(8'd0),
              .expected_reg_b(8'd0), .expected_immediate(16'd0), .expected_address(9'h1FF));

    // JZ address 0
    test_case(.test_number(27), .tc_instruction_data(16'b1110_000_000000000),
              .expected_opcode(`OP_JZ), .expected_dst_reg(8'd0), .expected_src_reg_a(8'd0),
              .expected_reg_b(8'd0), .expected_immediate(16'd0), .expected_address(9'd0));

    // HALT with garbage payload bits
    // Payload should be ignored
    test_case(.test_number(28), .tc_instruction_data(16'b1111_111111111111),
              .expected_opcode(`OP_HALT), .expected_dst_reg(8'd0), .expected_src_reg_a(8'd0),
              .expected_reg_b(8'd0), .expected_immediate(16'd0), .expected_address(9'd0));

    $finish;
  end

endmodule
