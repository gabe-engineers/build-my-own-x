`include "register.v"

module memory (
  input         clk,
  input  [ 8:0] address,
  input         write_enable,
  input  [15:0] write_data,
  output [15:0] read_data
);

  wire [15:0] register_out[0:511];

  assign read_data = register_out[address];

  genvar i;

  generate

    for (i = 0; i < 512; i = i + 1) begin
      register_16bit register (
        .clk         (clk),
        .reset       (1'b0),
        .write_enable(write_enable && (address == i)),
        .data_in     (write_data),
        .data_out    (register_out[i])
      );
    end

  endgenerate



endmodule
