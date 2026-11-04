module debounce (
    input  logic       clk,
    input  logic       reset,
    input  logic       tick_debounce,
    input  logic       btn_admin,
    input  logic       btn_test,
    input  logic       btn_reset,
    input  logic [4:0] finger_raw,
    output logic       admin_pressed,
    output logic       test_pressed,
    output logic       reset_pressed,
    output logic       finger_valid,
    output logic [2:0] finger_symbol
);

import config_pkg::*;

localparam int STAB_BITS = $clog2(DEBOUNCE_SAMPLES + 1);


// Botones: 2 FF sync + edge detector
// (no reseteados por reset para no cancelar reset_pressed)
logic admin_ff1, admin_ff2, admin_prev;
logic test_ff1,  test_ff2,  test_prev;
logic reset_ff1, reset_ff2, reset_prev;

always_ff @(posedge clk) begin
    admin_ff1  <= btn_admin;
    admin_ff2  <= admin_ff1;
    admin_prev <= admin_ff2;
    test_ff1   <= btn_test;
    test_ff2   <= test_ff1;
    test_prev  <= test_ff2;
    reset_ff1  <= btn_reset;
    reset_ff2  <= reset_ff1;
    reset_prev <= reset_ff2;
end

assign admin_pressed = admin_ff2 & ~admin_prev & ~reset;
assign test_pressed  = test_ff2  & ~test_prev  & ~reset;
assign reset_pressed = reset_ff2 & ~reset_prev;

// Dedos: 2 FF sync
logic [4:0] finger_ff1, finger_ff2;

always_ff @(posedge clk) begin
    finger_ff1 <= finger_raw;
    finger_ff2 <= finger_ff1;
end

logic [4:0] raw_sync;
assign raw_sync = finger_ff2;

// Dedos: filtro de estabilidad (DEBOUNCE_SAMPLES ticks)
logic [4:0]          candidate, stable;
logic [STAB_BITS-1:0] count;

logic cand_change, cand_match;
assign cand_change = tick_debounce & (raw_sync != candidate);
assign cand_match  = tick_debounce & (raw_sync == candidate);

localparam logic [STAB_BITS-1:0] COUNT_ONE = {{(STAB_BITS-1){1'b0}}, 1'b1};

// Contador: 1 si cambia el candidato, +1 si se repite, se mantiene si no.
// cand_change y cand_match nunca valen 1 a la vez. Reset deja todo en 0.
logic c_inc, c_hold;
assign c_inc  = cand_match & (count < DEBOUNCE_SAMPLES);
assign c_hold = ~cand_change & ~c_inc;

logic [STAB_BITS-1:0] count_next;
assign count_next = {STAB_BITS{~reset}} & (({STAB_BITS{cand_change}} & COUNT_ONE)
    | ({STAB_BITS{c_inc}} & (count + 1'b1)) | ({STAB_BITS{c_hold}} & count));

// Candidato: toma la entrada nueva cuando cambia
logic [4:0] candidate_next;
assign candidate_next = {5{~reset}} & (({5{cand_change}} & raw_sync)
    | ({5{~cand_change}} & candidate));

// Estable: se carga cuando el candidato se repitio DEBOUNCE_SAMPLES veces
logic stable_load;
assign stable_load = cand_match & (count == (DEBOUNCE_SAMPLES - 1));

logic [4:0] stable_next;
assign stable_next = {5{~reset}} & (({5{stable_load}} & candidate)
    | ({5{~stable_load}} & stable));

always_ff @(posedge clk) begin
    count     <= count_next;
    candidate <= candidate_next;
    stable    <= stable_next;
end

// Validacion: popcount(stable) <= 1
logic [2:0] popcount;
assign popcount = {2'b00, stable[0]} + {2'b00, stable[1]}
                + {2'b00, stable[2]} + {2'b00, stable[3]}
                + {2'b00, stable[4]};

assign finger_valid = (popcount <= 3'd1);


// Encoder estructural: one-hot (o cero) a simbolo 0-5
assign finger_symbol[0] = stable[0] | stable[2] | stable[4];
assign finger_symbol[1] = stable[1] | stable[2];
assign finger_symbol[2] = stable[3] | stable[4];

endmodule