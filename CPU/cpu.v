`include "fsm_states.vh"
`include "control_unit.v"
`include "datapath.v"

module cpu (
    input  wire        clk,
    input  wire        reset,
    input  wire [15:0] mem_read_data,
    output wire [ 8:0] mem_address,
    output wire [15:0] mem_write_data,
    output wire        mem_write_enable,
    output wire        halted
);

  wire [2:0] datapath_src_reg_a;
  wire [2:0] datapath_src_reg_b;
  wire [2:0] datapath_dst_reg;
  wire datapath_write_enable;
  wire datapath_writeback_select;
  wire [3:0] alu_op;
  wire [15:0] datapath_immediate;
  wire [15:0] datapath_out;
  wire [15:0] datapath_read_data_a;
  wire [15:0] datapath_read_data_b;

  control_unit control_unit_module (
      .clk                      (clk),
      .reset                    (reset),
      .mem_read_data            (mem_read_data),
      .mem_read_addr            (mem_address),
      .mem_write_enable         (mem_write_enable),
      .mem_write_data           (),
      .datapath_write_enable    (datapath_write_enable),
      .datapath_writeback_select(datapath_writeback_select),
      .alu_op                   (alu_op),
      .datapath_immediate       (datapath_immediate),
      .datapath_src_reg_a       (datapath_src_reg_a),
      .datapath_src_reg_b       (datapath_src_reg_b),
      .datapath_dst_reg         (datapath_dst_reg)
  );

  datapath_16bit datapath (
      .clk(clk),
      .reset(reset),
      .write_enable(datapath_write_enable),
      .writeback_select(datapath_writeback_select),
      .alu_op(alu_op),
      .immediate(datapath_immediate),
      .read_addr_a(datapath_src_reg_a),
      .read_addr_b(datapath_src_reg_b),
      .write_addr(datapath_dst_reg),
      .out(datapath_out),
      .read_data_a(datapath_read_data_a),
      .read_data_b(datapath_read_data_b)
  );

endmodule
