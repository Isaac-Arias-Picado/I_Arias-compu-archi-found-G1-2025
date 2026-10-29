`timescale 1ns/1ps

//Prueba del sistema completo. Se compila con config_pkg_sim.sv en vez de
//src/config_pkg.sv para que la captura y el tick de 1 ms sean mas rapidos.
module tb_top;

import config_pkg::*;

//Senales
logic CLOCK_50;
logic [3:0] KEY;
logic [4:0] FINGER;
logic [1:0] MOTOR;
logic BUZZER;
logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;

//DUT
top dut (
    .CLOCK_50(CLOCK_50), .KEY(KEY), .FINGER(FINGER),
    .MOTOR(MOTOR), .BUZZER(BUZZER),
    .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2),
    .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5)
);

//Reloj de 50 MHz
initial CLOCK_50 = 0;
always #10 CLOCK_50 = ~CLOCK_50;

//Utilidades
int errors = 0;

task check(input logic cond, input string msg);
    if (cond) begin
        $display("PASS: %s", msg);
    end else begin
        $display("FAIL: %s (state=%0d)", msg, dut.state);
        errors++;
    end
endtask

//Presiona un KEY (activo en bajo)
task press(input int k);
    KEY[k] = 0;
    repeat (50) @(posedge CLOCK_50);
    KEY[k] = 1;
    repeat (50) @(posedge CLOCK_50);
endtask

//Patron de dedos de un digito (0 = ninguno, 1 a 5 = one-hot)
function automatic logic [4:0] pat(input int d);
    if (d == 0) return 5'b00000;
    return 5'b00001 << (d - 1);
endfunction

//Pone los dedos de un intento, un digito por cada captura
task enter(input int d1, input int d2, input int d3);
    FINGER = pat(d1);
    repeat (CAPTURE_CYCLES) @(posedge CLOCK_50);
    FINGER = pat(d2);
    repeat (CAPTURE_CYCLES) @(posedge CLOCK_50);
    FINGER = pat(d3);
    repeat (CAPTURE_CYCLES) @(posedge CLOCK_50);
    FINGER = 0;
    repeat (CAPTURE_CYCLES + 500) @(posedge CLOCK_50);
endtask

//Espera hasta llegar a un estado (con limite para no colgarse)
task automatic wait_state(input logic [2:0] target, input int max_cycles);
    int n;
    n = 0;
    while ((dut.state != target) && (n < max_cycles)) begin
        @(posedge CLOCK_50);
        n++;
    end
endtask

//Pruebas
int pwm_high;

initial begin
    KEY = 4'b1111;
    FINGER = 0;
    repeat (100) @(posedge CLOCK_50);

    //Test 1: encendido
    check(dut.state == S_ERROR && MOTOR == 2'b00,
          "Test 1: al encender queda en ERROR con el motor quieto");

    //Test 2: registrar una contrasena
    press(1);
    check(dut.state == S_ADMIN && dut.mode == M_SLOT1,
          "Test 2a: KEY1 entra a admin en el submodo 1");
    enter(1, 2, 1);
    wait_state(S_CLOSED, 20000);
    check(dut.valid1 && dut.state == S_CLOSED,
          "Test 2b: la contrasena 1-2-1 se guarda y sale a CLOSED");

    //Test 3: abrir
    enter(1, 2, 1);
    wait_state(S_VALID, 20000);
    check(dut.state == S_VALID && dut.speed == 3'd3,
          "Test 3a: la contrasena correcta pasa a VALID con velocidad 3 (2 + 1)");
    check(HEX0 == 7'b1000110, "Test 3b: en VALID el display muestra C");
    wait_state(S_OPENING, 30000);
    pwm_high = 0;
    repeat (200000) begin
        @(posedge CLOCK_50);
        pwm_high += MOTOR[1];
    end
    check(pwm_high > 0 && MOTOR[0] == 0, "Test 3c: al abrir sale PWM por MOTOR[1]");
    wait_state(S_OPEN, 200000);
    check(dut.state == S_OPEN && MOTOR == 2'b00,
          "Test 3d: termina en OPEN con el motor apagado");

    //Test 4: contrasena incorrecta
    enter(3, 3, 3);
    check(dut.state == S_OPEN, "Test 4: una contrasena incorrecta no cambia nada");

    //Test 5: reset
    press(0);
    check(dut.state == S_ERROR && !dut.valid1,
          "Test 5: KEY0 borra las contrasenas y pasa a ERROR");

    $display("Simulacion terminada. Errores: %0d", errors);
    $finish;
end

endmodule