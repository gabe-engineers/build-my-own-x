module control_unit (
  input clk,
  input reset,
  input [15:0] mem_read_data,
  output [8:0] mem_read_addr,
  output datapath_write_enable,
  output datapath_writeback_select,
  output [3:0] alu_op,
  output [15:0] datapath_immediate,
  output [2:0] datapath_src_reg_a,
  output [2:0] datapath_src_reg_b(decode_out_src_reg_b),
  output [2:0] datapath_dst_reg(decode_out_dst_reg)
);

  wire [8:0] pc;
  reg        advance_pc;
  reg        write_enable_pc;

  wire [2:0] state;

  wire [ 4:0] decode_out_opcode;
  wire [ 2:0] decode_out_dst_reg;
  wire [ 2:0] decode_out_src_reg_a;
  wire [ 2:0] decode_out_src_reg_b;
  wire [15:0] decode_out_immediate;
  wire [ 8:0] decoder_out_address;
  wire        decoder_out_is_register_write_op;

  wire [8:0] ir;

  wire datapath_write_enable;  
  wire [15:0] datapath_out;

  program_counter pc_module (
    .clk         (clk),
    .reset       (reset),
    .advance     (advance_pc),
    .write_enable(write_enable_pc),
    .write_data  (decoder_out_address),
    .data_out    (pc)
  );

  register ir_module (
    .clk         (clk),
    .reset       (reset),
    .write_enable(state == `FSM_EXECUTE),
    .data_in     (mem_read_data),
    .data_out    (ir)
  );

  decoder decoder_module (
    .instruction_data(ir),
    .opcode          (decode_out_opcode),
    .dst_reg         (decode_out_dst_reg),
    .src_reg_a       (decode_out_src_reg_a),
    .src_reg_b       (decode_out_src_reg_b),
    .immediate       (decode_out_immediate),
    .address         (decoder_out_address)
  );

  control_fsm fsm (
    .clk   (clk),
    .reset (reset),
    .opcode(decode_out_opcode),
    .state(state)
  );

  function is_register_write_op(input opcode);
    begin
      case (opcode)
        `OP_ADD, `OP_SUB, `OP_SHL, `OP_SHR, `OP_MUL, `OP_AND, `OP_OR, `OP_XOR, `OP_MOV, `OP_STORE,
            `OP_LDI:
        is_register_write_op = 1'b1;
        `OP_LOAD, `OP_CMP, `OP_JMP, `OP_JZ, `OP_HALT: is_register_write_op = 1'b0;
      endcase
    end
  endfunction

assign datapath_immediate = decode_out_opcode == `OP_LOAD && state == MEMORY ? mem_read_data
               decode_out_immediate;

assign datapath_write_enable = is_register_write_op(decode_out_opcode);

assign mem_read_addr = state == `FSM_FETCH ? pc : 0; // zero placeholder

endmodule
