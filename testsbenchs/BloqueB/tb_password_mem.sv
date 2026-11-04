`timescale 1ns/1ps

module tb_password_mem;

import config_pkg::*;

logic       clk, reset;
logic [8:0] window;
logic       wr1, wr2, del1, del2, clear_all;
logic [8:0] pass1, pass2;
logic       valid1, valid2;

password_mem dut (
    .clk(clk), .reset(reset), .window(window),
    .wr1(wr1), .wr2(wr2), .del1(del1), .del2(del2), .clear_all(clear_all),
    .pass1(pass1), .pass2(pass2), .valid1(valid1), .valid2(valid2)
);

localparam logic [8:0] PW_A = 9'b001_010_011;   // 1 2 3
localparam logic [8:0] PW_B = 9'b100_101_001;   // 4 5 1
localparam logic [8:0] PW_C = 9'b010_010_010;   // 2 2 2

int tests_run;
int tests_failed;

initial clk = 1'b0;
always #10 clk = ~clk;

task automatic report(input string name, input logic ok);
    tests_run++;
    if (ok) begin
        $display("[PASS] %s", name);
    end else begin
        tests_failed++;
        $display("[FAIL] %s  (p1=%b v1=%b p2=%b v2=%b)", name, pass1, valid1, pass2, valid2);
    end
endtask

// Aplica las entradas durante un flanco y las suelta
task automatic step(input logic [8:0] w,
                    input logic r, input logic w1, input logic w2,
                    input logic d1, input logic d2, input logic ca);
    window = w; reset = r; wr1 = w1; wr2 = w2;
    del1 = d1; del2 = d2; clear_all = ca;
    @(posedge clk); #1;
    reset = 1'b0; wr1 = 1'b0; wr2 = 1'b0;
    del1 = 1'b0; del2 = 1'b0; clear_all = 1'b0;
endtask

initial begin
    tests_run = 0; tests_failed = 0;
    window = 9'd0; reset = 1'b0; wr1 = 1'b0; wr2 = 1'b0;
    del1 = 1'b0; del2 = 1'b0; clear_all = 1'b0;

    // Reset inicial
    step(PW_A, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    report("Reset: ambos espacios vacios", (valid1 == 1'b0) && (valid2 == 1'b0) &&
                                           (pass1 == 9'd0) && (pass2 == 9'd0));

    // Escritura espacio 1
    step(PW_A, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
    report("wr1 guarda la ventana y activa valid1", (pass1 == PW_A) && (valid1 == 1'b1));
    report("wr1 no toca el espacio 2", (valid2 == 1'b0) && (pass2 == 9'd0));

    // Mantener
    step(PW_C, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    report("Sin pulsos la memoria mantiene su valor", (pass1 == PW_A) && (valid1 == 1'b1) &&
                                                      (valid2 == 1'b0));

    // Escritura espacio 2
    step(PW_B, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0);
    report("wr2 guarda la ventana y activa valid2", (pass2 == PW_B) && (valid2 == 1'b1));
    report("wr2 no toca el espacio 1", (pass1 == PW_A) && (valid1 == 1'b1));

    // Sobrescritura
    step(PW_C, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
    report("wr1 sobrescribe la contrasena anterior", (pass1 == PW_C) && (valid1 == 1'b1) &&
                                                     (pass2 == PW_B) && (valid2 == 1'b1));

    // Borrado individual
    step(PW_A, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0);
    report("del1 vacia solo el espacio 1", (valid1 == 1'b0) && (pass1 == 9'd0) &&
                                           (valid2 == 1'b1) && (pass2 == PW_B));
    step(PW_A, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0);
    report("del2 vacia solo el espacio 2", (valid2 == 1'b0) && (pass2 == 9'd0));

    // clear_all
    step(PW_A, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0);
    report("wr1 y wr2 simultaneos guardan ambos", (valid1 == 1'b1) && (valid2 == 1'b1) &&
                                                  (pass1 == PW_A) && (pass2 == PW_A));
    step(PW_B, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1);
    report("clear_all vacia ambos espacios", (valid1 == 1'b0) && (valid2 == 1'b0) &&
                                             (pass1 == 9'd0) && (pass2 == 9'd0));

    // reset con datos
    step(PW_A, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0);
    step(PW_B, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    report("reset vacia ambos espacios", (valid1 == 1'b0) && (valid2 == 1'b0) &&
                                         (pass1 == 9'd0) && (pass2 == 9'd0));

    // Prioridades: borrado > escritura
    step(PW_A, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0);
    report("wr1 y del1 a la vez: gana el borrado", (valid1 == 1'b0) && (pass1 == 9'd0));
    step(PW_A, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b1);
    report("wr y clear_all a la vez: gana clear_all", (valid1 == 1'b0) && (valid2 == 1'b0));
    step(PW_A, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0);
    report("wr y reset a la vez: gana reset", (valid1 == 1'b0) && (valid2 == 1'b0));

    $display("");
    $display("===== tb_password_mem: %0d tests, %0d fallos =====", tests_run, tests_failed);
    if (tests_failed == 0) $display("RESULTADO: PASS");
    else                   $display("RESULTADO: FAIL");
    $finish;
end

endmodule
