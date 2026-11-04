`timescale 1ns/1ps

module tb_clk_enables;

import config_pkg::*;

localparam real CLK_PERIOD = 20.0;

logic clk;
logic reset;
logic tick_capture;
logic tick_debounce;

clk_enables dut (
    .clk(clk),
    .reset(reset),
    .tick_capture(tick_capture),
    .tick_debounce(tick_debounce)
);

initial clk = 0;
always #(CLK_PERIOD/2.0) clk = ~clk;

int errors = 0;
int cyc = 0;

initial begin
    reset = 1;
    repeat (5) @(posedge clk);

    if (tick_capture | tick_debounce) begin
        $display("FAIL [Test 1]: ticks activos durante reset");
        errors++;
    end else begin
        $display("PASS [Test 1]: ticks inactivos durante reset");
    end

    reset = 0;
    while (!tick_debounce) @(posedge clk);

    if (dut.shared_cnt !== (DEBOUNCE_CYCLES - 1)) begin
        $display("FAIL [Test 2]: debounce tick en cnt=%0d, esperado %0d",
                 dut.shared_cnt, DEBOUNCE_CYCLES - 1);
        errors++;
    end else begin
        $display("PASS [Test 2]: primer debounce tick en cnt=max");
    end

    cyc = 0;
    do begin
        @(posedge clk);
        cyc++;
    end while (!tick_debounce);

    if (cyc != DEBOUNCE_CYCLES) begin
        $display("FAIL [Test 3]: intervalo debounce = %0d, esperado %0d",
                 cyc, DEBOUNCE_CYCLES);
        errors++;
    end else begin
        $display("PASS [Test 3]: intervalo debounce correcto (%0d ciclos)", cyc);
    end

    //Para no simular 100 millones de ciclos, el contador de captura se
    //adelanta a 20 ciclos del final. El pulso se sigue comparando con el
    //valor real de CAPTURE_CYCLES.
    @(negedge clk);
    force dut.cap_cnt = CAPTURE_CYCLES - 20;
    @(negedge clk);
    release dut.cap_cnt;
    $display("INFO: contador de captura adelantado a %0d", CAPTURE_CYCLES - 20);
    while (!tick_capture) @(posedge clk);

    if (dut.cap_cnt !== (CAPTURE_CYCLES - 1)) begin
        $display("FAIL [Test 4]: capture tick en cnt=%0d, esperado %0d",
                 dut.cap_cnt, CAPTURE_CYCLES - 1);
        errors++;
    end else begin
        $display("PASS [Test 4]: primer capture tick en cnt=max");
    end

    $display(" Simulation complete. Errors: %0d ", errors);
    $finish;
end

initial begin
    #(20.0 * (CAPTURE_CYCLES + 10000));
    $display("FAIL [Timeout]: simulación excedió tiempo esperado");
    $finish;
end

endmodule