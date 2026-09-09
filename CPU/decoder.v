`include "isa.vh"

module decoder (
  input      [15:0] instruction_data,
  output     [ 3:0] opcode,
  output reg [ 2:0] dst_reg,
  output reg [ 2:0] src_reg_a,
  output reg [ 2:0] src_reg_b,
  output reg [15:0] immediate,
  output reg [ 8:0] address
);
  assign opcode               = instruction_data[15:12];

  always @(*) begin
    dst_reg   = 3'b000;
    src_reg_a = 3'b000;
    src_reg_b = 3'b000;
    immediate = 16'b0;
    address   = 9'b0;


    case (opcode)
      `OP_ADD, `OP_SUB, `OP_SHR, `OP_SHL, `OP_MUL, `OP_AND, `OP_OR, `OP_XOR: begin
        dst_reg   = instruction_data[11:9];
        src_reg_a = instruction_data[8:6];
        src_reg_b = instruction_data[5:3];
      end

      `OP_LOAD, `OP_STORE: begin
        dst_reg = instruction_data[11:9];
        address = instruction_data[8:0];
      end

      `OP_CMP: begin
        src_reg_a = instruction_data[11:9];
        src_reg_b = instruction_data[8:6];
      end

      `OP_MOV: begin
        dst_reg   = instruction_data[11:9];
        src_reg_a = instruction_data[8:6];
      end

      `OP_LDI: begin
        dst_reg   = instruction_data[11:9];
        immediate = instruction_data[8:0];
      end

      `OP_JMP, `OP_JZ: begin
        address = instruction_data[11:0];
      end
    endcase
  end

endmodule
