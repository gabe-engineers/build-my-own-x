module control_fsm(input clk, input [15:0] mem_data);
wire [1:0] state;

program_counter pc (
    .clk(clk),
    .reset(),
    .advance(),
    .write_enable(),
    .write_data(),
    .data_out()
)



endmodule
