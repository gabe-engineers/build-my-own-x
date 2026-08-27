`include "register-file.v"
`include "alu.v"

module datapath_16bit (
    input wire clk,
    input wire reset,
    input wire write_enable,
    input wire writeback_select,  // ALU = 0, IMMEDIATE = 1
    input wire [2:0] alu_op,
    input wire [15:0] immediate,
    input wire [2:0] read_addr_a,
    input wire [2:0] read_addr_b,
    input wire [2:0] write_addr,
    output wire [15:0] out  // ALU output if writeback_select = 1 else IMMEDIATE
);
  wire [15:0] alu_out;
  wire [15:0] write_data = writeback_select ? immediate : alu_out;
  wire [15:0] read_data_a;
  wire [15:0] read_data_b;

  assign out = writeback_select ? immediate : alu_out;

  register_file registers (
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

  alu_16bit alu (
      alu_op,
      read_data_a,
      read_data_b,
      alu_out
  );

endmodule
