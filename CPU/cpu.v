`include "fsm_states.vh"

module cpu (
  input  wire        clk,
  input  wire        reset,
  input  wire [15:0] mem_read_data,
  output wire [ 8:0] mem_address,
  output wire [15:0] mem_write_data,
  output wire        mem_write_enable,
  output wire        halted
);

  wire datapath_src_reg_a;

  control_unit control_unit_module (
    .clk                      (clk),
    .reset                    (reset),
    .pc                       (pc),
    .mem_read_data            (),
    .datapath_write_enable    (),
    .datapath_writeback_select(),
    .alu_op                   (),
    .datapath_immediate       (),
    .datapath_src_reg_a       (decode_out_src_reg_a),
    .datapath_src_reg_b       (decode_out_src_reg_b),
    .datapath_dst_reg         (decode_out_dst_reg)
  );

  datapath_16bit datapath (
    .clk(clk),
    .reset(reset),
    .write_enable(is_register_write_op(ir)),
    .writeback_select(),
    .alu_op(),
    .immediate(decode_out_opcode == `OP_LOAD && state == MEMORY ? mem_read_data :
               decode_out_immediate),
    .read_addr_a(decode_out_src_reg_a),
    .read_addr_b(decode_out_src_reg_b),
    .write_addr(decode_out_dst_reg),
    .out(datapath_out)
    .read_data_a(datapath_src_reg_a)
  );

endmodule
