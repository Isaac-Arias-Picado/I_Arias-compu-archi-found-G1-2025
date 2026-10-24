`timescale 1ns/1ps

module tb_timer_travel;

import config_pkg::*;

logic clk, reset, tick_ms, start;
logic wait_done, timeout;

timer_travel dut (
    .clk(clk),
    .reset(reset),
    .tick_ms(tick_ms),
    .start(start),
    .wait_done(wait_done),
    .timeout(timeout)
);

initial clk = 0;
always #10 clk = ~clk;

int errors = 0;

// Manda n pulsos de tick_ms, uno cada 2 ciclos de reloj
task send_ticks(input int n);
    repeat (n) begin
        @(negedge clk) tick_ms = 1;
        @(negedge clk) tick_ms = 0;
    end
endtask

// Pulso de start de un ciclo
task pulse_start();
    @(negedge clk) start = 1;
    @(negedge clk) start = 0;
endtask

initial begin
    tick_ms = 0;
    start = 0;
    reset = 1;

    repeat(5) @(posedge clk);
    
    // Test 1: después del reset las dos salidas deben estar en 0
    if (wait_done | timeout) begin
        $display("FAIL [Test 1]: salidas activas despues del reset");
        errors++;
    end else begin
        $display("PASS [Test 1]: salidas en 0 despues del reset");
    end

    reset = 0;

    //Test 2: se verifica si wait_done se activa unicamente cuando coincida que tick_ms llego a 1000
    pulse_start();
    send_ticks(999);
    if(wait_done) begin
        $display("FAIL [Test2]: wait_done se cambio a valor 1 antes de que tick_ms fuese 1000");
        errors++;
    end 

    send_ticks(1);

    if(wait_done) begin
        $display("PASS [Test2]: el wait_done cambio cuando se alcanzo los 1000 ticks esperados");
    end else begin
        $display("FAIL [Test2]: wait_done no cambio al alcanzar los 1000 ticks");
        errors++;
    end

    // Test 3: timeout se activa exactamente al tick TIMEOUT_MS
    // La cuenta ya va en TEST_WAIT_MS, faltan TIMEOUT_MS - TEST_WAIT_MS
    send_ticks(TIMEOUT_MS - TEST_WAIT_MS - 1);
    if (timeout) begin
        $display("FAIL [Test 3]: timeout se activo antes de %0d ticks", TIMEOUT_MS);
        errors++;
    end

    send_ticks(1);
    if (timeout & wait_done) begin
        $display("PASS [Test 3]: timeout se activo justo a los %0d ticks", TIMEOUT_MS);
    end else begin
        $display("FAIL [Test 3]: timeout=%b wait_done=%b a los %0d ticks",
                 timeout, wait_done, TIMEOUT_MS);
        errors++;
    end

    // Test 4: saturación, la cuenta no pasa del límite ni vuelve a 0
    send_ticks(100);
    if (timeout & (dut.count == TIMEOUT_MS)) begin
        $display("PASS [Test 4]: cuenta saturada en %0d con timeout activo", TIMEOUT_MS);
    end else begin
        $display("FAIL [Test 4]: cuenta=%0d timeout=%b tras ticks extra",
                 dut.count, timeout);
        errors++;
    end

    // Test 5: sin ticks la cuenta se mantiene (hold)
    pulse_start();
    send_ticks(10);
    repeat(20) @(posedge clk);
    if (dut.count == 10) begin
        $display("PASS [Test 5]: sin ticks la cuenta se mantiene en 10");
    end else begin
        $display("FAIL [Test 5]: cuenta=%0d, se esperaba 10", dut.count);
        errors++;
    end

    // Test 6: start después del timeout limpia la cuenta y las salidas
    send_ticks(TIMEOUT_MS);
    pulse_start();
    if (wait_done | timeout | (dut.count != 0)) begin
        $display("FAIL [Test 6]: tras start cuenta=%0d wait_done=%b timeout=%b",
                 dut.count, wait_done, timeout);
        errors++;
    end else begin
        $display("PASS [Test 6]: start limpia cuenta y salidas despues del timeout");
    end

    // Test 7: start a mitad de la cuenta reinicia desde 0
    send_ticks(500);
    pulse_start();
    send_ticks(TEST_WAIT_MS - 1);
    if (wait_done) begin
        $display("FAIL [Test 7]: wait_done se activo sin reiniciar la cuenta");
        errors++;
    end

    send_ticks(1);
    if (wait_done) begin
        $display("PASS [Test 7]: start a mitad de cuenta reinicia desde 0");
    end else begin
        $display("FAIL [Test 7]: wait_done no se activo tras reiniciar");
        errors++;
    end

    // Test 8: reset a mitad de la cuenta también limpia
    @(negedge clk) reset = 1;
    @(negedge clk) reset = 0;
    if (wait_done | timeout | (dut.count != 0)) begin
        $display("FAIL [Test 8]: reset no limpio la cuenta (cuenta=%0d)", dut.count);
        errors++;
    end else begin
        $display("PASS [Test 8]: reset a mitad de cuenta limpia todo");
    end

    $display("Simulacion terminada. Errores: %0d", errors);
    $finish;
end

endmodule