module alu_8bit_tb;
  reg  [2:0] op;
  reg  [7:0] a;
  reg  [7:0] b;
  wire [7:0] out;
  alu_8bit dut (
      op,
      a,
      b,
      out
  );

  task test_case(input [3:0] op, input [7:0] a, input [7:0] b, input [7:0] expected_out);
    if (out != expected_out) begin
      $display("FAIL - test inputs: op=%b, a=%b, b=%b, out=%b, expected_out=%b", op, a, b, out,
               expected_out);
    end
  endtask


  initial begin
    // ADD
    test_case(3'b000, 8'd5, 8'd7, 8'd12);
    test_case(3'b000, 8'd255, 8'd1, 8'd0);

    // SUB
    test_case(3'b001, 8'd10, 8'd3, 8'd7);
    test_case(3'b001, 8'd3, 8'd10, 8'd249);
    test_case(3'b001, 8'd100, 8'd100, 8'd0);

    // Basic boundaries
    test_case(3'b001, 8'd0, 8'd0, 8'd0);
    test_case(3'b001, 8'd255, 8'd0, 8'd255);
    test_case(3'b001, 8'd0, 8'd255, 8'd1);

    // Underflow / wraparound
    test_case(3'b001, 8'd0, 8'd1, 8'd255);
    test_case(3'b001, 8'd1, 8'd2, 8'd255);
    test_case(3'b001, 8'd10, 8'd20, 8'd246);
    test_case(3'b001, 8'd100, 8'd200, 8'd156);

    // Near the 8-bit boundary
    test_case(3'b001, 8'd255, 8'd1, 8'd254);
    test_case(3'b001, 8'd255, 8'd254, 8'd1);
    test_case(3'b001, 8'd254, 8'd255, 8'd255);

    // Interesting bit patterns
    test_case(3'b001, 8'hAA, 8'h55, 8'h55);
    test_case(3'b001, 8'h55, 8'hAA, 8'hAB);
    test_case(3'b001, 8'h80, 8'h01, 8'h7F);
    test_case(3'b001, 8'h7F, 8'hFF, 8'h80);

    // Same-value cancellation
    test_case(3'b001, 8'hFF, 8'hFF, 8'h00);
    test_case(3'b001, 8'h80, 8'h80, 8'h00);
    test_case(3'b001, 8'h01, 8'h01, 8'h00);

    // AND
    test_case(3'b010, 8'b10101010, 8'b11001100, 8'b10001000);
    test_case(3'b010, 8'hFF, 8'h0F, 8'h0F);

    // OR
    test_case(3'b011, 8'b10101010, 8'b11001100, 8'b11101110);
    test_case(3'b011, 8'h00, 8'h55, 8'h55);

    // XOR
    test_case(3'b100, 8'b10101010, 8'b11001100, 8'b01100110);
    test_case(3'b100, 8'hFF, 8'hFF, 8'h00);

    // SHL
    test_case(3'b101, 8'b00000001, 8'd0, 8'b00000010);
    test_case(3'b101, 8'b10000001, 8'd0, 8'b00000010);

    // SHR
    test_case(3'b110, 8'b10000000, 8'd0, 8'b01000000);
    test_case(3'b110, 8'b00000011, 8'd0, 8'b00000001);

    // ZERO
    test_case(3'b111, 8'hFF, 8'hFF, 8'h00);
    test_case(3'b111, 8'h12, 8'h34, 8'h00);

    $display("Tests finished");

    $finish;

  end

endmodule
