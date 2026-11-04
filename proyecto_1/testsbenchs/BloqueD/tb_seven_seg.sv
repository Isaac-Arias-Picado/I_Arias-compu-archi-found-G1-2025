`timescale 1ns/1ps

module tb_seven_seg;
logic [4:0] char_code;
logic [6:0] segments;
logic [6:0] expected;
int errors = 0;

seven_seg dut (.char_code(char_code), .segments(segments));

// Referencia independiente: patrones activos bajos en orden gfedcba.
function automatic logic [6:0] reference_pattern(input int code);
    case (code)
         0: reference_pattern = 7'b1000000;
         1: reference_pattern = 7'b1111001;
         2: reference_pattern = 7'b0100100;
         3: reference_pattern = 7'b0110000;
         4: reference_pattern = 7'b0011001;
         5: reference_pattern = 7'b0010010;
         6: reference_pattern = 7'b0000010;
         7: reference_pattern = 7'b1111000;
         8: reference_pattern = 7'b0000000;
         9: reference_pattern = 7'b0010000;
        10: reference_pattern = 7'b0001000; // A
        11: reference_pattern = 7'b0000011; // b
        12: reference_pattern = 7'b1000110; // C
        13: reference_pattern = 7'b0100001; // d
        14: reference_pattern = 7'b0000110; // E
        15: reference_pattern = 7'b0001110; // F
        16: reference_pattern = 7'b0100011; // o
        17: reference_pattern = 7'b0100111; // c
        18: reference_pattern = 7'b0101011; // n
        19: reference_pattern = 7'b0000111; // t
        default: reference_pattern = 7'b1111111;
    endcase
endfunction

initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_seven_seg);
    // Dos recorridos verifican las 32 entradas y cambios en ambos sentidos.
    for (int pass = 0; pass < 2; pass++) begin
        for (int i = 0; i < 32; i++) begin
            if (pass == 0) char_code = 5'(i);
            else           char_code = 5'(31 - i);
            expected = reference_pattern(int'(char_code));
            #10;
            if (segments !== expected) begin
                $error("FAIL code=%h segments=%b expected=%b", char_code, segments, expected);
                errors++;
            end else $display("PASS code=%h segments=%b", char_code, segments);
        end
    end
    if (errors != 0) $fatal(1, "Resultado: %0d errores", errors);
    $display("PASS: 64 comprobaciones, 0 errores");
    $finish;
end
endmodule
