`include "register.v"

module register_file (
  input wire clk,
  input wire reset,

  input wire        write_enable,
  input wire [ 2:0] write_addr,
  input wire [15:0] write_data,

  input wire [2:0] read_addr_a,
  input wire [2:0] read_addr_b,

  output wire [15:0] read_data_a,
  output wire [15:0] read_data_b
);

  wire [ 7:0] reg_write_enable;
  wire [15:0] data_in;
  wire [15:0] data_out         [7:0];

  assign data_in          = write_data;
  assign reg_write_enable = write_enable ? 8'b00000001 << write_addr : 8'b0;
  assign read_data_a      = data_out[read_addr_a];
  assign read_data_b      = data_out[read_addr_b];

  register reg1 (
    .clk         (clk),
    .reset       (reset),
    .write_enable(reg_write_enable[0]),
    .data_in     (data_in),
    .data_out    (data_out[0])
  );

  register reg2 (
    .clk         (clk),
    .reset       (reset),
    .write_enable(reg_write_enable[1]),
    .data_in     (data_in),
    .data_out    (data_out[1])
  );

  register reg3 (
    .clk         (clk),
    .reset       (reset),
    .write_enable(reg_write_enable[2]),
    .data_in     (data_in),
    .data_out    (data_out[2])
  );

  register reg4 (
    .clk         (clk),
    .reset       (reset),
    .write_enable(reg_write_enable[3]),
    .data_in     (data_in),
    .data_out    (data_out[3])
  );

  register reg5 (
    .clk         (clk),
    .reset       (reset),
    .write_enable(reg_write_enable[4]),
    .data_in     (data_in),
    .data_out    (data_out[4])
  );

  register reg6 (
    .clk         (clk),
    .reset       (reset),
    .write_enable(reg_write_enable[5]),
    .data_in     (data_in),
    .data_out    (data_out[5])
  );

  register reg7 (
    .clk         (clk),
    .reset       (reset),
    .write_enable(reg_write_enable[6]),
    .data_in     (data_in),
    .data_out    (data_out[6])
  );

  register reg8 (
    .clk         (clk),
    .reset       (reset),
    .write_enable(reg_write_enable[7]),
    .data_in     (data_in),
    .data_out    (data_out[7])
  );

endmodule
