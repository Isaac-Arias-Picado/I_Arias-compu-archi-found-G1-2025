`timescale 1ns/1ps

module tb_debounce;

import config_pkg::*;

localparam real CLK_PERIOD  = 20.0;
localparam int  TICK_PERIOD = 10;   // tick_debounce acelerado

logic clk, reset, tick_debounce;
logic btn_admin, btn_test, btn_reset;
logic [4:0] finger_raw;
logic admin_pressed, test_pressed, reset_pressed;
logic finger_valid;
logic [2:0] finger_symbol;

debounce dut (
    .clk(clk), .reset(reset), .tick_debounce(tick_debounce),
    .btn_admin(btn_admin), .btn_test(btn_test), .btn_reset(btn_reset),
    .finger_raw(finger_raw),
    .admin_pressed(admin_pressed), .test_pressed(test_pressed), .reset_pressed(reset_pressed),
    .finger_valid(finger_valid), .finger_symbol(finger_symbol)
);

initial clk = 0;
always #(CLK_PERIOD/2.0) clk = ~clk;

// Generador de tick acelerado
int tick_cnt = 0;
always @(posedge clk) begin
    if (reset) begin
        tick_cnt      <= 0;
        tick_debounce <= 0;
    end else if (tick_cnt == TICK_PERIOD - 1) begin
        tick_cnt      <= 0;
        tick_debounce <= 1;
    end else begin
        tick_cnt      <= tick_cnt + 1;
        tick_debounce <= 0;
    end
end

int admin_pulses = 0, test_pulses = 0, reset_pulses = 0;
always @(posedge clk) begin
    if (admin_pressed) admin_pulses++;
    if (test_pressed)  test_pulses++;
    if (reset_pressed) reset_pulses++;
end

int errors = 0;

task automatic wait_ticks(int n);
    for (int i = 0; i < n; i++) begin
        @(posedge clk);
        while (!tick_debounce) @(posedge clk);
    end
endtask

initial begin
    reset = 1;
    btn_admin = 0; btn_test = 0; btn_reset = 0;
    finger_raw = 5'b00000;
    repeat (5) @(posedge clk);
    reset = 0;
    repeat (5) @(posedge clk);

    // Test 1: admin button single pulse
    admin_pulses = 0;
    btn_admin = 1; repeat (5) @(posedge clk); btn_admin = 0; repeat (5) @(posedge clk);
    if (admin_pulses != 1) begin
        $display("FAIL [Test 1]: admin_pulses=%0d expected 1", admin_pulses); errors++;
    end else $display("PASS [Test 1]: admin button single pulse");

    // Test 2: test button single pulse
    test_pulses = 0;
    btn_test = 1; repeat (5) @(posedge clk); btn_test = 0; repeat (5) @(posedge clk);
    if (test_pulses != 1) begin
        $display("FAIL [Test 2]: test_pulses=%0d expected 1", test_pulses); errors++;
    end else $display("PASS [Test 2]: test button single pulse");

    // Test 3: reset button single pulse
    reset_pulses = 0;
    btn_reset = 1; repeat (5) @(posedge clk); btn_reset = 0; repeat (5) @(posedge clk);
    if (reset_pulses != 1) begin
        $display("FAIL [Test 3]: reset_pulses=%0d expected 1", reset_pulses); errors++;
    end else $display("PASS [Test 3]: reset button single pulse");

    // Test 4: 00001 estable -> valid, symbol 1
    finger_raw = 5'b00001;
    wait_ticks(DEBOUNCE_SAMPLES + 5);
    if (!finger_valid || finger_symbol != 3'd1) begin
        $display("FAIL [Test 4]: valid=%0d sym=%0d", finger_valid, finger_symbol); errors++;
    end else $display("PASS [Test 4]: 00001 -> symbol 1");

    // Test 5: 00000 -> symbol 0 valid
    finger_raw = 5'b00000;
    wait_ticks(DEBOUNCE_SAMPLES + 5);
    if (!finger_valid || finger_symbol != 3'd0) begin
        $display("FAIL [Test 5]: valid=%0d sym=%0d", finger_valid, finger_symbol); errors++;
    end else $display("PASS [Test 5]: 00000 -> symbol 0");

    // Test 6: 10000 (5 dedos) -> symbol 5
    finger_raw = 5'b10000;
    wait_ticks(DEBOUNCE_SAMPLES + 5);
    if (!finger_valid || finger_symbol != 3'd5) begin
        $display("FAIL [Test 6]: valid=%0d sym=%0d", finger_valid, finger_symbol); errors++;
    end else $display("PASS [Test 6]: 10000 -> symbol 5");

    // Test 7: 00011 (dos bits) -> invalid
    finger_raw = 5'b00011;
    wait_ticks(DEBOUNCE_SAMPLES + 5);
    if (finger_valid) begin
        $display("FAIL [Test 7]: multi-bit reportado como valido"); errors++;
    end else $display("PASS [Test 7]: 00011 -> invalid");

    // Test 8: cambio rápido no actualiza stable
    finger_raw = 5'b01000;               // establece 4 dedos
    wait_ticks(DEBOUNCE_SAMPLES + 5);
    finger_raw = 5'b00100; wait_ticks(5); // 5 ticks (< DEBOUNCE_SAMPLES)
    finger_raw = 5'b01000; wait_ticks(DEBOUNCE_SAMPLES + 5);
    if (finger_symbol != 3'd4) begin
        $display("FAIL [Test 8]: stable cambio a %0d (esperado 4)", finger_symbol); errors++;
    end else $display("PASS [Test 8]: cambio rapido rechazado");

    // Test 9: 00010 -> symbol 2
    finger_raw = 5'b00010;
    wait_ticks(DEBOUNCE_SAMPLES + 5);
    if (finger_symbol != 3'd2) begin
        $display("FAIL [Test 9]: sym=%0d esperado 2", finger_symbol); errors++;
    end else $display("PASS [Test 9]: 00010 -> symbol 2");

    $display("=== Simulation complete. Errors: %0d ===", errors);
    $finish;
end

initial begin
    #(CLK_PERIOD * 50000);
    $display("FAIL [Timeout]");
    $finish;
end

endmodule