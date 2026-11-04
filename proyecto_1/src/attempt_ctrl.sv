module attempt_ctrl (
    input  logic       clk,
    input  logic       reset,
    input  logic       tick_capture,   // pulso cada 2 s (A)
    input  logic       finger_valid,   // patron de dedos valido (A)
    input  logic [2:0] finger_symbol,  // digito capturado (A)
    input  logic       clear_capture,  // limpiar intento (FSM)
    output logic       ready           // se completo un intento (FSM)
);

// Senales internas
logic [1:0] cnt, cnt_next;   // digitos que lleva el intento
logic clr, shift, nz;
logic c0, c1, c2;
logic start, adv, fin, hold;

// Condiciones
assign clr   = reset | clear_capture;
assign shift = tick_capture & finger_valid;
assign nz    = finger_symbol[2] | finger_symbol[1] | finger_symbol[0];

// Decodificacion del contador
assign c0 = (cnt == 2'd0);
assign c1 = (cnt == 2'd1);
assign c2 = (cnt == 2'd2);

// Transiciones del contador
assign start = shift & nz & c0 & ~clr;   // 0 -> 1, empieza el intento
assign adv   = shift & c1 & ~clr;        // 1 -> 2
assign fin   = shift & c2 & ~clr;        // 2 -> 0, intento completo
assign hold  = ~clr & ~start & ~adv & ~fin;

// Multiplexor con mascaras: elige 1 (start), 2 (adv), cnt (hold) o 0 (clr, fin)
assign cnt_next = ({2{start}} & 2'd1) | ({2{adv}} & 2'd2) | ({2{hold}} & cnt);

// Registros con FF
// ready sale un ciclo despues de fin, cuando la ventana ya tiene el tercer digito
always_ff @(posedge clk) begin
    cnt   <= cnt_next;
    ready <= fin;
end

endmodule