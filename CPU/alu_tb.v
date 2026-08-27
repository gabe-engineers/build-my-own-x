`include "alu.v"

module alu_16bit_tb;
  reg  [ 2:0] op;
  reg  [15:0] a;
  reg  [15:0] b;
  wire [15:0] out;
  alu_16bit dut (
      op,
      a,
      b,
      out
  );

  task test_case(input [3:0] op, input [15:0] a, input [15:0] b, input [15:0] expected_out);
    if (out != expected_out) begin
      $display("FAIL - test inputs: op=%d, a=%d, b=%d, out=%d, expected_out=%d", op, a, b, out,
               expected_out);
    end
  endtask


  initial begin
    // ADD
    test_case(3'b000, 16'd5, 16'd7, 16'd12);
    test_case(3'b000, 16'd65535, 16'd1, 16'd0);

    // SUB
    test_case(3'b001, 16'd10, 16'd3, 16'd7);
    test_case(3'b001, 16'd3, 16'd10, 16'd65529);
    test_case(3'b001, 16'd100, 16'd100, 16'd0);

    // Basic boundaries
    test_case(3'b001, 16'd0, 16'd0, 16'd0);
    test_case(3'b001, 16'd65535, 16'd0, 16'd65535);
    test_case(3'b001, 16'd0, 16'd65535, 16'd1);

    // Underflow / wraparound
    test_case(3'b001, 16'd0, 16'd1, 16'd65535);
    test_case(3'b001, 16'd1, 16'd2, 16'd65535);
    test_case(3'b001, 16'd10, 16'd20, 16'd65526);
    test_case(3'b001, 16'd100, 16'd200, 16'd65436);

    // Near the 16-bit boundary
    test_case(3'b001, 16'd65535, 16'd1, 16'd65534);
    test_case(3'b001, 16'd65535, 16'd65534, 16'd1);
    test_case(3'b001, 16'd65534, 16'd65535, 16'd65535);

    // Interesting bit patterns
    test_case(3'b001, 16'hAAAA, 16'h5555, 16'h5555);
    test_case(3'b001, 16'h5555, 16'hAAAA, 16'hAAAB);
    test_case(3'b001, 16'h8000, 16'h0001, 16'h7FFF);
    test_case(3'b001, 16'h7FFF, 16'hFFFF, 16'h8000);

    // Same-value cancellation
    test_case(3'b001, 16'hFFFF, 16'hFFFF, 16'h0000);
    test_case(3'b001, 16'h8000, 16'h8000, 16'h0000);
    test_case(3'b001, 16'h0001, 16'h0001, 16'h0000);

    // AND
    test_case(3'b010, 16'b1010101010101010, 16'b1100110011001100, 16'b1000100010001000);
    test_case(3'b010, 16'hFFFF, 16'h0F0F, 16'h0F0F);

    // OR
    test_case(3'b011, 16'b1010101010101010, 16'b1100110011001100, 16'b1110111011101110);
    test_case(3'b011, 16'h0000, 16'h5555, 16'h5555);

    // XOR
    test_case(3'b100, 16'b1010101010101010, 16'b1100110011001100, 16'b0110011001100110);
    test_case(3'b100, 16'hFFFF, 16'hFFFF, 16'h0000);

    // SHL
    test_case(3'b101, 16'b0000000000000001, 16'd0, 16'b0000000000000010);
    test_case(3'b101, 16'b1000000000000001, 16'd0, 16'b0000000000000010);

    // SHR
    test_case(3'b110, 16'b1000000000000000, 16'd0, 16'b0100000000000000);
    test_case(3'b110, 16'b0000000000000011, 16'd0, 16'b0000000000000001);

    // ZERO
    test_case(3'b111, 16'hFFFF, 16'hFFFF, 16'h0000);
    test_case(3'b111, 16'h1234, 16'h5678, 16'h0000);

    $finish;

  end

endmodule
