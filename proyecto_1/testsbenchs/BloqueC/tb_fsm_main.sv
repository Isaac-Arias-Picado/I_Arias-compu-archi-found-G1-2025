`timescale 1ns/1ps

module tb_fsm_main;

import config_pkg::*;
//Senales
logic clk, reset;
logic reset_pressed, admin_pressed, test_pressed, ready;
logic match1, match2, valid1, valid2;
logic [2:0] alu_result;
logic wait_done, travel_done;
logic [2:0] state, mode, speed, bz_code;
logic door_open_flag, bz_start, timer_start, clear_capture;
logic [1:0] motor_dir;
logic wr1, wr2, del1, del2, clear_all;
logic tick_ms;
//DUT y timer real
fsm_main dut (
    .clk(clk), .reset(reset),
    .rst(reset_pressed), .adm(admin_pressed),
    .tst(test_pressed), .ready(ready),
    .match1(match1), .match2(match2), .valid1(valid1), .valid2(valid2),
    .alu_result(alu_result), .wait_done(wait_done), .travel_done(travel_done),
    .state(state), .mode(mode), .door_open_flag(door_open_flag), .speed(speed),
    .motor_dir(motor_dir), .bz_code(bz_code), .bz_start(bz_start),
    .timer_start(timer_start), .clear_capture(clear_capture),
    .wr1(wr1), .wr2(wr2), .del1(del1), .del2(del2), .clear_all(clear_all)
);

timer_travel timer (
    .clk(clk), .reset(reset), .tick_ms(tick_ms), .start(timer_start),
    .speed(speed), .wait_done(wait_done), .travel_done(travel_done)
);
//Reloj y tick de "1 ms" acelerado (uno cada 2 ciclos)
initial clk = 0;
always #10 clk = ~clk;

initial tick_ms = 0;
always @(negedge clk) tick_ms = ~tick_ms & ~reset;
//Modelo simple del bloque B (memoria de 2 espacios)
logic [8:0] window, pw1, pw2;

always_ff @(posedge clk) begin
    if (reset | clear_all) begin
        valid1 <= 0;
        valid2 <= 0;
    end else begin
        if (wr1) begin pw1 <= window; valid1 <= 1; end
        if (wr2) begin pw2 <= window; valid2 <= 1; end
        if (del1) valid1 <= 0;
        if (del2) valid2 <= 0;
    end
end

assign match1 = valid1 & (window == pw1);
assign match2 = valid2 & (window == pw2);
//Registro del ultimo sonido finito pedido
logic [2:0] last_event;
always @(posedge clk) begin
    if (bz_start) last_event <= bz_code;
end
//Utilidades
int errors = 0;

task check(input logic cond, input string msg);
    if (cond) begin
        $display("PASS: %s", msg);
    end else begin
        $display("FAIL: %s (state=%0d mode=%0d door=%b motor=%b)",
                 msg, state, mode, door_open_flag, motor_dir);
        errors++;
    end
endtask

task press_reset();
    @(negedge clk) reset_pressed = 1;
    @(negedge clk) reset_pressed = 0;
endtask

task press_admin();
    @(negedge clk) admin_pressed = 1;
    @(negedge clk) admin_pressed = 0;
endtask

task press_test();
    @(negedge clk) test_pressed = 1;
    @(negedge clk) test_pressed = 0;
endtask

//Ingresa un intento: pone la ventana y la velocidad de la ALU y da ready
task enter_code(input logic [2:0] d1, d2, d3, input logic [2:0] spd);
    @(negedge clk);
    window     = {d1, d2, d3};
    alu_result = spd;
    ready      = 1;
    @(negedge clk) ready = 0;
endtask

//Espera hasta llegar a una fase del test (con limite para no colgarse)
task wait_phase(input logic [1:0] target, input int max_cycles);
    int n;
    n = 0;
    while ((dut.tphase != target) && (n < max_cycles)) begin
        @(posedge clk);
        n++;
    end
    @(negedge clk);
endtask

//Espera hasta llegar a un estado (con limite para no colgarse)
task wait_state(input logic [2:0] target, input int max_cycles);
    int n;
    n = 0;
    while ((state != target) && (n < max_cycles)) begin
        @(posedge clk);
        n++;
    end
    @(negedge clk);
endtask
//Pruebas
initial begin
    reset = 1;
    reset_pressed = 0; admin_pressed = 0; test_pressed = 0; ready = 0;
    window = 0; alu_result = 0; last_event = BZ_NONE;
    repeat (5) @(posedge clk);
    @(negedge clk) reset = 0;

    //Test 1: encendido
    check(state == S_ERROR && !door_open_flag && motor_dir == 2'b00,
          "Test 1: al encender queda en ERROR, puerta cerrada, motor quieto");

    //Test 2: intento sin contrasenas
    enter_code(3'd4, 3'd2, 3'd1, 3'd4);
    @(negedge clk);
    check(state == S_ERROR && last_event == BZ_INVALID,
          "Test 2: en ERROR un intento suena INVALID y no cambia de estado");

    //Test 3: registrar la primera contrasena (espacio 1)
    press_admin();
    check(state == S_ADMIN && mode == M_SLOT1, "Test 3a: admin entra en el submodo 1");
    enter_code(3'd4, 3'd2, 3'd1, 3'd4);
    check(valid1 && last_event == BZ_REG_OK, "Test 3b: se guarda en el espacio 1 con REG_OK");
    wait_state(S_CLOSED, 10);
    check(state == S_CLOSED, "Test 3c: sale de admin a CLOSED");

    //Test 4: contrasena incorrecta
    enter_code(3'd1, 3'd1, 3'd1, 3'd2);
    @(negedge clk);
    check(state == S_CLOSED && last_event == BZ_INVALID,
          "Test 4: contrasena incorrecta suena INVALID y la puerta no cambia");

    //Test 5: abrir
    enter_code(3'd4, 3'd2, 3'd1, 3'd4);
    @(negedge clk);
    check(state == S_VALID && last_event == BZ_VALID && motor_dir == 2'b00,
          "Test 5a: contrasena correcta pasa a VALID, suena VALID, motor quieto");
    wait_state(S_OPENING, 3000);
    check(state == S_OPENING && motor_dir == 2'b10 && bz_code == BZ_OPENING && speed == 3'd4,
          "Test 5b: despues de 1 s abre con motor 10, sonido OPENING y speed 4");
    wait_state(S_OPEN, 20000);
    check(state == S_OPEN && door_open_flag && motor_dir == 2'b00,
          "Test 5c: al terminar el viaje queda OPEN, puerta abierta, motor quieto");

    //Test 6: la misma contrasena cierra
    enter_code(3'd4, 3'd2, 3'd1, 3'd4);
    wait_state(S_CLOSING, 3000);
    check(state == S_CLOSING && motor_dir == 2'b01 && bz_code == BZ_CLOSING,
          "Test 6a: con la puerta abierta la misma contrasena cierra (motor 01)");
    wait_state(S_CLOSED, 20000);
    check(state == S_CLOSED && !door_open_flag, "Test 6b: queda CLOSED, puerta cerrada");

    //Test 7: velocidad 0 no mueve la puerta
    enter_code(3'd4, 3'd2, 3'd1, 3'd0);
    @(negedge clk);
    check(state == S_VALID, "Test 7a: con velocidad 0 igual pasa a VALID");
    wait_state(S_CLOSED, 3000);
    check(state == S_CLOSED && !door_open_flag, "Test 7b: con velocidad 0 vuelve a CLOSED sin moverse");

    //Test 8: registrar en el espacio 2 y salir rotando el submodo
    press_admin();
    press_admin();
    check(mode == M_SLOT2, "Test 8a: el boton admin pasa al submodo 2");
    enter_code(3'd1, 3'd3, 3'd5, 3'd6);
    check(valid2, "Test 8b: se guarda en el espacio 2");
    wait_state(S_CLOSED, 10);
    press_admin();
    press_admin();
    press_admin();
    wait_state(S_CLOSED, 10);
    check(state == S_CLOSED && valid1 && valid2,
          "Test 8c: rotar 1 -> 2 -> 0 sale de admin sin tocar la memoria");

    //Test 9: la segunda contrasena tambien abre
    enter_code(3'd1, 3'd3, 3'd5, 3'd6);
    wait_state(S_OPENING, 3000);
    check(state == S_OPENING && speed == 3'd6, "Test 9a: la contrasena del espacio 2 abre");
    wait_state(S_OPEN, 20000);
    check(state == S_OPEN && door_open_flag, "Test 9b: queda OPEN");

    //Test 10: test no se permite con la puerta abierta
    press_test();
    @(negedge clk);
    check(state == S_OPEN, "Test 10: el boton de prueba se ignora con la puerta abierta");

    //Test 11: borrar una contrasena repetida desde admin
    press_admin();
    enter_code(3'd4, 3'd2, 3'd1, 3'd4);
    check(!valid1 && valid2 && last_event == BZ_REG_OK,
          "Test 11a: repetir la contrasena del espacio 1 la borra");
    wait_state(S_OPEN, 10);
    check(state == S_OPEN, "Test 11b: sale a OPEN porque aun queda una contrasena");

    //Test 12: la contrasena borrada ya no funciona
    enter_code(3'd4, 3'd2, 3'd1, 3'd4);
    @(negedge clk);
    check(state == S_OPEN && last_event == BZ_INVALID, "Test 12: la contrasena borrada suena INVALID");

    //Test 13: reset durante el movimiento no detiene el motor
    enter_code(3'd1, 3'd3, 3'd5, 3'd6);
    wait_state(S_CLOSING, 3000);
    press_reset();
    check(state == S_CLOSING && motor_dir == 2'b01 && !valid2,
          "Test 13a: reset borra contrasenas pero el motor sigue cerrando");
    wait_state(S_ERROR, 20000);
    check(state == S_ERROR && !door_open_flag,
          "Test 13b: al terminar de cerrar pasa a ERROR sabiendo que la puerta esta cerrada");

    //Test 14: secuencia de prueba desde ERROR con la puerta cerrada
    press_test();
    check(state == S_TEST && motor_dir == 2'b10 && bz_code == BZ_TEST && speed == TEST_SPEED,
          "Test 14a: test abre a TEST_SPEED con sonido TEST");
    wait_phase(2'd1, 20000);
    check(motor_dir == 2'b00 && bz_code == BZ_TEST, "Test 14b: fase 1, motor quieto, sigue sonando");
    wait_phase(2'd2, 3000);
    check(motor_dir == 2'b01, "Test 14c: fase 2, cierra");
    wait_state(S_ERROR, 20000);
    check(state == S_ERROR && !door_open_flag,
          "Test 14d: sin contrasenas el test termina en ERROR");

    //Test 15: prioridad, reset y admin en el mismo ciclo
    press_admin();
    enter_code(3'd2, 3'd2, 3'd2, 3'd1);
    wait_state(S_CLOSED, 10);
    @(negedge clk);
    reset_pressed = 1;
    admin_pressed = 1;
    @(negedge clk);
    reset_pressed = 0;
    admin_pressed = 0;
    check(state == S_ERROR && !valid1 && !valid2,
          "Test 15: con reset y admin a la vez gana el reset");

    //Test 16: borrar la unica contrasena devuelve a ERROR
    press_admin();
    enter_code(3'd3, 3'd3, 3'd3, 3'd1);
    wait_state(S_CLOSED, 10);
    press_admin();
    enter_code(3'd3, 3'd3, 3'd3, 3'd1);
    wait_state(S_ERROR, 10);
    check(state == S_ERROR && !valid1 && !valid2,
          "Test 16: borrar la ultima contrasena regresa a ERROR");

    $display("Simulacion terminada. Errores: %0d", errors);
    $finish;
end

endmodule