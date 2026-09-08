`include "control_fsm.v"

module control_fsm_tb;
  reg        clk;
  reg        reset;
  reg  [3:0] opcode;
  wire [2:0] state;

  control_fsm dut (
    clk,
    reset,
    opcode,
    state
  );

  task test_case(input [7:0] test_number, input tc_reset, input [3:0] tc_opcode,
                 input [2:0] expected_state);
    begin
      reset  = tc_reset;
      opcode = tc_opcode;
      clk    = 0;
      #10;
      clk = 1;
      #10;

      if (state != expected_state) begin
        $display("Test case #%d failed - reset: %d, opcode: %d | state: %d, expected state: %d",
                 test_number, reset, opcode, state, expected_state);
      end
    end
  endtask

  initial begin
    test_case(1, 0, `OP_LDI, `FSM_EXECUTE);
    test_case(2, 0, `OP_LDI, `FSM_FETCH);
    test_case(3, 0, `OP_MOV, `FSM_EXECUTE);
    test_case(4, 0, `OP_MOV, `FSM_FETCH);
    test_case(5, 0, `OP_ADD, `FSM_EXECUTE);
    test_case(6, 0, `OP_ADD, `FSM_FETCH);
    test_case(7, 0, `OP_SUB, `FSM_EXECUTE);
    test_case(8, 0, `OP_SUB, `FSM_FETCH);
    test_case(9, 0, `OP_AND, `FSM_EXECUTE);
    test_case(10, 0, `OP_AND, `FSM_FETCH);
    test_case(11, 0, `OP_OR, `FSM_EXECUTE);
    test_case(12, 0, `OP_OR, `FSM_FETCH);
    test_case(13, 0, `OP_XOR, `FSM_EXECUTE);
    test_case(14, 0, `OP_XOR, `FSM_FETCH);
    test_case(15, 0, `OP_SHL, `FSM_EXECUTE);
    test_case(16, 0, `OP_SHL, `FSM_FETCH);
    test_case(17, 0, `OP_SHR, `FSM_EXECUTE);
    test_case(18, 0, `OP_SHR, `FSM_FETCH);
    test_case(19, 0, `OP_MUL, `FSM_EXECUTE);
    test_case(20, 0, `OP_MUL, `FSM_FETCH);
    test_case(21, 0, `OP_CMP, `FSM_EXECUTE);
    test_case(22, 0, `OP_CMP, `FSM_FETCH);
    test_case(23, 0, `OP_JMP, `FSM_EXECUTE);
    test_case(24, 0, `OP_JMP, `FSM_FETCH);
    test_case(25, 0, `OP_JZ, `FSM_EXECUTE);
    test_case(26, 0, `OP_JZ, `FSM_FETCH);

    test_case(27, 0, `OP_LOAD, `FSM_EXECUTE);
    test_case(28, 0, `OP_LOAD, `FSM_MEMORY);
    test_case(29, 0, `OP_LOAD, `FSM_FETCH);
    test_case(30, 0, `OP_STORE, `FSM_EXECUTE);
    test_case(31, 0, `OP_STORE, `FSM_MEMORY);
    test_case(32, 0, `OP_STORE, `FSM_FETCH);

    test_case(33, 0, `OP_HALT, `FSM_EXECUTE);
    test_case(34, 0, `OP_HALT, `FSM_HALT);
    test_case(35, 0, `OP_ADD, `FSM_HALT);
    test_case(36, 1, `OP_ADD, `FSM_FETCH);

    $finish;
  end

endmodule
