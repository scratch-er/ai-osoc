module MemIf (
  input         valid,
  output        ready
);

  assign ready = valid;

endmodule
