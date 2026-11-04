module fsm_main (
    input logic clk,
    input logic reset,
    input logic rst,
    input logic adm,
    input logic tst,
    input logic ready,
    input logic match1,
    input logic match2,
    input logic valid1,
    input logic valid2,
    input logic [2:0] alu_result,
    input logic wait_done,
    input logic travel_done,
    output logic [2:0] state,
    output logic [2:0] mode,
    output logic door_open_flag,
    output logic [2:0] speed,
    output logic [1:0] motor_dir,
    output logic [2:0] bz_code,
    output logic bz_start,
    output logic timer_start,
    output logic clear_capture,
    output logic wr1,
    output logic wr2,
    output logic del1,
    output logic del2,
    output logic clear_all
);

import config_pkg::*;

//Registros FSM
logic [2:0] state_next;
logic [2:0] mode_next;
logic [2:0] speed_next;
logic door_next;
logic [1:0] tphase;
logic [1:0] tphase_next;

/*Cada valor de los registros se
actualiza por flanco de reloj en Flip Flop*/
always_ff @(posedge clk) begin
    state <= state_next;
    mode <= mode_next;
    speed <= speed_next;
    door_open_flag <= door_next;
    tphase <= tphase_next;
end

//Estados FSM
logic is_error, is_closed, is_opening,
is_open, is_closing, is_admin, is_test,
is_valid;

assign is_error = (state == S_ERROR);
assign is_closed = (state == S_CLOSED);
assign is_opening = (state == S_OPENING);
assign is_open = (state == S_OPEN);
assign is_closing = (state == S_CLOSING);
assign is_admin = (state == S_ADMIN);
assign is_test = (state == S_TEST);
assign is_valid = (state == S_VALID);

//Submodos
logic m0, m1, m2;

assign m0 = (mode == M_NORMAL);
assign m1 = (mode == M_SLOT1);
assign m2 = (mode == M_SLOT2);

//Fases del test (resgistros tphase)
logic ph0, ph1, ph2;

