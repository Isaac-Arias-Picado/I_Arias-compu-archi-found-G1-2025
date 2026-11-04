`timescale 1ns/1ps

module tb_timer_travel;

import config_pkg::*;

logic clk, reset, tick_ms, start;
logic [2:0] speed;
logic wait_done, travel_done;

timer_travel dut (
    .clk(clk),
    .reset(reset),
    .tick_ms(tick_ms),
    .start(start),
    .speed(speed),
    .wait_done(wait_done),
    .travel_done(travel_done)
);

initial clk = 0;
always #10 clk = ~clk;

int errors = 0;

int expected;

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
    speed = 3'd1;
    reset = 1;

    repeat(5) @(posedge clk);

    // Test 1: despues del reset las salidas deben estar en 0
    if (wait_done | travel_done) begin
        $display("FAIL [Test 1]: salidas activas despues del reset");
        errors++;
    end else begin
        $display("PASS [Test 1]: salidas en 0 despues del reset");
    end

    reset = 0;

    // Test 2: wait_done se activa exactamente al tick TEST_WAIT_MS
    pulse_start();
    send_ticks(TEST_WAIT_MS - 1);
    if (wait_done) begin
        $display("FAIL [Test 2]: wait_done se activo antes de %0d ticks", TEST_WAIT_MS);
        errors++;
    end

    send_ticks(1);
    if (wait_done) begin
        $display("PASS [Test 2]: wait_done se activo justo a los %0d ticks", TEST_WAIT_MS);
    end else begin
        $display("FAIL [Test 2]: wait_done no se activo a los %0d ticks", TEST_WAIT_MS);
        errors++;
    end

    // Test 3: travel_done se activa justo en el tiempo de la LUT, para cada velocidad
    // El tiempo esperado se calcula con la misma formula del paquete: T_MAX_MS * 7 / s
    for (int s = 1; s <= 7; s++) begin
        speed = s;
        expected = T_MAX_MS * 7 / s;
        pulse_start();
        send_ticks(expected - 1);
        if (travel_done) begin
            $display("FAIL [Test 3]: speed=%0d travel_done antes de %0d ticks", s, expected);
            errors++;
        end

        send_ticks(1);
        if (travel_done) begin
            $display("PASS [Test 3]: speed=%0d travel_done justo a los %0d ticks", s, expected);
        end else begin
            $display("FAIL [Test 3]: speed=%0d travel_done no se activo a los %0d ticks", s, expected);
            errors++;
        end
    end

    // Test 4: saturacion, la cuenta se detiene en TRAVEL_MS_MAX
    speed = 3'd1;
    pulse_start();
    send_ticks(TRAVEL_MS_MAX + 100);
    if (dut.count == TRAVEL_MS_MAX) begin
        $display("PASS [Test 4]: cuenta saturada en %0d", TRAVEL_MS_MAX);
    end else begin
        $display("FAIL [Test 4]: cuenta=%0d, se esperaba %0d", dut.count, TRAVEL_MS_MAX);
        errors++;
    end

    // Test 5: con speed = 0, wait_done sigue funcionando (caso de S_VALID)
    speed = 3'd0;
    pulse_start();
    send_ticks(TEST_WAIT_MS);
    if (wait_done) begin
        $display("PASS [Test 5]: con speed=0 wait_done se activa a los %0d ticks", TEST_WAIT_MS);
    end else begin
        $display("FAIL [Test 5]: con speed=0 wait_done no se activo (cuenta=%0d)", dut.count);
        errors++;
    end

    // Test 6: sin ticks la cuenta se mantiene (hold)
    speed = 3'd1;
    pulse_start();
    send_ticks(10);
    repeat(20) @(posedge clk);
    if (dut.count == 10) begin
        $display("PASS [Test 6]: sin ticks la cuenta se mantiene en 10");
    end else begin
        $display("FAIL [Test 6]: cuenta=%0d, se esperaba 10", dut.count);
        errors++;
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

    // Test 8: reset a mitad de la cuenta tambien limpia
    @(negedge clk) reset = 1;
    @(negedge clk) reset = 0;
    if (wait_done | (dut.count != 0)) begin
        $display("FAIL [Test 8]: reset no limpio la cuenta (cuenta=%0d)", dut.count);
        errors++;
    end else begin
        $display("PASS [Test 8]: reset a mitad de cuenta limpia todo");
    end

    $display("Simulacion terminada. Errores: %0d", errors);
    $finish;
end

endmodule