`include "register_file.v"
`include "alu.v"

module datapath_16bit (
    input         clk,
    input         reset,
    input         write_enable,
    input         writeback_select,  // ALU = 0, IMMEDIATE = 1
    input  [ 3:0] alu_op,
    input  [15:0] immediate,
    input  [ 2:0] read_addr_a,
    input  [ 2:0] read_addr_b,
    input  [ 2:0] write_addr,
    output [15:0] write_reg_data
);
  wire [15:0] alu_out;
  wire [15:0] write_data;
  wire [15:0] read_data_a;
  wire [15:0] read_data_b;

  assign write_data = writeback_select ? immediate : alu_out;

  register_file registers (
      .clk           (clk),
      .reset         (reset),
      .write_enable  (write_enable),
      .write_addr    (write_addr),
      .write_data    (write_data),
      .read_addr_a   (read_addr_a),
      .read_addr_b   (read_addr_b),
      .read_data_a   (read_data_a),
      .read_data_b   (read_data_b),
      .write_reg_data(write_reg_data)
  );

  alu_16bit alu (
      alu_op,
      read_data_a,
      read_data_b,
      alu_out
  );

endmodule
