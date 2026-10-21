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

logic special_state, admin_state, test_state;
logic [4:0] state_char, mode_char;
logic [4:0] char0, char1, char2, char3, char4, char5;
logic oldest_valid, middle_valid, newest_valid, mode_valid;

assign admin_state = (state == 3'd5);
assign test_state = (state == 3'd6);
assign special_state = admin_state | test_state;

// HEX0: E, C, o, A, c. En ADMIN/TEST muestra la posicion recordada.
assign state_char =
    ({5{(state == 3'd0) | (state == 3'd7)}} & 5'h0E) |
    ({5{state == 3'd1}} & 5'h0C) |
    ({5{state == 3'd2}} & 5'h10) |
    ({5{state == 3'd3}} & 5'h0A) |
    ({5{state == 3'd4}} & 5'h11) |
    ({5{special_state & ~door_open_flag}} & 5'h0C) |
    ({5{special_state & door_open_flag}} & 5'h0A);

// HEX4: TEST tiene t; ADMIN tiene n/1/2/3/4; resto tiene n.
assign mode_valid = (mode <= 3'd4);
assign mode_char =
    ({5{test_state}} & 5'h13) |
    ({5{~special_state | (admin_state & (mode == 3'd0))}} & 5'h12) |
    ({5{admin_state & mode_valid & (mode != 3'd0)}} & {2'b00, mode}) |
    ({5{admin_state & ~mode_valid}} & 5'h0E);

assign oldest_valid = (window[8:6] <= 3'd5);
assign middle_valid = (window[5:3] <= 3'd5);
assign newest_valid = (window[2:0] <= 3'd5);

// Reset selecciona 1F (apagado). Los digitos 6/7 tambien quedan apagados.
assign char0 = ({5{~reset}} & state_char) | {5{reset}};
assign char1 = ({5{~reset & oldest_valid}} & {2'b00, window[8:6]}) |
               {5{reset | ~oldest_valid}};
assign char2 = ({5{~reset & middle_valid}} & {2'b00, window[5:3]}) |
               {5{reset | ~middle_valid}};
assign char3 = ({5{~reset & newest_valid}} & {2'b00, window[2:0]}) |
               {5{reset | ~newest_valid}};
assign char4 = ({5{~reset}} & mode_char) | {5{reset}};
assign char5 = ({5{~reset}} & {2'b00, speed}) | {5{reset}};

seven_seg dec0 (.char_code(char0), .segments(HEX0));
seven_seg dec1 (.char_code(char1), .segments(HEX1));
seven_seg dec2 (.char_code(char2), .segments(HEX2));
seven_seg dec3 (.char_code(char3), .segments(HEX3));
seven_seg dec4 (.char_code(char4), .segments(HEX4));
seven_seg dec5 (.char_code(char5), .segments(HEX5));

endmodule