assign ph0 = (tphase == 2'd0);
assign ph1 = (tphase == 2'd1);
assign ph2 = (tphase == 2'd2);

// Velocidad cero (registro speed)
logic spd0;
assign spd0 = (speed == 3'd0);

//Memoria de contrasenas (B)
logic match, has_pw;
assign match = match1 | match2;
assign has_pw = valid1 | valid2;

//CLOSED u OPEN
logic co;
assign co = is_closed | is_open;

//Tabla de transiciones
//ERROR
//rst borra contrasenas
assign clear_all = rst;

//adm entra a admin
logic e_adm;
assign e_adm = is_error & ~rst & adm;

//tst con puerta cerrada entra a test
logic e_tst;
assign e_tst = is_error & ~door_open_flag & ~rst & ~adm & tst;

//intento suena invalido
logic  e_rdy;
assign e_rdy = is_error & ~rst & ~adm & ~(tst & ~door_open_flag) & ready;

//CLOSED y OPEN
//rst va a error
logic co_rst;
assign co_rst = co & rst;

//adm entra a admin
logic co_adm;
assign co_adm = co & ~rst & adm;

//tst entra a test (solo cerrada)
logic c_tst;
assign c_tst = is_closed & ~rst & ~adm & tst;

//contrasena correcta va a valid
logic co_ok;
assign co_ok = co & ~rst & ~adm & ~(is_closed & tst) & ready & match;

//contrasena incorrecta suena invalido
logic co_bad;
assign co_bad = co & ~rst & ~adm & ~(is_closed & tst) & ready & ~match;

//VALID
//rst va a error
logic v_rst;
assign v_rst = is_valid & rst;

//paso 1 s, mueve la puerta
logic v_go;
assign v_go = is_valid & ~rst & wait_done & ~spd0;

//paso 1 s, velocidad 0 no se mueve
logic v_stay;
assign v_stay = is_valid & ~rst & wait_done & spd0;

//OPENING y CLOSING
//termino el viaje
logic opg_done, clg_done;
assign opg_done = is_opening & ~rst & travel_done;
assign clg_done = is_closing & ~rst & travel_done;

//ADMIN
//rst va a error
logic a_rst;
assign a_rst = is_admin & rst;

//mode 0 sale de admin
logic a_exit;
assign a_exit = is_admin & ~rst & m0;

//adm cambia de espacio
logic a_adm;
assign a_adm = is_admin & ~rst & ~m0 & adm;

//contrasena repetida se borra
logic a_del;
assign a_del = is_admin & ~rst & ~m0 & ~adm & ready & match;

//contrasena nueva se guarda
logic a_wr;
assign a_wr = is_admin & ~rst & ~m0 & ~adm & ready & ~match;

//TEST
//termino de abrir, espera 1 s
logic t_p0;
assign t_p0 = is_test & ~rst & ph0 & travel_done;

//termino de esperar, cierra
logic t_p1;
assign t_p1 = is_test & ~rst & ph1 & wait_done;

//termino de cerrar, sale de test
logic t_end;
assign t_end = is_test & ~rst & ph2 & travel_done;

//Expresiones de los registros
//Estado
logic hold_st;
assign hold_st = ~(e_adm | e_tst | co_rst | co_adm | c_tst | co_ok | v_rst
| v_go | v_stay | opg_done | clg_done | a_rst | a_exit | t_end);

assign state_next = {3{~reset}} & (({3{e_adm | co_adm}} & S_ADMIN)
| ({3{e_tst | c_tst}} & S_TEST) | ({3{co_ok}} & S_VALID)
| ({3{v_go & ~door_open_flag}} & S_OPENING)
| ({3{v_go & door_open_flag}} & S_CLOSING)
| ({3{v_stay & ~door_open_flag}} & S_CLOSED)
| ({3{v_stay & door_open_flag}} & S_OPEN) | ({3{opg_done & has_pw}} & S_OPEN)
| ({3{clg_done & has_pw}} & S_CLOSED)
| ({3{a_exit & has_pw & ~door_open_flag}} & S_CLOSED)
| ({3{a_exit & has_pw & door_open_flag}} & S_OPEN)
| ({3{t_end & has_pw}} & S_CLOSED) | ({3{hold_st}} & state));

//Submodo
logic mode_hold;
assign mode_hold = is_admin & ~rst & ~m0 & ~adm & ~ready;

assign mode_next = {3{~reset}} & (({3{e_adm | co_adm}} & M_SLOT1)
| ({3{a_adm & m1}} & M_SLOT2) | ({3{mode_hold}} & mode));

//Fase del test
logic tphase_hold;
assign tphase_hold = is_test & ~(t_p0 | t_p1 | t_end);

assign tphase_next = {2{~reset}} & (({2{t_p0}} & 2'd1) | ({2{t_p1}} & 2'd2)
| ({2{tphase_hold}} & tphase));

//Velocidad
logic spd_hold;
assign spd_hold = ~(e_tst | c_tst | co_ok);

assign speed_next = {3{~reset}} & (({3{co_ok}} & alu_result)
| ({3{e_tst | c_tst}} & TEST_SPEED) | ({3{spd_hold}} & speed));

//Puerta
assign door_next = ~reset & (opg_done | (door_open_flag & ~clg_done));

//Expresiones de las salidas
//Motor (10 abre, 01 cierra)
assign motor_dir[1] = is_opening | (is_test & ph0);
assign motor_dir[0] = is_closing | (is_test & ph2);

//Buzzer
logic ev_valid, ev_invalid, ev_regok;
assign ev_valid = co_ok;
assign ev_invalid = e_rdy | co_bad;
assign ev_regok = a_del | a_wr;

assign bz_start = ev_valid | ev_invalid | ev_regok;
assign bz_code = ({3{is_opening}} & BZ_OPENING) | ({3{is_closing}} & BZ_CLOSING)
| ({3{is_test}} & BZ_TEST) | ({3{ev_valid}} & BZ_VALID)
| ({3{ev_invalid}} & BZ_INVALID) | ({3{ev_regok}} & BZ_REG_OK);

//Timer
assign timer_start = e_tst | c_tst | co_ok | v_go | t_p0 | t_p1;

//Captura
assign clear_capture = rst | e_rdy | co_ok | co_bad | a_del | a_wr | is_valid
| is_opening | is_closing | is_test;

//Memoria
assign wr1 = a_wr & m1;
assign wr2 = a_wr & m2;
assign del1 = a_del & match1;
assign del2 = a_del & match2;

endmodule