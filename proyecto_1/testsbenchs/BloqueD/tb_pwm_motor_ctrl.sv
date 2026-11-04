`timescale 1ns/1ps

module tb_pwm_motor_ctrl;
localparam int PERIOD = 50_000;
logic clk = 0;
logic reset = 1;
logic [2:0] speed = 0;
logic [1:0] motor_dir = 0;
logic pwm_out;
logic [1:0] motor_lines;
logic [1:0] expected;
int errors = 0;
int checks = 0;
int high_open, high_close;

always #10 clk = ~clk;
pwm pwm_dut (
    .clk(clk), .reset(reset), .speed(speed), .pwm_out(pwm_out)
);
motor_ctrl motor_dut (
    .reset(reset), .motor_dir(motor_dir),
    .pwm_in(pwm_out), .motor_lines(motor_lines)
);

// Verifica la ruta combinacional cada ciclo, despues de actualizar registros.
always @(posedge clk) begin
    #1;
    expected = 2'b00;
    if (!reset) begin
        case (motor_dir)
            2'b10: expected = {pwm_out, 1'b0};
            2'b01: expected = {1'b0, pwm_out};
            default: expected = 2'b00;
        endcase
    end
    checks++;
    if (motor_lines !== expected || motor_lines === 2'b11) begin
        if (errors < 10) $error("FAIL dir=%b pwm=%b out=%b expected=%b",
                               motor_dir, pwm_out, motor_lines, expected);
        errors++;
    end
end

task automatic wait_cycles(input int n);
    repeat (n) begin
        @(posedge clk);
        #2;
    end
endtask

task automatic check_period(input logic [1:0] direction, input int s);
    int expected_high;
    // Inicio independiente para observar un periodo completo por caso.
    @(negedge clk);
    reset = 1;
    motor_dir = direction;
    speed = 3'(s);
    wait_cycles(2);
    @(negedge clk);
    reset = 0;
    high_open = 0;
    high_close = 0;
    repeat (PERIOD) begin
        wait_cycles(1);
        if (motor_lines[1] === 1'b1) high_open++;
        if (motor_lines[0] === 1'b1) high_close++;
    end
    expected_high = $rtoi(PERIOD * (s / 7.0) + 0.5);
    if (direction == 2'b10) begin
        if (high_open != expected_high || high_close != 0) errors++;
    end else if (direction == 2'b01) begin
        if (high_close != expected_high || high_open != 0) errors++;
    end else if (high_open != 0 || high_close != 0) errors++;
    $display("Periodo dir=%b speed=%0d: abrir=%0d cerrar=%0d / %0d ciclos",
             direction, s, high_open, high_close, PERIOD);
endtask

initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, clk, reset, speed, motor_dir, pwm_out, motor_lines, expected);
    wait_cycles(3);
    for (int s = 0; s < 8; s++) begin
        check_period(2'b10, s);
        check_period(2'b01, s);
    end
    check_period(2'b00, 7);
    check_period(2'b11, 7);

    // Cambios sin reiniciar el PWM, pasando por detener antes de invertir.
    @(negedge clk); motor_dir = 2'b10;
    wait_cycles(5);
    @(negedge clk); motor_dir = 2'b00;
    wait_cycles(5);
    @(negedge clk); motor_dir = 2'b01;
    wait_cycles(5);
    @(negedge clk); reset = 1;
    #1;
    if (motor_lines !== 2'b00) begin
        $error("FAIL reset entre flancos");
        errors++;
    end
    wait_cycles(2);
    if (errors != 0) $fatal(1, "Integracion PWM/motor: %0d errores", errors);
    $display("PASS PWM + MOTOR_CTRL: 18 periodos, %0d comprobaciones, 0 errores", checks);
    $finish;
end

initial begin
    #20_000_000;
    $fatal(1, "Timeout de simulacion");
end
endmodule
