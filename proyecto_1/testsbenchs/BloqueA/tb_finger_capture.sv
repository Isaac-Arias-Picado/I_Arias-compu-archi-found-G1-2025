`timescale 1ns/1ps

module tb_finger_capture;

import config_pkg::*;

localparam real CLK_PERIOD  = 20.0;
localparam int  TICK_PERIOD = 5;   // tick_capture acelerado

logic clk, reset;
logic tick_capture;
logic finger_valid;
logic [2:0] finger_symbol;
logic clear_capture;
logic [8:0] window;

finger_capture dut (
    .clk(clk),
    .reset(reset),
    .tick_capture(tick_capture),
    .finger_valid(finger_valid),
    .finger_symbol(finger_symbol),
    .clear_capture(clear_capture),
    .window(window)
);

initial clk = 0;
always #(CLK_PERIOD/2.0) clk = ~clk;

// Generador de tick acelerado
int tick_cnt = 0;
always @(posedge clk) begin
    if (reset) begin
        tick_cnt      <= 0;
        tick_capture  <= 0;
    end else if (tick_cnt == TICK_PERIOD - 1) begin
        tick_cnt      <= 0;
        tick_capture  <= 1;
    end else begin
        tick_cnt      <= tick_cnt + 1;
        tick_capture  <= 0;
    end
end

int errors = 0;

// Espera exactamente un tick_capture
task automatic wait_tick();
    @(posedge clk);
    while (!tick_capture) @(posedge clk);
endtask

// Aplica un símbolo durante un tick y espera al siguiente
task automatic push_symbol(logic [2:0] sym);
    finger_symbol = sym;
    finger_valid  = 1;
    wait_tick();
endtask

initial begin
    reset         = 1;
    finger_valid  = 0;
    finger_symbol = 3'd0;
    clear_capture = 0;
    repeat (5) @(posedge clk);
    reset = 0;
    repeat (3) @(posedge clk);

    // Test 1: reset limpia window
    if (window !== 9'b0) begin
        $display("FAIL [Test 1]: window=%b tras reset", window); errors++;
    end else $display("PASS [Test 1]: window limpia tras reset");

    // Test 2: ingresar 1, 2, 3 -> window = 001_010_011
    push_symbol(3'd1);
    push_symbol(3'd2);
    push_symbol(3'd3);
    @(posedge clk);  // deja propagar el registro
    if (window !== 9'b001_010_011) begin
        $display("FAIL [Test 2]: window=%b esperado 001_010_011", window); errors++;
    end else $display("PASS [Test 2]: 1,2,3 -> 001_010_011");

    // Test 3: cuarto símbolo 4 -> desplaza, sale el 1
    push_symbol(3'd4);
    @(posedge clk);
    if (window !== 9'b010_011_100) begin
        $display("FAIL [Test 3]: window=%b esperado 010_011_100", window); errors++;
    end else $display("PASS [Test 3]: 4 desplaza -> 010_011_100");

    // Test 4: finger_valid=0 no desplaza
    finger_valid  = 0;
    finger_symbol = 3'd5;
    wait_tick();
    @(posedge clk);
    if (window !== 9'b010_011_100) begin
        $display("FAIL [Test 4]: window cambio con valid=0: %b", window); errors++;
    end else $display("PASS [Test 4]: valid=0 no desplaza");

    // Test 5: clear_capture limpia
    clear_capture = 1;
    @(posedge clk);
    @(posedge clk);
    clear_capture = 0;
    if (window !== 9'b0) begin
        $display("FAIL [Test 5]: window=%b tras clear", window); errors++;
    end else $display("PASS [Test 5]: clear_capture limpia window");

    // Test 6: repetir mismo símbolo 3 veces (1,1,1)
    finger_valid = 1;
    push_symbol(3'd1);
    push_symbol(3'd1);
    push_symbol(3'd1);
    @(posedge clk);
    if (window !== 9'b001_001_001) begin
        $display("FAIL [Test 6]: window=%b esperado 001_001_001", window); errors++;
    end else $display("PASS [Test 6]: 1,1,1 -> 001_001_001");

    $display("=== Simulation complete. Errors: %0d ===", errors);
    $finish;
end

initial begin
    #(CLK_PERIOD * 50000);
    $display("FAIL [Timeout]");
    $finish;
end

endmodule