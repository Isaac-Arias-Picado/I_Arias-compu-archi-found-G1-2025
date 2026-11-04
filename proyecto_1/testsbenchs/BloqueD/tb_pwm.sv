`timescale 1ns/1ps

module tb_pwm;
localparam int CLK_HZ = 50_000_000;
localparam int PWM_HZ = 1000;
localparam int PERIOD = CLK_HZ / PWM_HZ;
localparam real CLK_NS = 20.0;

logic clk = 0;
logic reset = 1;
logic [2:0] speed = 0;
logic pwm_out;
int errors = 0;
int checks = 0;
int phase = 0;
int latched_speed = 0;
int high_cycles = 0;
int complete_periods = 0;
bit started = 0;
logic expected;

pwm #(.CLK_FREQ_HZ(CLK_HZ), .PWM_FREQ_HZ(PWM_HZ)) dut (
    .clk(clk), .reset(reset), .speed(speed), .pwm_out(pwm_out)
);
always #(CLK_NS/2.0) clk = ~clk;

// Modelo independiente: tiempo dentro del periodo y duty ideal redondeado.
// No consulta registros ni senales internas del DUT.
always @(posedge clk) begin
    if (reset) begin
        phase = 0;
        started = 0;
        latched_speed = 0;
        high_cycles = 0;
        expected = 0;
    end else begin
        if (!started) begin
            started = 1;
            phase = 0;
            latched_speed = int'(speed);
        end else if (phase == PERIOD - 1) begin
            phase = 0;
            latched_speed = int'(speed);
        end else phase++;
        expected = (phase < $rtoi(PERIOD * (latched_speed / 7.0) + 0.5));
    end
    #1;
    checks++;
    if (pwm_out !== expected) begin
        if (errors < 10)
            $error("FAIL t=%0t phase=%0d speed=%0d out=%b expected=%b",
                   $time, phase, latched_speed, pwm_out, expected);
        errors++;
    end
    if (!reset && started) begin
        if (pwm_out === 1'b1) high_cycles++;
        if (phase == PERIOD - 1) begin
            if (high_cycles != $rtoi(PERIOD * (latched_speed / 7.0) + 0.5)) begin
                $error("FAIL duty: speed=%0d high_cycles=%0d", latched_speed, high_cycles);
                errors++;
            end
            complete_periods++;
            $display("Periodo %0d: speed=%0d, encendido=%0d/%0d ciclos",
                     complete_periods, latched_speed, high_cycles, PERIOD);
            high_cycles = 0;
        end
    end
end

task automatic wait_cycles(input int n);
    repeat (n) begin
        @(posedge clk);
        #2;
    end
endtask

initial begin
    $dumpfile("dump.vcd");
    // Limitar el archivo a las senales utiles para observar el comportamiento.
    $dumpvars(0, clk, reset, speed, pwm_out, expected);
    wait_cycles(3);
    // Dos periodos completos para cada velocidad, con tiempos reales.
    for (int s = 0; s < 8; s++) begin
        @(negedge clk);
        reset = 1;
        speed = 3'(s);
        wait_cycles(2);
        @(negedge clk);
        reset = 0;
        wait_cycles(2 * PERIOD);
    end

    // Pasar 7 -> 0 -> 4 -> 1 sin reset y a mitad de periodos.
    // El modelo exige que el cambio espere al limite del periodo.
    @(negedge clk);
    speed = 0;
    wait_cycles(PERIOD + 123);
    @(negedge clk);
    speed = 4;
    wait_cycles(2 * PERIOD);
    @(negedge clk);
    speed = 1;
    wait_cycles(2 * PERIOD);

    // Reset durante un pulso alto, fuera del flanco de reloj.
    @(negedge clk);
    reset = 1;
    #1;
    if (pwm_out !== 1'b0) begin
        $error("FAIL: reset no apaga inmediatamente la salida");
        errors++;
    end
    wait_cycles(2);
    @(negedge clk);
    speed = 7;
    reset = 0;
    wait_cycles(PERIOD);

    if (complete_periods < 22) $fatal(1, "No se completaron los periodos previstos");
    if (errors != 0) $fatal(1, "Resultado: %0d errores", errors);
    $display("PASS PWM: %0d comprobaciones, %0d periodos, 0 errores", checks, complete_periods);
    $finish;
end

initial begin
    #30_000_000;
    $fatal(1, "Timeout de simulacion");
end
endmodule
