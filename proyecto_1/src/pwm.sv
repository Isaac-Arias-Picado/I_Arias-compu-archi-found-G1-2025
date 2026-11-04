// PWM estructural: duty = speed/7; valores por defecto: 50 MHz -> 1 kHz.
// En top, conectar los parametros a las constantes de config_pkg.
module pwm #(
    parameter int CLK_FREQ_HZ = 50_000_000,
    parameter int PWM_FREQ_HZ = 1000
) (
    input  logic       clk,
    input  logic       reset,
    input  logic [2:0] speed,
    output logic       pwm_out
);

localparam int PERIOD_CYCLES = CLK_FREQ_HZ / PWM_FREQ_HZ;
// Incluye PERIOD_CYCLES para representar el umbral del 100 %.
localparam int COUNT_BITS = $clog2(PERIOD_CYCLES + 1);

logic [COUNT_BITS-1:0] counter, counter_next;
logic [COUNT_BITS-1:0] threshold;
logic [2:0] active_speed, speed_next;
logic running;
logic period_end, count_en, load_speed, hold_speed;

assign period_end = (counter == COUNT_BITS'(PERIOD_CYCLES - 1));
assign count_en = running & ~period_end & ~reset;
assign counter_next = {COUNT_BITS{count_en}} & (counter + 1'b1);

// Primer periodo: cargar speed y comenzar en counter=0.
// Periodos posteriores: cargar solo al terminar el anterior.
assign load_speed = ~reset & (~running | period_end);
assign hold_speed = ~reset & ~load_speed;
assign speed_next = ({3{load_speed}} & speed) |
                    ({3{hold_speed}} & active_speed);

always_ff @(posedge clk) begin
    counter      <= counter_next;
    active_speed <= speed_next;
    running      <= ~reset;
end

// LUT mediante decodificacion y mascaras. Las divisiones son constantes
// calculadas al elaborar el diseno, no divisores de hardware.
// Redondeo al entero mas cercano: (PERIOD_CYCLES*s + 3)/7.
assign threshold =
    ({COUNT_BITS{active_speed == 3'd1}} & COUNT_BITS'((PERIOD_CYCLES * 1 + 3) / 7)) |
    ({COUNT_BITS{active_speed == 3'd2}} & COUNT_BITS'((PERIOD_CYCLES * 2 + 3) / 7)) |
    ({COUNT_BITS{active_speed == 3'd3}} & COUNT_BITS'((PERIOD_CYCLES * 3 + 3) / 7)) |
    ({COUNT_BITS{active_speed == 3'd4}} & COUNT_BITS'((PERIOD_CYCLES * 4 + 3) / 7)) |
    ({COUNT_BITS{active_speed == 3'd5}} & COUNT_BITS'((PERIOD_CYCLES * 5 + 3) / 7)) |
    ({COUNT_BITS{active_speed == 3'd6}} & COUNT_BITS'((PERIOD_CYCLES * 6 + 3) / 7)) |
    ({COUNT_BITS{active_speed == 3'd7}} & COUNT_BITS'(PERIOD_CYCLES));

// Reset apaga la salida inmediatamente; los registros se reinician al flanco.
assign pwm_out = running & ~reset & (counter < threshold);

endmodule
