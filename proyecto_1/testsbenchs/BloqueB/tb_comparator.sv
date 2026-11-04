`timescale 1ns/1ps

module tb_comparator;

import config_pkg::*;

logic [8:0] window, pass1, pass2;
logic       valid1, valid2;
logic       match1, match2;

comparator dut (
    .window(window), .pass1(pass1), .pass2(pass2),
    .valid1(valid1), .valid2(valid2),
    .match1(match1), .match2(match2)
);

localparam logic [8:0] PW_A = 9'b001_010_011;   // 1 2 3
localparam logic [8:0] PW_B = 9'b100_101_001;   // 4 5 1

int tests_run;
int tests_failed;

task automatic report(input string name, input logic ok);
    tests_run++;
    if (ok) begin
        $display("[PASS] %s", name);
    end else begin
        tests_failed++;
        $display("[FAIL] %s  (m1=%b m2=%b)", name, match1, match2);
    end
endtask

task automatic apply(input logic [8:0] w, input logic [8:0] p1, input logic [8:0] p2,
                     input logic v1, input logic v2);
    window = w; pass1 = p1; pass2 = p2; valid1 = v1; valid2 = v2;
    #1;
endtask

initial begin
    tests_run = 0; tests_failed = 0;

    apply(PW_A, PW_A, PW_B, 1'b1, 1'b1);
    report("Coincide solo con el espacio 1", (match1 == 1'b1) && (match2 == 1'b0));

    apply(PW_B, PW_A, PW_B, 1'b1, 1'b1);
    report("Coincide solo con el espacio 2", (match1 == 1'b0) && (match2 == 1'b1));

    apply(9'b010_010_010, PW_A, PW_B, 1'b1, 1'b1);
    report("No coincide con ninguno", (match1 == 1'b0) && (match2 == 1'b0));

    apply(PW_A, PW_A, PW_A, 1'b1, 1'b1);
    report("Mismo valor en ambos espacios: match1 y match2", (match1 == 1'b1) && (match2 == 1'b1));

    apply(PW_A, PW_A, PW_B, 1'b0, 1'b1);
    report("Espacio 1 vacio no coincide aunque el dato sea igual", (match1 == 1'b0) && (match2 == 1'b0));

    apply(PW_B, PW_A, PW_B, 1'b1, 1'b0);
    report("Espacio 2 vacio no coincide aunque el dato sea igual", (match1 == 1'b0) && (match2 == 1'b0));

    apply(9'd0, 9'd0, 9'd0, 1'b0, 1'b0);
    report("Ventana vacia contra espacios vacios no coincide", (match1 == 1'b0) && (match2 == 1'b0));

    apply(PW_A ^ 9'b000_000_001, PW_A, PW_B, 1'b1, 1'b1);
    report("Difiere el digito mas nuevo", (match1 == 1'b0));
    apply(PW_A ^ 9'b000_001_000, PW_A, PW_B, 1'b1, 1'b1);
    report("Difiere el digito del medio", (match1 == 1'b0));
    apply(PW_A ^ 9'b001_000_000, PW_A, PW_B, 1'b1, 1'b1);
    report("Difiere el digito mas viejo", (match1 == 1'b0));

    // Barrido completo de la ventana contra PW_A (espacio 1) y PW_B (espacio 2)
    begin
        int errors;
        errors = 0;
        for (int w = 0; w < 512; w++) begin
            apply(w[8:0], PW_A, PW_B, 1'b1, 1'b1);
            if (match1 !== (w[8:0] == PW_A)) errors++;
            if (match2 !== (w[8:0] == PW_B)) errors++;
        end
        report("Barrido de las 512 ventanas", (errors == 0));
    end

    $display("");
    $display("===== tb_comparator: %0d tests, %0d fallos =====", tests_run, tests_failed);
    if (tests_failed == 0) $display("RESULTADO: PASS");
    else                   $display("RESULTADO: FAIL");
    $finish;
end

endmodule
