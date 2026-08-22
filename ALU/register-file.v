module register_file (
    input wire clk,
    input wire reset,

    input wire       write_enable,
    input wire [2:0] write_addr,
    input wire [7:0] write_data,

    input wire [2:0] read_addr_a,
    input wire [2:0] read_addr_b,

    output reg [7:0] read_data_a,
    output reg [7:0] read_data_b
);

  reg [7:0] reg_write_enable;
  reg [7:0] data_in[7:0];
  wire [7:0] data_out[7:0];

  register_8bit reg1 (
      clk,
      reset,
      reg_write_enable[0],
      data_in[0],
      data_out[0]
  );

  register_8bit reg2 (
      clk,
      reset,
      reg_write_enable[1],
      data_in[1],
      data_out[1]
  );

  register_8bit reg3 (
      clk,
      reset,
      reg_write_enable[2],
      data_in[2],
      data_out[2]
  );

  register_8bit reg4 (
      clk,
      reset,
      reg_write_enable[3],
      data_in[3],
      data_out[3]
  );

  register_8bit reg5 (
      clk,
      reset,
      reg_write_enable[4],
      data_in[4],
      data_out[4]
  );

  register_8bit reg6 (
      clk,
      reset,
      reg_write_enable[5],
      data_in[5],
      data_out[5]
  );

  register_8bit reg7 (
      clk,
      reset,
      reg_write_enable[6],
      data_in[6],
      data_out[6]
  );

  register_8bit reg8 (
      clk,
      reset,
      reg_write_enable[7],
      data_in[7],
      data_out[7]
  );

  always @(posedge clk) begin
    reg_write_enable <= 8'b0;
    reg_write_enable[write_addr] <= 1'b1;
    data_in[write_addr] <= write_data;

    read_data_a <= data_out[read_addr_a];
    read_data_b <= data_out[read_addr_b];
  end

endmodule
