module password_mem (
    input  logic       clk,
    input  logic       reset,
    input  logic [8:0] window,
    input  logic       wr1,
    input  logic       wr2,
    input  logic       del1,
    input  logic       del2,
    input  logic       clear_all,
    output logic [8:0] pass1,
    output logic [8:0] pass2,
    output logic       valid1,
    output logic       valid2
);

import config_pkg::*;

// Borrado global: reset o clear_all (pulso de la FSM)

logic clear_any;
assign clear_any = reset | clear_all;


// Espacio 1
// Prioridad: borrado (global o del1) > escritura > mantener

logic kill1, load1, hold1;
assign kill1 = clear_any | del1;
assign load1 = wr1 & ~kill1;
assign hold1 = ~wr1 & ~kill1;

logic [8:0] pass1_next;
logic       valid1_next;
assign pass1_next  = ({9{load1}} & window) | ({9{hold1}} & pass1);
assign valid1_next = load1 | (hold1 & valid1);


// Espacio 2

logic kill2, load2, hold2;
assign kill2 = clear_any | del2;
assign load2 = wr2 & ~kill2;
assign hold2 = ~wr2 & ~kill2;

logic [8:0] pass2_next;
logic       valid2_next;
assign pass2_next  = ({9{load2}} & window) | ({9{hold2}} & pass2);
assign valid2_next = load2 | (hold2 & valid2);


// Registros
always_ff @(posedge clk) begin
    pass1  <= pass1_next;
    valid1 <= valid1_next;
    pass2  <= pass2_next;
    valid2 <= valid2_next;
end

endmodule
