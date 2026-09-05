`include "decoder.v"
`include "program_counter.v"
`include "datapath.v"
  
module control_fsm(input clk, input reset, input [15:0] mem_data);

reg [2:0] state = FSM_FETCH;

wire [4:0] opcode;
wire [2:0] dst_reg;
wire [2:0] src_reg_a;
wire [2:0] src_reg_b;
wire [15:0] immediate;
wire [8:0] address;

wire [8:0] pc;

reg advance_pc;
reg write_enable_pc;

program_counter pc_module (
    .clk(clk),
    .reset(reset),
    .advance(advance_pc),
    .write_enable(write_enable_pc),
    .write_data(),
    .data_out(pc)
)

decoder decoder_module (
    .instruction_data(mem_data),
    .opcode(),
    .dst_reg(dst_reg),
    .src_reg_a(src_reg_a),
    .src_reg_b(src_reg_b),
    .immediate(immediate),
    .address(address)
);

datapath_16bit datapath_module (
    .clk(),
    .reset(reset),
    .write_enable(),
    .writeback_select(),  // ALU = 0, IMMEDIATE = 1
    input wire [2:0] alu_op,
    input wire [15:0] immediate,
    input wire [2:0] read_addr_a,
    input wire [2:0] read_addr_b,
    input wire [2:0] write_addr,
    output wire [15:0] out  // ALU output if writeback_select = 1 else IMMEDIATE
);

always @(posedge clk) begin

  
end

endmodule
