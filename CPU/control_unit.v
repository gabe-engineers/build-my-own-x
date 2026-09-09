`include "decoder.v"
`include "program_counter.v"
`include "control_fsm.v"

module control_unit (
    input clk,
    input reset,
    input [15:0] mem_read_data,
    output [8:0] mem_read_addr,
    output mem_write_enable,
    output [15:0] mem_write_data,
    output datapath_write_enable,
    output datapath_writeback_select,
    output [3:0] alu_op,
    output [15:0] datapath_immediate,
    output [2:0] datapath_src_reg_a,
    output [2:0] datapath_src_reg_b,
    output [2:0] datapath_dst_reg
);

  wire [15:0] pc;
  wire        advance_pc;
  wire        write_enable_pc;

  wire [ 2:0] fsm_out_state;

  wire [ 3:0] decoder_out_opcode;
  wire [ 2:0] decoder_out_dst_reg;
  wire [ 2:0] decoder_out_src_reg_a;
  wire [ 2:0] decoder_out_src_reg_b;
  wire [15:0] decoder_out_immediate;
  wire [ 8:0] decoder_out_address;
  wire        decoder_out_is_register_write_op;

  wire [15:0] ir;

  wire [15:0] datapath_out;

  register ir_module (
      .clk         (clk),
      .reset       (reset),
      .write_enable(fsm_out_state == `FSM_EXECUTE),
      .data_in     (mem_read_data),
      .data_out    (ir)
  );

  decoder decoder_module (
      .instruction_data(ir),
      .opcode          (decoder_out_opcode),
      .dst_reg         (decoder_out_dst_reg),
      .src_reg_a       (decoder_out_src_reg_a),
      .src_reg_b       (decoder_out_src_reg_b),
      .immediate       (decoder_out_immediate),
      .address         (decoder_out_address)
  );

  program_counter pc_module (
      .clk         (clk),
      .reset       (reset),
      .advance     (advance_pc),
      .write_enable(write_enable_pc),
      .write_data  ({7'b0, decoder_out_address}),
      .data_out    (pc)
  );

  control_fsm fsm (
      .clk   (clk),
      .reset (reset),
      .opcode(decoder_out_opcode),
      .state(fsm_out_state)
  );

  function is_register_write_op(input [3:0] opcode);
    begin
      case (opcode)
        `OP_ADD, `OP_SUB, `OP_SHL, `OP_SHR, `OP_MUL, `OP_AND, `OP_OR, `OP_XOR, `OP_MOV, `OP_STORE,
            `OP_LDI:
        is_register_write_op = 1'b1;
        `OP_LOAD, `OP_CMP, `OP_JMP, `OP_JZ, `OP_HALT: is_register_write_op = 1'b0;
      endcase
    end
  endfunction

  assign datapath_immediate = decoder_out_opcode == `OP_LOAD && fsm_out_state == `FSM_MEMORY ? mem_read_data : decoder_out_immediate;

  assign datapath_write_enable = is_register_write_op(decoder_out_opcode);

  assign mem_read_addr = fsm_out_state == `FSM_FETCH ? pc[8:0] : decoder_out_address;

  assign advance_pc = fsm_out_state == `FSM_EXECUTE;

  assign write_enable_pc = fsm_out_state == `FSM_EXECUTE && (decoder_out_opcode == `OP_JZ || decoder_out_opcode == `OP_JMP);

  assign mem_write_enable = fsm_out_state == `FSM_EXECUTE && decoder_out_opcode == `OP_STORE;

endmodule
