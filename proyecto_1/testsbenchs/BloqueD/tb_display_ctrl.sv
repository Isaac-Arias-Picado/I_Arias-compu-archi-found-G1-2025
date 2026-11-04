`timescale 1ns/1ps

module tb_display_ctrl;
logic reset = 0;
logic [2:0] state = 0;
logic [2:0] mode = 0;
logic [2:0] speed = 0;
logic [8:0] window = 0;
logic door_open_flag = 0;
logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
logic [41:0] expected;
int errors = 0;
int checks = 0;

display_ctrl dut (.*);

// Tabla independiente de patrones finales; no instancia otro decodificador.
function automatic logic [6:0] pattern(input int code);
    case (code)
        0: pattern = 7'b1000000;
        1: pattern = 7'b1111001;
        2: pattern = 7'b0100100;
        3: pattern = 7'b0110000;
        4: pattern = 7'b0011001;
        5: pattern = 7'b0010010;
        6: pattern = 7'b0000010;
        7: pattern = 7'b1111000;
        8: pattern = 7'b0000000;
        9: pattern = 7'b0010000;
        10: pattern = 7'b0001000; // A
        11: pattern = 7'b0000011; // b
        12: pattern = 7'b1000110; // C
        13: pattern = 7'b0100001; // d
        14: pattern = 7'b0000110; // E
        15: pattern = 7'b0001110; // F
        16: pattern = 7'b0100011; // o
        17: pattern = 7'b0100111; // c
        18: pattern = 7'b0101011; // n
        19: pattern = 7'b0000111; // t
        default: pattern = 7'b1111111;
    endcase
endfunction

// Velocidad normalizada esperada en HEX5: round(15*speed/7).
function automatic int speed_hex(input logic [2:0] s);
    case (s)
        0: speed_hex = 0;
        1: speed_hex = 2;
        2: speed_hex = 4;
        3: speed_hex = 6;
        4: speed_hex = 9;
        5: speed_hex = 11;
        6: speed_hex = 13;
        default: speed_hex = 15;
    endcase
endfunction

task automatic check_display;
    int state_code, mode_code;
    case (state)
        0: state_code = 14;
        1: state_code = 12;
        2: state_code = 16;
        3: state_code = 10;
        4: state_code = 17;
        // ADMIN, TEST y VALID muestran la posicion recordada de la puerta
        default: begin
            if (door_open_flag) state_code = 10;
            else state_code = 12;
        end
    endcase
    if (state == 6) mode_code = 19;
    else if (mode == 0) mode_code = 18;
    else mode_code = int'(mode);
    // HEX3 = digito mas viejo (window[8:6]), HEX1 = mas nuevo (window[2:0])
    expected = {pattern(speed_hex(speed)), pattern(mode_code),
                pattern(int'(window[8:6])), pattern(int'(window[5:3])),
                pattern(int'(window[2:0])), pattern(state_code)};
    if (reset) expected = '1;
    #10;
    checks++;
    if ({HEX5,HEX4,HEX3,HEX2,HEX1,HEX0} !== expected) begin
        if (errors < 10)
            $error("FAIL state=%0d mode=%0d speed=%0d window=%b flag=%b reset=%b actual=%h expected=%h",
                state, mode, speed, window, door_open_flag, reset,
                {HEX5,HEX4,HEX3,HEX2,HEX1,HEX0}, expected);
        errors++;
    end
endtask

initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_display_ctrl);
    window = {3'd1,3'd2,3'd3};
    // Todas las combinaciones de controles (incluidos codigos reservados).
    for (int s = 0; s < 8; s++)
        for (int m = 0; m < 8; m++)
            for (int v = 0; v < 8; v++)
                for (int f = 0; f < 2; f++) begin
                    state = 3'(s); mode = 3'(m);
                    speed = 3'(v); door_open_flag = 1'(f);
                    check_display();
                end
    $display("INFO: 1024 combinaciones de controles comprobadas");
    // Todas las ventanas: verifica la posicion de cada digito.
    state = 3; mode = 0;
    for (int w = 0; w < 512; w++) begin
        window = 9'(w);
        check_display();
    end
    $display("INFO: 512 ventanas comprobadas");
    // Reset debe dominar todos los estados y apagarlos simultaneamente.
    reset = 1;
    for (int s = 0; s < 8; s++) begin
        state = 3'(s);
        check_display();
    end
    // Liberar reset restaura las entradas actuales sin esperar reloj.
    reset = 0; state = 1; mode = 0; speed = 4;
    window = {3'd1,3'd2,3'd3};
    check_display();
    if (errors != 0) $fatal(1, "DISPLAY: %0d errores", errors);
    $display("PASS DISPLAY_CTRL: %0d escenarios, %0d salidas comprobadas, 0 errores", checks, checks*6);
    $finish;
end
endmodule
