`include "fsm_states.vh"
`include "isa.vh"

module control_fsm (
  input clk,
  input reset,
  input [3:0] opcode,
  output reg [2:0] state
);

  initial state = `FSM_FETCH;

  always @(posedge clk) begin
    case (state)
      `FSM_FETCH:
        state           <= `FSM_EXECUTE;
      `FSM_EXECUTE: begin
        case (opcode)
          `OP_LDI, `OP_MOV,`OP_ADD, `OP_SUB, `OP_AND, `OP_OR, `OP_XOR, `OP_SHL, `OP_SHR, `OP_MUL, `OP_CMP, `OP_JMP, `OP_JZ : state <= `FSM_FETCH;
          `OP_LOAD, `OP_STORE: state <= `FSM_MEMORY;
          `OP_HALT: state <= `FSM_HALT;
        endcase
      end
      `FSM_MEMORY: begin
        state <= `FSM_FETCH;
      end
      `FSM_HALT: begin
        if (reset) begin
          state <= `FSM_FETCH;
        end
      end
    endcase
  end
endmodule
