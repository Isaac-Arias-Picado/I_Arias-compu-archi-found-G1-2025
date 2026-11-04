`timescale 1ns/1ps

module tb_motor_ctrl;
logic reset;
logic [1:0] motor_dir;
logic pwm_in;
logic [1:0] motor_lines;
logic [1:0] expected;
int errors = 0;
int checks = 0;

motor_ctrl dut (
    .reset(reset), .motor_dir(motor_dir),
    .pwm_in(pwm_in), .motor_lines(motor_lines)
);

initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_motor_ctrl);
    // Dos recorridos de todas las combinaciones, en sentidos opuestos.
    for (int pass = 0; pass < 2; pass++) begin
        for (int i = 0; i < 16; i++) begin
            if (pass == 0) {reset, motor_dir, pwm_in} = 4'(i);
            else           {reset, motor_dir, pwm_in} = 4'(15-i);
            // Tabla de referencia: solo dos combinaciones activan el motor.
            case ({reset, motor_dir, pwm_in})
                4'b0101: expected = 2'b10;
                4'b0011: expected = 2'b01;
                default: expected = 2'b00;
            endcase
            #10;
            checks++;
            if (motor_lines !== expected) begin
                $error("FAIL reset=%b dir=%b pwm=%b out=%b expected=%b",
                       reset, motor_dir, pwm_in, motor_lines, expected);
                errors++;
            end
            if (motor_lines === 2'b11) begin
                $error("FAIL: ambas lineas activas");
                errors++;
            end
        end
    end
    if (errors != 0) $fatal(1, "Motor: %0d errores", errors);
    $display("PASS MOTOR_CTRL: %0d combinaciones comprobadas, 0 errores", checks);
    $finish;
end
endmodule
