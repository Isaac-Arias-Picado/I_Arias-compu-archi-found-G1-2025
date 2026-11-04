`timescale 1ns/1ps

module tb_attempt_ctrl;

import config_pkg::*;

logic clk, reset, tick_capture, finger_valid, clear_capture;
logic [2:0] finger_symbol;
logic ready;
logic [8:0] window;

attempt_ctrl dut (
    .clk(clk),
    .reset(reset),
    .tick_capture(tick_capture),
    .finger_valid(finger_valid),
    .finger_symbol(finger_symbol),
    .clear_capture(clear_capture),
    .ready(ready)
);

// Ventana real del bloque A, para revisar que ready llega con los 3 digitos
finger_capture u_capture (
    .clk(clk),
    .reset(reset),
    .tick_capture(tick_capture),
    .finger_valid(finger_valid),
    .finger_symbol(finger_symbol),
    .clear_capture(clear_capture),
    .window(window)
);

initial clk = 0;
always #10 clk = ~clk;

int errors = 0;
int ready_count = 0;
logic [8:0] window_at_ready;

// Cuenta los pulsos de ready y guarda la ventana en ese momento
always @(posedge clk) begin
    if (ready) begin
        ready_count++;
        window_at_ready = window;
    end
end

// Una captura: pone el digito y da un pulso de tick_capture
task capture(input logic [2:0] sym, input logic valid);
    @(negedge clk);
    finger_symbol = sym;
    finger_valid  = valid;
    tick_capture  = 1;
    @(negedge clk) tick_capture = 0;
    repeat (3) @(negedge clk);
endtask

task pulse_clear();
    @(negedge clk) clear_capture = 1;
    @(negedge clk) clear_capture = 0;
endtask

initial begin
    reset = 1;
    tick_capture = 0;
    finger_valid = 1;
    finger_symbol = 0;
    clear_capture = 0;
    repeat (5) @(posedge clk);
    @(negedge clk) reset = 0;

    // Test 1: sin dedos (ceros) no empieza ningun intento
    capture(3'd0, 1);
    capture(3'd0, 1);
    capture(3'd0, 1);
    capture(3'd0, 1);
    if (ready_count == 0 && dut.cnt == 0) begin
        $display("PASS [Test 1]: con ceros no arranca ningun intento");
    end else begin
        $display("FAIL [Test 1]: ready=%0d cnt=%0d con solo ceros", ready_count, dut.cnt);
        errors++;
    end

    // Test 2: intento 4-2-1 genera un ready con la ventana completa
    capture(3'd4, 1);
    capture(3'd2, 1);
    if (ready_count != 0) begin
        $display("FAIL [Test 2]: ready antes del tercer digito");
        errors++;
    end
    capture(3'd1, 1);
    if (ready_count == 1 && window_at_ready == {3'd4, 3'd2, 3'd1}) begin
        $display("PASS [Test 2]: ready con la ventana 4-2-1");
    end else begin
        $display("FAIL [Test 2]: ready=%0d ventana=%b", ready_count, window_at_ready);
        errors++;
    end

    // Test 3: despues del intento el contador vuelve a 0
    if (dut.cnt == 0) begin
        $display("PASS [Test 3]: contador en 0 despues del intento");
    end else begin
        $display("FAIL [Test 3]: cnt=%0d", dut.cnt);
        errors++;
    end

    // Test 4: los digitos 2 y 3 pueden ser 0
    pulse_clear();
    capture(3'd3, 1);
    capture(3'd0, 1);
    capture(3'd0, 1);
    if (ready_count == 2 && window_at_ready == {3'd3, 3'd0, 3'd0}) begin
        $display("PASS [Test 4]: intento 3-0-0 genera ready");
    end else begin
        $display("FAIL [Test 4]: ready=%0d ventana=%b", ready_count, window_at_ready);
        errors++;
    end

    // Test 5: un patron invalido no cuenta como digito
    pulse_clear();
    capture(3'd5, 1);
    capture(3'd2, 0);
    capture(3'd1, 1);
    if (ready_count == 2 && dut.cnt == 2) begin
        $display("PASS [Test 5]: el patron invalido no avanza el contador");
    end else begin
        $display("FAIL [Test 5]: ready=%0d cnt=%0d", ready_count, dut.cnt);
        errors++;
    end

    // Test 6: clear_capture cancela un intento a medias
    pulse_clear();
    if (dut.cnt == 0) begin
        $display("PASS [Test 6]: clear_capture cancela el intento");
    end else begin
        $display("FAIL [Test 6]: cnt=%0d despues de clear", dut.cnt);
        errors++;
    end

    // Test 7: ready dura un solo ciclo
    capture(3'd1, 1);
    capture(3'd1, 1);
    @(negedge clk);
    finger_symbol = 3'd1;
    tick_capture = 1;
    @(negedge clk) tick_capture = 0;
    @(negedge clk);
    if (ready) begin
        $display("FAIL [Test 7]: ready sigue activo despues de un ciclo");
        errors++;
    end else if (ready_count == 3) begin
        $display("PASS [Test 7]: ready dura un solo ciclo");
    end else begin
        $display("FAIL [Test 7]: ready_count=%0d", ready_count);
        errors++;
    end

    $display("Simulacion terminada. Errores: %0d", errors);
    $finish;
end

endmodule