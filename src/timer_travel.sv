
module timer_travel (
    input  logic clk,
    input  logic reset,
    input  logic tick_ms,
    input  logic start,
    output logic wait_done,
    output logic timeout
);
import config_pkg::*;

//Ancho en bits del contador
localparam int W = $clog2(TIMEOUT_MS + 1);

logic [W-1:0] count, count_next;
logic clr, inc, hold;

assign clr = reset | start;
assign inc = tick_ms & ~clr & ~timeout;
assign hold = ~clr & ~inc;

//Enmascaramiento con {W{valor}} para multiplexor: elige count+1 (inc), count (hold) o 0 (clr)
assign count_next = ({W{inc}} & (count + 1'b1)) | ({W{hold}} & count);

//Registro con FF
always_ff @(posedge clk) begin
    count  <= count_next;
end

//Salidas
assign wait_done = (count >= TEST_WAIT_MS);
assign timeout = (count >= TIMEOUT_MS);

endmodule