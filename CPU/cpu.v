module cpu (
  input  wire        clk,
  input  wire        reset,
  input  wire [15:0] mem_read_data,
  output wire [ 8:0] mem_address,
  output wire [15:0] mem_write_data,
  output wire        mem_write_enable,
  output wire        halted
);

  control_fsm fsm (
    .mem_data(mem_read_data),
    .reset   (reset),
    .mem
  );

endmodule
