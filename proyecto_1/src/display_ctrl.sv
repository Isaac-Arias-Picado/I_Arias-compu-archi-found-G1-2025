// Seis displays independientes, activos bajos, orden gfedcba.
// Codigos de estado/modo compatibles con config_pkg. Sin reloj ni barrido.
module display_ctrl (
    input  logic       reset,
    input  logic [2:0] state,
    input  logic [2:0] mode,
    input  logic [2:0] speed,
    input  logic [8:0] window,
    input  logic       door_open_flag,
    output logic [6:0] HEX0,
    output logic [6:0] HEX1,
    output logic [6:0] HEX2,
    output logic [6:0] HEX3,
    output logic [6:0] HEX4,
    output logic [6:0] HEX5
);

logic position_state, test_state;
logic [4:0] state_char, mode_char;
logic [3:0] speed_hex;
logic [4:0] char0, char1, char2, char3, char4, char5;

// ADMIN, TEST y VALID no mueven la puerta: HEX0 muestra la posicion recordada.
assign test_state = (state == 3'd6);
assign position_state = (state == 3'd5) | test_state | (state == 3'd7);

// HEX0: E, C, o, A, c.
assign state_char =
    ({5{state == 3'd0}} & 5'h0E) |
    ({5{state == 3'd1}} & 5'h0C) |
    ({5{state == 3'd2}} & 5'h10) |
    ({5{state == 3'd3}} & 5'h0A) |
    ({5{state == 3'd4}} & 5'h11) |
    ({5{position_state & ~door_open_flag}} & 5'h0C) |
    ({5{position_state & door_open_flag}} & 5'h0A);

// HEX4: t en TEST, el espacio (1 o 2) en ADMIN y n en el resto.
// mode solo es distinto de 0 dentro de ADMIN.
assign mode_char =
    ({5{test_state}} & 5'h13) |
    ({5{~test_state & (mode == 3'd0)}} & 5'h12) |
    ({5{~test_state & (mode != 3'd0)}} & {2'b00, mode});

// HEX5: velocidad normalizada a 0-F, round(15*speed/7).
assign speed_hex =
    ({4{speed == 3'd1}} & 4'h2) |
    ({4{speed == 3'd2}} & 4'h4) |
    ({4{speed == 3'd3}} & 4'h6) |
    ({4{speed == 3'd4}} & 4'h9) |
    ({4{speed == 3'd5}} & 4'hB) |
    ({4{speed == 3'd6}} & 4'hD) |
    ({4{speed == 3'd7}} & 4'hF);

// Digitos del intento en orden de lectura: el primero en HEX3, el ultimo en HEX1.
// window[8:6] es el mas viejo y window[2:0] el mas nuevo.
// Reset selecciona 1F (apagado).
assign char0 = ({5{~reset}} & state_char) | {5{reset}};
assign char1 = ({5{~reset}} & {2'b00, window[2:0]}) | {5{reset}};
assign char2 = ({5{~reset}} & {2'b00, window[5:3]}) | {5{reset}};
assign char3 = ({5{~reset}} & {2'b00, window[8:6]}) | {5{reset}};
assign char4 = ({5{~reset}} & mode_char) | {5{reset}};
assign char5 = ({5{~reset}} & {1'b0, speed_hex}) | {5{reset}};

seven_seg dec0 (.char_code(char0), .segments(HEX0));
seven_seg dec1 (.char_code(char1), .segments(HEX1));
seven_seg dec2 (.char_code(char2), .segments(HEX2));
seven_seg dec3 (.char_code(char3), .segments(HEX3));
seven_seg dec4 (.char_code(char4), .segments(HEX4));
seven_seg dec5 (.char_code(char5), .segments(HEX5));

endmodule
