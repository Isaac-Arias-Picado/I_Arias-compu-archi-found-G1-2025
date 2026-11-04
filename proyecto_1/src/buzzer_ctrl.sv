// Buzzer pasivo, salida activa alta. Codigos compatibles con config_pkg.
// En top enlazar estos parametros a las constantes homonimas del paquete.
module buzzer_ctrl #(
    parameter int BUZZER_TEST_HALF = 25_000,
    parameter int BUZZER_REG_OK_HALF = 25_000,
    parameter int BUZZER_VALID_HALF = 25_000,
    parameter int BUZZER_INVALID_HALF = 50_000,
    parameter int BUZZER_OPENING_HALF = 12_500,
    parameter int BUZZER_CLOSING_HALF = 16_666,
    parameter int BUZZER_BEEP_CYCLES = 5_000_000,
    parameter int BUZZER_INVALID_CYCLES = 25_000_000,
    parameter int BUZZER_GAP_CYCLES = 5_000_000
) (
    input  logic       clk,
    input  logic       reset,
    input  logic [2:0] event_code,
    input  logic       event_start,
    output logic       buzzer_out
);

localparam int PAT_BITS = $clog2(BUZZER_INVALID_CYCLES +
    2*BUZZER_BEEP_CYCLES + BUZZER_GAP_CYCLES + 1);
localparam int TONE_BITS = $clog2(2*(BUZZER_TEST_HALF + BUZZER_REG_OK_HALF +
    BUZZER_VALID_HALF + BUZZER_INVALID_HALF + BUZZER_OPENING_HALF +
    BUZZER_CLOSING_HALF) + 1);

logic is_test, is_opening, is_closing, continuous;
logic finite_valid, finite_start, cancel_pattern;
logic pattern_active, pattern_next, pattern_done;
logic [2:0] pattern_code, code_next;
logic [PAT_BITS-1:0] elapsed, elapsed_next, duration;
logic advance_pattern, hold_code;
logic reg_pattern, valid_pattern, invalid_pattern, finite_sound;
logic tone_enable, continuous_changed;
logic [2:0] continuous_code, previous_continuous;
logic [TONE_BITS-1:0] half_period, tone_counter, tone_next;
logic tone_end, advance_tone;

assign is_test = (event_code == 3'd1);
assign is_opening = (event_code == 3'd5);
assign is_closing = (event_code == 3'd6);
assign continuous = is_test | is_opening | is_closing;
assign continuous_code = {3{continuous}} & event_code;
assign continuous_changed = (continuous_code != previous_continuous);

assign finite_valid = (event_code == 3'd2) | (event_code == 3'd3) |
                      (event_code == 3'd4);
assign finite_start = ~reset & ~continuous & event_start & finite_valid;
assign cancel_pattern = reset | continuous | event_start;

assign reg_pattern = (pattern_code == 3'd2);
assign valid_pattern = (pattern_code == 3'd3);
assign invalid_pattern = (pattern_code == 3'd4);
assign duration =
    ({PAT_BITS{reg_pattern}} & PAT_BITS'(BUZZER_BEEP_CYCLES)) |
    ({PAT_BITS{valid_pattern}} & PAT_BITS'(2*BUZZER_BEEP_CYCLES + BUZZER_GAP_CYCLES)) |
    ({PAT_BITS{invalid_pattern}} & PAT_BITS'(BUZZER_INVALID_CYCLES));
assign pattern_done = (elapsed == duration - 1'b1);
assign pattern_next = finite_start |
    (pattern_active & ~pattern_done & ~cancel_pattern);
assign advance_pattern = pattern_active & ~pattern_done & ~cancel_pattern;
assign elapsed_next = {PAT_BITS{advance_pattern}} & (elapsed + 1'b1);
assign hold_code = ~reset & ~continuous & ~event_start & pattern_next;
assign code_next = ({3{finite_start}} & event_code) |
                   ({3{hold_code}} & pattern_code);

// VALID: sonido, pausa, sonido. REG_OK e INVALID: un unico sonido.
assign finite_sound = pattern_active & (reg_pattern | invalid_pattern |
    (valid_pattern & ((elapsed < PAT_BITS'(BUZZER_BEEP_CYCLES)) |
      (elapsed >= PAT_BITS'(BUZZER_BEEP_CYCLES + BUZZER_GAP_CYCLES)))));
assign tone_enable = ~reset & (continuous | finite_sound);

// Tono continuo prioritario; los demas tonos usan el codigo almacenado.
assign half_period =
    ({TONE_BITS{is_test}} & TONE_BITS'(BUZZER_TEST_HALF)) |
    ({TONE_BITS{is_opening}} & TONE_BITS'(BUZZER_OPENING_HALF)) |
    ({TONE_BITS{is_closing}} & TONE_BITS'(BUZZER_CLOSING_HALF)) |
    ({TONE_BITS{~continuous & pattern_active & reg_pattern}} & TONE_BITS'(BUZZER_REG_OK_HALF)) |
    ({TONE_BITS{~continuous & pattern_active & valid_pattern}} & TONE_BITS'(BUZZER_VALID_HALF)) |
    ({TONE_BITS{~continuous & pattern_active & invalid_pattern}} & TONE_BITS'(BUZZER_INVALID_HALF));
assign tone_end = (tone_counter == ((half_period << 1) - 1'b1));
assign advance_tone = tone_enable & ~event_start & ~continuous_changed & ~tone_end;
assign tone_next = {TONE_BITS{advance_tone}} & (tone_counter + 1'b1);

always_ff @(posedge clk) begin
    pattern_active <= pattern_next;
    pattern_code <= code_next;
    elapsed <= elapsed_next;
    tone_counter <= tone_next;
    previous_continuous <= {3{~reset}} & continuous_code;
end

assign buzzer_out = tone_enable & (tone_counter < half_period);

endmodule
