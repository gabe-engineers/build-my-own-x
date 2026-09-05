module cpu (
    input wire clk,
    input wire reset,

    output wire [ 8:0] mem_address,
    output wire [15:0] mem_write_data,
    output wire        mem_write_enable,
    input  wire [15:0] mem_read_data,

    output wire halted
);

  control_fsm fsm ();

endmodule
