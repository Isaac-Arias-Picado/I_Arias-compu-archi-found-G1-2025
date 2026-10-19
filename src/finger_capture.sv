module finger_capture (
    input  logic       clk,
    input  logic       reset,
    input  logic       tick_capture,
    input  logic       finger_valid,
    input  logic [2:0] finger_symbol,
    input  logic       clear_capture,
    output logic [8:0] window
);

import config_pkg::*;

// Control de desplazamiento

logic clear_all;
logic shift_en;

assign clear_all = reset | clear_capture;
assign shift_en  = tick_capture & finger_valid & ~clear_all;


// Valor desplazado: sale el más viejo, entra el nuevo
// window[8:6] = viejo, window[5:3] = medio, window[2:0] = nuevo

logic [8:0] shifted;
assign shifted = {window[5:0], finger_symbol};

// Máscaras estructurales

logic [8:0] mask_shift, mask_hold;
assign mask_shift = {9{shift_en}};
assign mask_hold  = {9{~shift_en & ~clear_all}};

logic [8:0] window_next;
assign window_next = (mask_shift & shifted) | (mask_hold & window);

// Registro
always_ff @(posedge clk) begin
    window <= window_next;
end

endmodule