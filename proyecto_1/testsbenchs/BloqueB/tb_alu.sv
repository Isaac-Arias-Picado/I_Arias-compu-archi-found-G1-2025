`timescale 1ns/1ps

module tb_alu;

import config_pkg::*;

logic [2:0] op, a, b, result;

alu dut (.op(op), .a(a), .b(b), .result(result));

int tests_run;
int tests_failed;

// Referencia comportamental (solo para simulación)
function automatic logic [2:0] rot_left(input logic [2:0] x, input int k);
    logic [2:0] r;
    r = x;
    for (int i = 0; i < k; i++) r = {r[1:0], r[2]};
    return r;
endfunction

function automatic logic [2:0] rot_right(input logic [2:0] x, input int k);
    logic [2:0] r;
    r = x;
    for (int i = 0; i < k; i++) r = {r[0], r[2:1]};
    return r;
endfunction

function automatic logic [2:0] expected(input logic [2:0] o,
                                        input logic [2:0] x,
                                        input logic [2:0] y);
    logic [5:0] prod;
    prod = x * y;
    case (o)
        3'd1:    return x + y;
        3'd2:    return x - y;
        3'd3:    return prod[2:0];
        3'd4:    return rot_left(x, y % 3);
        3'd5:    return rot_right(x, y % 3);
        default: return 3'd0;
    endcase
endfunction

task automatic report(input string name, input int errors);
    tests_run++;
    if (errors == 0) begin
        $display("[PASS] %s", name);
    end else begin
        tests_failed++;
        $display("[FAIL] %s (%0d errores)", name, errors);
    end
endtask

// Recorre las 64 combinaciones (A, B) para una operación
task automatic sweep(input logic [2:0] o, input string name);
    int errors;
    errors = 0;
    for (int x = 0; x < 8; x++) begin
        for (int y = 0; y < 8; y++) begin
            op = o;
            a  = x[2:0];
            b  = y[2:0];
            #1;
            if (result !== expected(o, a, b)) begin
                errors++;
                $display("  op=%0d a=%0d b=%0d -> %0d (esperado %0d)",
                         op, a, b, result, expected(o, a, b));
            end
        end
    end
    report(name, errors);
endtask

// Valor puntual
task automatic spot(input string name, input logic [2:0] o,
                    input logic [2:0] x, input logic [2:0] y,
                    input logic [2:0] exp);
    int errors;
    op = o; a = x; b = y;
    #1;
    errors = (result !== exp) ? 1 : 0;
    if (errors != 0) $display("  op=%0d a=%0d b=%0d -> %0d (esperado %0d)", o, x, y, result, exp);
    report(name, errors);
endtask

initial begin
    tests_run    = 0;
    tests_failed = 0;

    sweep(3'd1, "Suma circular mod 8 (op 1)");
    sweep(3'd2, "Resta circular mod 8 (op 2)");
    sweep(3'd3, "Multiplicacion mod 8 (op 3)");
    sweep(3'd4, "Rotacion izquierda, giros = B mod 3 (op 4)");
    sweep(3'd5, "Rotacion derecha, giros = B mod 3 (op 5)");

    sweep(3'd0, "Codigo 0 no es operacion: resultado 0");
    sweep(3'd6, "Codigo 6 no es operacion: resultado 0");
    sweep(3'd7, "Codigo 7 no es operacion: resultado 0");

    spot("Suma 5+4 = 1 (circular)",        3'd1, 3'd5, 3'd4, 3'd1);
    spot("Resta 1-3 = 6 (circular)",       3'd2, 3'd1, 3'd3, 3'd6);
    spot("Mult 3*3 = 1 (mod 8)",           3'd3, 3'd3, 3'd3, 3'd1);
    spot("Rot izq 5 (101) con B=4 -> 011", 3'd4, 3'd5, 3'd4, 3'd3);
    spot("Rot der 1 (001) con B=2 -> 010", 3'd5, 3'd1, 3'd2, 3'd2);

    $display("");
    $display("===== tb_alu: %0d tests, %0d fallos =====", tests_run, tests_failed);
    if (tests_failed == 0) $display("RESULTADO: PASS");
    else                   $display("RESULTADO: FAIL");
    $finish;
end

endmodule
