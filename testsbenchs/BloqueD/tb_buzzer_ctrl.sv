`timescale 1ns/1ps

module tb_buzzer_ctrl;
// Tiempos acelerados: pruebas de forma de onda y limites exactos por ciclo.
localparam int BEEP = 40;
localparam int GAP = 20;
localparam int INVALID = 100;
logic clk = 0;
logic reset = 1;
logic [2:0] event_code = 0;
logic event_start = 0;
logic buzzer_out;
logic expected;
int errors = 0;
int checks = 0;
int cycle = 0;
int saved_kind = 0;
int begin_cycle = 0;
int end_cycle = 0;
int tone_origin = 0;
int previous_cont = 0;
bit previous_enable = 0;
int cont, half_cycles, age;
bit enable_sound;

buzzer_ctrl #(
    .BUZZER_TEST_HALF(5), .BUZZER_REG_OK_HALF(5),
    .BUZZER_VALID_HALF(5), .BUZZER_INVALID_HALF(10),
    .BUZZER_OPENING_HALF(3), .BUZZER_CLOSING_HALF(4),
    .BUZZER_BEEP_CYCLES(BEEP), .BUZZER_INVALID_CYCLES(INVALID),
    .BUZZER_GAP_CYCLES(GAP)
) dut (.*);
always #10 clk = ~clk;

// Referencia temporal: calcula intervalos a partir del ciclo de inicio,
// sin consultar contadores ni registros internos del diseno.
always @(posedge clk) begin
    cycle++;
    cont = 0;
    if (event_code == 1 || event_code == 5 || event_code == 6)
        cont = int'(event_code);
    if (reset || cont != 0 || event_start) begin
        saved_kind = 0;
        end_cycle = cycle;
    end
    if (!reset && cont == 0 && event_start) begin
        begin_cycle = cycle;
        case (event_code)
            2: begin saved_kind = 2; end_cycle = cycle + BEEP; end
            3: begin saved_kind = 3; end_cycle = cycle + 2*BEEP + GAP; end
            4: begin saved_kind = 4; end_cycle = cycle + INVALID; end
            default: saved_kind = 0;
        endcase
    end
    age = cycle - begin_cycle;
    enable_sound = 0;
    half_cycles = 1;
    if (!reset) begin
        if (cont != 0) begin
            enable_sound = 1;
            case (cont)
                1: half_cycles = 5;
                5: half_cycles = 3;
                6: half_cycles = 4;
            endcase
        end else if (cycle < end_cycle) begin
            case (saved_kind)
                2: begin enable_sound = 1; half_cycles = 5; end
                3: begin
                    enable_sound = (age < BEEP || age >= BEEP + GAP);
                    half_cycles = 5;
                end
                4: begin enable_sound = 1; half_cycles = 10; end
            endcase
        end
    end
    if (reset || event_start || cont != previous_cont || !previous_enable || !enable_sound)
        tone_origin = cycle;
    expected = enable_sound && (((cycle - tone_origin) % (2*half_cycles)) < half_cycles);
    previous_enable = enable_sound;
    previous_cont = cont;
    #1;
    checks++;
    if (buzzer_out !== expected) begin
        if (errors < 10)
            $error("FAIL cycle=%0d event=%0d start=%b out=%b expected=%b",
                   cycle, event_code, event_start, buzzer_out, expected);
        errors++;
    end
end

task automatic wait_cycles(input int n);
    repeat (n) begin @(posedge clk); #2; end
endtask

task automatic send_event(input logic [2:0] code);
    @(negedge clk);
    event_code = code;
    event_start = 1;
    wait_cycles(1);
    @(negedge clk);
    event_start = 0;
endtask

initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, clk, reset, event_code, event_start, buzzer_out, expected);
    wait_cycles(3);
    @(negedge clk); reset = 0;
    wait_cycles(10);

    // Cada patron termina aunque el codigo permanezca sin cambiar.
    send_event(2); wait_cycles(BEEP + 15);
    send_event(3); wait_cycles(2*BEEP + GAP + 15);
    send_event(4); wait_cycles(INVALID + 15);
    $display("INFO: REG_OK, VALID e INVALID comprobados");

    // Un codigo finito por si solo no inicia sonido; un nuevo pulso si.
    @(negedge clk); event_code = 2;
    wait_cycles(15);
    send_event(2); wait_cycles(12);
    send_event(2); wait_cycles(BEEP + 10);
    // El codigo puede volver a NONE mientras termina el aviso almacenado.
    send_event(3);
    @(negedge clk); event_code = 0;
    wait_cycles(2*BEEP + GAP + 10);
    // Un aviso nuevo sustituye al anterior, sin cola.
    send_event(4); wait_cycles(12);
    send_event(3); wait_cycles(2*BEEP + GAP + 10);

    // Continuos sin pulso: TEST -> OPENING -> CLOSING -> NONE.
    @(negedge clk); event_code = 1;
    wait_cycles(70);
    @(negedge clk); event_code = 5;
    wait_cycles(70);
    @(negedge clk); event_code = 6;
    wait_cycles(70);
    @(negedge clk); event_code = 0;
    wait_cycles(20);
    // Un continuo interrumpe y cancela el patron finito.
    send_event(4); wait_cycles(12);
    @(negedge clk); event_code = 5;
    wait_cycles(30);
    @(negedge clk); event_code = 0;
    wait_cycles(INVALID + 10);
    // Codigo reservado + start cancela; sin start no crea sonido.
    send_event(3); wait_cycles(12);
    send_event(7); wait_cycles(20);
    send_event(0); wait_cycles(20);
    $display("INFO: repeticion, sustitucion, continuos y cancelacion comprobados");

    send_event(4); wait_cycles(12);
    @(negedge clk); reset = 1;
    #1;
    if (buzzer_out !== 1'b0) begin
        $error("FAIL reset no apaga inmediatamente"); errors++;
    end
    wait_cycles(3);
    @(negedge clk); reset = 0; event_code = 0;
    wait_cycles(20);
    send_event(2); wait_cycles(BEEP + 10);
    if (errors != 0) $fatal(1, "BUZZER: %0d errores", errors);
    $display("PASS BUZZER_CTRL: %0d comprobaciones, 0 errores", checks);
    $finish;
end

initial begin
    #100_000;
    $fatal(1, "Timeout de simulacion");
end
endmodule
