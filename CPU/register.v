module register_16bit (
    input  wire        clk,
    input  wire        reset,
    input  wire        write_enable,
    input  wire [15:0] data_in,
    output reg  [15:0] data_out
);

  always @(posedge clk) begin
    if (reset) data_out <= 16'b0;
    else if (write_enable) data_out <= data_in;
  end

endmodule
