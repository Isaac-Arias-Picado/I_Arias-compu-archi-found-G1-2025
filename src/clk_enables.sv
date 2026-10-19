module clk_enables (
    input  logic clk,
    input  logic reset,
    output logic tick_capture,
    output logic tick_debounce,
    output logic tick_display
);

import config_pkg::*;

// Anchuras de contador 

localparam int CAP_BITS    = $clog2(CAPTURE_CYCLES);
localparam int SHARED_BITS = $clog2(DEBOUNCE_CYCLES);   // debounce y display comparten período

// Contadores
logic [CAP_BITS-1:0]    cap_cnt;
logic [SHARED_BITS-1:0] shared_cnt;

// Comparadores
logic cap_is_max, shared_is_max;

assign cap_is_max    = (cap_cnt    == CAP_BITS'(CAPTURE_CYCLES  - 1));
assign shared_is_max = (shared_cnt == SHARED_BITS'(DEBOUNCE_CYCLES - 1));

// Ticks 
assign tick_capture  = cap_is_max    & ~reset;
assign tick_debounce = shared_is_max & ~reset;
assign tick_display  = shared_is_max & ~reset;

// Enables de conteo
logic cap_en, shared_en;

assign cap_en    = ~reset & ~cap_is_max;
assign shared_en = ~reset & ~shared_is_max;

// Siguientes valores 
logic [CAP_BITS-1:0]    cap_next;
logic [SHARED_BITS-1:0] shared_next;

assign cap_next    = {CAP_BITS{cap_en}}       & (cap_cnt    + 1'b1);
assign shared_next = {SHARED_BITS{shared_en}} & (shared_cnt + 1'b1);

// Registros
always_ff @(posedge clk) begin
    cap_cnt    <= cap_next;
    shared_cnt <= shared_next;
end

endmodule