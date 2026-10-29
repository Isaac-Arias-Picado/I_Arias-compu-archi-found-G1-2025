module comparator (
    input  logic [8:0] window,
    input  logic [8:0] pass1,
    input  logic [8:0] pass2,
    input  logic       valid1,
    input  logic       valid2,
    output logic       match1,
    output logic       match2
);

import config_pkg::*;

// Igualdad bit a bit: XOR da 1 donde difieren; sin diferencias = iguales

logic [8:0] diff1, diff2;
logic       equal1, equal2;

assign diff1  = window ^ pass1;
assign diff2  = window ^ pass2;
assign equal1 = ~(|diff1);
assign equal2 = ~(|diff2);

// Un espacio vacío nunca coincide

assign match1 = equal1 & valid1;
assign match2 = equal2 & valid2;

endmodule
