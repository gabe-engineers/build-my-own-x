module or_gate (
  input  a,
  input  b,
  output out
);
  assign out = a | b;
endmodule

module and_gate (
  input  a,
  input  b,
  output out
);
  assign out = a & b;
endmodule

module xor_gate (
  input  a,
  input  b,
  output out
);
  assign out = a ^ b;
endmodule
