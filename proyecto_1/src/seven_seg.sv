// Decodificador combinacional. segments[6:0] = {g,f,e,d,c,b,a}.
// Salidas activas en bajo: 0 enciende el segmento; 1 lo apaga.
// Codigos compatibles con config_pkg: 00-0F hexadecimal, 10-13 o,c,n,t.
// Los codigos 14-1F dejan el display apagado.
module seven_seg (
    input  logic [4:0] char_code,
    output logic [6:0] segments
);

logic [19:0] character;

// Cada igualdad representa un mintermino (AND de los cinco bits).
assign character[0]  = (char_code == 5'h00);
assign character[1]  = (char_code == 5'h01);
assign character[2]  = (char_code == 5'h02);
assign character[3]  = (char_code == 5'h03);
assign character[4]  = (char_code == 5'h04);
assign character[5]  = (char_code == 5'h05);
assign character[6]  = (char_code == 5'h06);
assign character[7]  = (char_code == 5'h07);
assign character[8]  = (char_code == 5'h08);
assign character[9]  = (char_code == 5'h09);
assign character[10] = (char_code == 5'h0A);
assign character[11] = (char_code == 5'h0B);
assign character[12] = (char_code == 5'h0C);
assign character[13] = (char_code == 5'h0D);
assign character[14] = (char_code == 5'h0E);
assign character[15] = (char_code == 5'h0F);
assign character[16] = (char_code == 5'h10);
assign character[17] = (char_code == 5'h11);
assign character[18] = (char_code == 5'h12);
assign character[19] = (char_code == 5'h13);

// Suma de minterminos por segmento, invertida por la polaridad activa baja.
assign segments[0] = ~(character[0] | character[2] | character[3] |
    character[5] | character[6] | character[7] | character[8] |
    character[9] | character[10] | character[12] | character[14] | character[15]);
assign segments[1] = ~(character[0] | character[1] | character[2] |
    character[3] | character[4] | character[7] | character[8] |
    character[9] | character[10] | character[13]);
assign segments[2] = ~(character[0] | character[1] | character[3] |
    character[4] | character[5] | character[6] | character[7] |
    character[8] | character[9] | character[10] | character[11] |
    character[13] | character[16] | character[18]);
assign segments[3] = ~(character[0] | character[2] | character[3] |
    character[5] | character[6] | character[8] | character[9] |
    character[11] | character[12] | character[13] | character[14] |
    character[16] | character[17] | character[19]);
assign segments[4] = ~(character[0] | character[2] | character[6] |
    character[8] | character[10] | character[11] | character[12] |
    character[13] | character[14] | character[15] | character[16] |
    character[17] | character[18] | character[19]);
assign segments[5] = ~(character[0] | character[4] | character[5] |
    character[6] | character[8] | character[9] | character[10] |
    character[11] | character[12] | character[14] | character[15] | character[19]);
assign segments[6] = ~(character[2] | character[3] | character[4] |
    character[5] | character[6] | character[8] | character[9] |
    character[10] | character[11] | character[13] | character[14] |
    character[15] | character[16] | character[17] | character[18] | character[19]);

endmodule
