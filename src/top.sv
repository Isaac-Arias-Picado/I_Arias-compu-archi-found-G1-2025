module top (
    input logic CLOCK_50,
    input logic [3:0] KEY,
    input logic [4:0] FINGER,
    output logic [1:0] MOTOR,
    output logic BUZZER,
    output logic [6:0] HEX0,
    output logic [6:0] HEX1,
    output logic [6:0] HEX2,
    output logic [6:0] HEX3,
    output logic [6:0] HEX4,
    output logic [6:0] HEX5
);

import config_pkg::*;

logic clk;
assign clk = CLOCK_50;

//Reset de encendido (8 ciclos, el contador arranca en 0 al programar)
logic [3:0] por_cnt = 4'd0;
logic reset;
assign reset = ~por_cnt[3];

always_ff @(posedge clk) begin
    por_cnt <= por_cnt + {3'b000, reset};
end

//Botones (KEY es activo en bajo)
logic btn_reset, btn_admin, btn_test;
assign btn_reset = ~KEY[0];
assign btn_admin = ~KEY[1];
assign btn_test = ~KEY[2];

//Senales entre bloques
logic tick_capture, tick_debounce, tick_display;
logic rst, adm, tst;
logic finger_valid;
logic [2:0] finger_symbol;
logic [8:0] window;
logic ready;
logic [8:0] pass1, pass2;
logic valid1, valid2, match1, match2;
logic [2:0] alu_result;
logic wait_done, travel_done;
logic [2:0] state, mode, speed;
logic door_open_flag;
logic [1:0] motor_dir;
logic [2:0] bz_code;
logic bz_start, timer_start, clear_capture;
logic wr1, wr2, del1, del2, clear_all;
logic pwm_out;

//Bloque A
clk_enables u_clk_enables (
    .clk(clk),
    .reset(reset),
    .tick_capture(tick_capture),
    .tick_debounce(tick_debounce),
    .tick_display(tick_display)
);

debounce u_debounce (
    .clk(clk),
    .reset(reset),
    .tick_debounce(tick_debounce),
    .btn_admin(btn_admin),
    .btn_test(btn_test),
    .btn_reset(btn_reset),
    .finger_raw(FINGER),
    .admin_pressed(adm),
    .test_pressed(tst),
    .reset_pressed(rst),
    .finger_valid(finger_valid),
    .finger_symbol(finger_symbol)
);

finger_capture u_finger_capture (
    .clk(clk),
    .reset(reset),
    .tick_capture(tick_capture),
    .finger_valid(finger_valid),
    .finger_symbol(finger_symbol),
    .clear_capture(clear_capture),
    .window(window)
);

//Bloque B
alu u_alu (
    .op(window[8:6]),
    .a(window[5:3]),
    .b(window[2:0]),
    .result(alu_result)
);

password_mem u_password_mem (
    .clk(clk),
    .reset(reset),
    .window(window),
    .wr1(wr1),
    .wr2(wr2),
    .del1(del1),
    .del2(del2),
    .clear_all(clear_all),
    .pass1(pass1),
    .pass2(pass2),
    .valid1(valid1),
    .valid2(valid2)
);

comparator u_comparator (
    .window(window),
    .pass1(pass1),
    .pass2(pass2),
    .valid1(valid1),
    .valid2(valid2),
    .match1(match1),
    .match2(match2)
);

//Bloque C
attempt_ctrl u_attempt_ctrl (
    .clk(clk),
    .reset(reset),
    .tick_capture(tick_capture),
    .finger_valid(finger_valid),
    .finger_symbol(finger_symbol),
    .clear_capture(clear_capture),
    .ready(ready)
);

timer_travel u_timer_travel (
    .clk(clk),
    .reset(reset),
    .tick_ms(tick_debounce),
    .start(timer_start),
    .speed(speed),
    .wait_done(wait_done),
    .travel_done(travel_done)
);

fsm_main u_fsm_main (
    .clk(clk),
    .reset(reset),
    .rst(rst),
    .adm(adm),
    .tst(tst),
    .ready(ready),
    .match1(match1),
    .match2(match2),
    .valid1(valid1),
    .valid2(valid2),
    .alu_result(alu_result),
    .wait_done(wait_done),
    .travel_done(travel_done),
    .state(state),
    .mode(mode),
    .door_open_flag(door_open_flag),
    .speed(speed),
    .motor_dir(motor_dir),
    .bz_code(bz_code),
    .bz_start(bz_start),
    .timer_start(timer_start),
    .clear_capture(clear_capture),
    .wr1(wr1),
    .wr2(wr2),
    .del1(del1),
    .del2(del2),
    .clear_all(clear_all)
);

//Bloque D
pwm #(
    .CLK_FREQ_HZ(CLK_FREQ_HZ),
    .PWM_FREQ_HZ(PWM_FREQ_HZ)
) u_pwm (
    .clk(clk),
    .reset(reset),
    .speed(speed),
    .pwm_out(pwm_out)
);

motor_ctrl u_motor_ctrl (
    .reset(reset),
    .motor_dir(motor_dir),
    .pwm_in(pwm_out),
    .motor_lines(MOTOR)
);

buzzer_ctrl #(
    .BUZZER_TEST_HALF(BUZZER_TEST_HALF),
    .BUZZER_REG_OK_HALF(BUZZER_REG_OK_HALF),
    .BUZZER_VALID_HALF(BUZZER_VALID_HALF),
    .BUZZER_INVALID_HALF(BUZZER_INVALID_HALF),
    .BUZZER_OPENING_HALF(BUZZER_OPENING_HALF),
    .BUZZER_CLOSING_HALF(BUZZER_CLOSING_HALF),
    .BUZZER_BEEP_CYCLES(BUZZER_BEEP_CYCLES),
    .BUZZER_INVALID_CYCLES(BUZZER_INVALID_CYCLES),
    .BUZZER_GAP_CYCLES(BUZZER_GAP_CYCLES)
) u_buzzer_ctrl (
    .clk(clk),
    .reset(reset),
    .event_code(bz_code),
    .event_start(bz_start),
    .buzzer_out(BUZZER)
);

//En VALID el display muestra la posicion de la puerta
logic is_valid;
logic [2:0] disp_state;
assign is_valid = (state == S_VALID);
assign disp_state = ({3{~is_valid}} & state)
| ({3{is_valid & ~door_open_flag}} & S_CLOSED)
| ({3{is_valid & door_open_flag}} & S_OPEN);

//El display muestra la ultima captura y la mantiene hasta la siguiente,
//asi el usuario alcanza a ver el tercer digito aunque la FSM limpie la ventana
logic shift, shift_d;
logic [8:0] disp_window, disp_window_next;
assign shift = tick_capture & finger_valid;
assign disp_window_next = {9{~reset}} & (({9{shift_d}} & window)
| ({9{~shift_d}} & disp_window));

always_ff @(posedge clk) begin
    shift_d <= shift;
    disp_window <= disp_window_next;
end

display_ctrl u_display_ctrl (
    .reset(reset),
    .state(disp_state),
    .mode(mode),
    .speed(speed),
    .window(disp_window),
    .door_open_flag(door_open_flag),
    .HEX0(HEX0),
    .HEX1(HEX1),
    .HEX2(HEX2),
    .HEX3(HEX3),
    .HEX4(HEX4),
    .HEX5(HEX5)
);

endmodule