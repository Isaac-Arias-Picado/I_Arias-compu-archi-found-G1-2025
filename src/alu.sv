module alu (
    input  logic [2:0] op,
    input  logic [2:0] a,
    input  logic [2:0] b,
    output logic [2:0] result
);

import config_pkg::*;

// Códigos de operación = primer dígito del intento (1-5).
// Propios de la ALU: no dependen de alu_op_t del paquete.
// Cualquier otro código da resultado 0.

localparam logic [2:0] OP_ADD  = 3'd1;
localparam logic [2:0] OP_SUB  = 3'd2;
localparam logic [2:0] OP_MUL  = 3'd3;
localparam logic [2:0] OP_ROTL = 3'd4;
localparam logic [2:0] OP_ROTR = 3'd5;

logic sel_sum, sel_sub, sel_mult, sel_rotl, sel_rotr;

assign sel_sum  = (op == OP_ADD);
assign sel_sub  = (op == OP_SUB);
assign sel_mult = (op == OP_MUL);
assign sel_rotl = (op == OP_ROTL);
assign sel_rotr = (op == OP_ROTR);


// Suma y resta circulares (se descarta el acarreo, mod 8)

logic [2:0] sum, sub;
assign sum = a + b;
assign sub = a - b;


// Multiplicación mod 8: productos parciales de peso 1, 2 y 4

logic [2:0] mult;
logic       pp_a1b0, pp_a0b1, carry_w2;

assign pp_a1b0  = a[1] & b[0];
assign pp_a0b1  = a[0] & b[1];
assign carry_w2 = pp_a1b0 & pp_a0b1;

assign mult[0] = a[0] & b[0];
assign mult[1] = pp_a1b0 ^ pp_a0b1;
assign mult[2] = (a[2] & b[0]) ^ (a[1] & b[1]) ^ (a[0] & b[2]) ^ carry_w2;


// Rotaciones sobre 3 bits. Cantidad de giros = b mod 3

logic mod_1, mod_2, mod_0;

assign mod_1 = (b == 3'd1) | (b == 3'd4) | (b == 3'd7);
assign mod_2 = (b == 3'd2) | (b == 3'd5);
assign mod_0 = ~mod_1 & ~mod_2;

logic [2:0] shift_l1, shift_l2;
assign shift_l1 = {a[1:0], a[2]};   // 1 giro a la izquierda
assign shift_l2 = {a[0], a[2:1]};   // 2 giros a la izquierda

logic [2:0] rotl, rotr;

assign rotl = ({3{mod_0}} & a) | ({3{mod_1}} & shift_l1) | ({3{mod_2}} & shift_l2);
assign rotr = ({3{mod_0}} & a) | ({3{mod_1}} & shift_l2) | ({3{mod_2}} & shift_l1);


// Selección del resultado por máscaras

assign result = ({3{sel_sum}}  & sum)  |
                ({3{sel_sub}}  & sub)  |
                ({3{sel_mult}} & mult) |
                ({3{sel_rotl}} & rotl) |
                ({3{sel_rotr}} & rotr);

endmodule