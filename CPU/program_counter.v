`include "register.v"
`include "adder.v"

module program_counter (
    input             clk,
    input             reset,
    input             advance,
    input             write_enable,
    input      [15:0] write_data,
    output reg [15:0] data_out
);

  wire [15:0] incrementer_out;
  wire [15:0] register_out;
  wire reg_write_enable = write_enable | advance;
  wire [15:0] reg_data_in = write_enable ? write_data : incrementer_out;

  register register (
      .clk         (clk),
      .reset       (reset),
      .write_enable(reg_write_enable),
      .data_in     (reg_data_in),
      .data_out    (register_out)
  );

  adder_16bit incrementer (
      register_out,
      16'b1,
      incrementer_out
  );

endmodule
