`include "decoder.v"
`include "program-counter.v"
`include "datapath.v"
`include "fsm_states.vh"

module control_fsm (
  input             clk,
  input             reset,
  input      [15:0] mem_data,
  output reg [ 8:0] mem_addr
);

  function should_enable_datapath_write(input [2:0] state, input opcode);
    reg is_register_write_op;
    begin
      case (opcode)
        `OP_ADD, `OP_SUB, `OP_SHL, `OP_SHR, `OP_MUL, `OP_AND, `OP_OR, `OP_XOR, `OP_MOV:
        is_register_write_op = 1'b1;
        `OP_LDI, `OP_LOAD, `OP_STORE, `OP_CMP, `OP_JMP, `OP_JZ, `OP_HALT:
        is_register_write_op = 1'b0;
      endcase
      should_enable_datapath_write = state == `FSM_EXECUTE && is_register_write_op;
    end
  endfunction


  reg [2:0] state = `FSM_FETCH;

  wire [ 4:0] decode_out_opcode;
  wire [ 2:0] decode_out_dst_reg;
  wire [ 2:0] decode_out_src_reg_a;
  wire [ 2:0] decode_out_src_reg_b;
  wire [15:0] decode_out_immediate;
  wire [ 8:0] decoder_out_address;

  wire [8:0] pc;
  reg        advance_pc;
  reg        write_enable_pc;

  program_counter pc_module (
    .clk         (clk),
    .reset       (reset),
    .advance     (advance_pc),
    .write_enable(write_enable_pc),
    .write_data  (decoder_out_address),
    .data_out    (pc)
  );

  decoder decoder_module (
    .instruction_data(mem_data),
    .opcode          (decode_out_opcode),
    .dst_reg         (decode_out_dst_reg),
    .src_reg_a       (decode_out_src_reg_a),
    .src_reg_b       (decode_out_src_reg_b),
    .immediate       (decode_out_immediate),
    .address         (decoder_out_address)
  );

  datapath_16bit datapath_module (
    .clk(clk),
    .reset(reset),
    .write_enable(should_enable_datapath_write(state, decode_out_opcode)),
    .writeback_select(),  // ALU = 0, IMMEDIATE = 1
    .alu_op(),
    .immediate(),
    .read_addr_a(),
    .read_addr_b(),
    .write_addr(),
    .out()  // ALU output if writeback_select = 1 else IMMEDIATE
  );

  always @(posedge clk) begin
    case (state)
      `FSM_FETCH: begin
        mem_addr        <= pc;
        advance_pc      <= 1'b1;
        write_enable_pc <= 1'b0;
        state           <= `FSM_DECODE;
      end
      `FSM_DECODE: begin


      end
      `FSM_EXECUTE: begin
      end
      `FSM_MEMORY: begin
      end
      `FSM_HALT: begin
      end
    endcase

  end

endmodule
