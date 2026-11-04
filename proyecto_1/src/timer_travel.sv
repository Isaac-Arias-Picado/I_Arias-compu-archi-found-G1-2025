module timer_travel (
    input  logic       clk,
    input  logic       reset,
    input  logic       tick_ms,
    input  logic       start,
    input  logic [2:0] speed,
    output logic       wait_done,
    output logic       travel_done
);
import config_pkg::*;

//Ancho en bits del contador
localparam int W = $clog2(TRAVEL_MS_MAX + 1);

logic [W-1:0] count, count_next;
logic [W-1:0] limit;
logic clr, inc, hold, at_max;

//LUT de tiempo de viaje: decodifica speed y elige el limite con mascaras
assign limit = ({W{speed == 3'd1}} & W'(TRAVEL_MS_1)) |
               ({W{speed == 3'd2}} & W'(TRAVEL_MS_2)) |
               ({W{speed == 3'd3}} & W'(TRAVEL_MS_3)) |
               ({W{speed == 3'd4}} & W'(TRAVEL_MS_4)) |
               ({W{speed == 3'd5}} & W'(TRAVEL_MS_5)) |
               ({W{speed == 3'd6}} & W'(TRAVEL_MS_6)) |
               ({W{speed == 3'd7}} & W'(TRAVEL_MS_7));

//El contador se detiene en el viaje mas largo para no desbordarse
assign at_max = (count >= W'(TRAVEL_MS_MAX));

assign clr = reset | start;
assign inc = tick_ms & ~clr & ~at_max;
assign hold = ~clr & ~inc;

//Multiplexor con mascaras: elige count+1 (inc), count (hold) o 0 (clr)
assign count_next = ({W{inc}} & (count + 1'b1)) | ({W{hold}} & count);

//Registro con FF
always_ff @(posedge clk) begin
    count <= count_next;
end

//Salidas
assign wait_done   = (count >= W'(TEST_WAIT_MS));
assign travel_done = (count >= limit);

endmodule