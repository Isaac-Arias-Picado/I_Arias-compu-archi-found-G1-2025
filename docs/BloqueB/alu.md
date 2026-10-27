# alu

## Propósito

Calcula la velocidad de la puerta a partir de los tres dígitos de la ventana de captura. El primer dígito elige la operación y los otros dos son los operandos A y B. El resultado es de 3 bits y circular (mod 8), lo que da una velocidad de 0 a 7.

## Interfaz

| Puerto   | Dirección | Ancho | Descripción                                                    |
|----------|-----------|-------|----------------------------------------------------------------|
| `op`     | entrada   | 3     | Operación (1 a 5). Es `window[8:6]`.                           |
| `a`      | entrada   | 3     | Operando A. Es `window[5:3]`.                                  |
| `b`      | entrada   | 3     | Operando B. Es `window[2:0]`.                                  |
| `result` | salida    | 3     | Resultado circular de 3 bits. Es la velocidad `s` de la puerta.|

Es lógica combinacional pura: no tiene reloj ni reset.

## Operaciones

| `op` | Constante  | Operación          | Resultado                  |
|------|------------|--------------------|----------------------------|
| 1    | `OP_ADD`   | Suma               | `(A + B) mod 8`            |
| 2    | `OP_SUB`   | Resta              | `(A - B) mod 8`            |
| 3    | `OP_MUL`   | Multiplicación     | `(A · B) mod 8`            |
| 4    | `OP_ROTL`  | Rotación izquierda | `rot_izq(A, B mod 3)`      |
| 5    | `OP_ROTR`  | Rotación derecha   | `rot_der(A, B mod 3)`      |
| 0, 6, 7 | —       | No es operación    | `000`                      |

## Decisiones de diseño

1. No existe operación nula. Un intento nunca empieza con 0, así que `op = 0` no llega a la ALU en uso normal. Si llegara, el resultado es 0 (velocidad 0, sin movimiento). Lo mismo con los códigos 6 y 7.
2. Los códigos de operación (1 a 5) se definen dentro de `alu.sv`, porque `alu_op_t` del paquete numera de 0 a 4 y no coincide con el dígito. El bloque C debe conectar `window[8:6]` directo a `op`.
3. La rotación de 3 bits repetida 3 veces devuelve el mismo valor, por eso los giros son `B mod 3`.
4. La multiplicación se arma con productos parciales y acarreo, sin el operador `*`. Suma y resta usan `+` y `-` descartando el acarreo, igual que el contador de `clk_enables`.
5. El resultado se elige con máscaras de selección, sin `case`, `if` ni ternario.

## Ecuaciones booleanas

sel_sum = (op = 1), sel_sub = (op = 2), sel_mult = (op = 3), sel_rotl = (op = 4), sel_rotr = (op = 5)

sum = (A + B) mod 8

sub = (A − B) mod 8

Multiplicación mod 8:

pp_a1b0 = A[1] ∧ B[0]

pp_a0b1 = A[0] ∧ B[1]

carry_w2 = pp_a1b0 ∧ pp_a0b1

mult[0] = A[0] ∧ B[0]

mult[1] = pp_a1b0 ⊕ pp_a0b1

mult[2] = (A[2] ∧ B[0]) ⊕ (A[1] ∧ B[1]) ⊕ (A[0] ∧ B[2]) ⊕ carry_w2

Giros:

mod_1 = (B = 1) ∨ (B = 4) ∨ (B = 7)

mod_2 = (B = 2) ∨ (B = 5)

mod_0 = ¬mod_1 ∧ ¬mod_2

shift_l1 = A[1:0] ∥ A[2]

shift_l2 = A[0] ∥ A[2:1]

rotl[i] = (mod_0 ∧ A[i]) ∨ (mod_1 ∧ shift_l1[i]) ∨ (mod_2 ∧ shift_l2[i])

rotr[i] = (mod_0 ∧ A[i]) ∨ (mod_1 ∧ shift_l2[i]) ∨ (mod_2 ∧ shift_l1[i])

Resultado:

result[i] = (sel_sum ∧ sum[i]) ∨ (sel_sub ∧ sub[i]) ∨ (sel_mult ∧ mult[i]) ∨ (sel_rotl ∧ rotl[i]) ∨ (sel_rotr ∧ rotr[i]), para i = 0 a 2

## Ejemplos

| `op` | A | B | Resultado | Razón                                   |
|------|---|---|-----------|-----------------------------------------|
| 1    | 5 | 4 | 1         | 9 mod 8                                 |
| 2    | 1 | 3 | 6         | −2 mod 8                                |
| 3    | 3 | 3 | 1         | 9 mod 8                                 |
| 4    | 5 | 4 | 3         | B mod 3 = 1; `101` gira a `011`         |
| 5    | 1 | 2 | 2         | B mod 3 = 2; `001` gira a `010`         |

## Verificación

| Test                         | Verifica                                                                 | Resultado   |
|------------------------------|--------------------------------------------------------------------------|-------------|
| Suma                         | Las 64 combinaciones (A, B) con `op` = 1 dan `(A + B) mod 8`.            | `PASS` |
| Resta                        | Las 64 combinaciones con `op` = 2 dan `(A − B) mod 8`.                   | `PASS` |
| Multiplicación               | Las 64 combinaciones con `op` = 3 dan `(A · B) mod 8`.                   | `PASS` |
| Rotación izquierda           | Las 64 combinaciones con `op` = 4 giran A en `B mod 3`.                  | `PASS` |
| Rotación derecha             | Las 64 combinaciones con `op` = 5 giran A en `B mod 3`.                  | `PASS` |
| Códigos 0, 6 y 7             | Con esos códigos el resultado es 0 para cualquier A y B.                 | `PASS` |
| Valores puntuales            | Los cinco ejemplos de la tabla anterior.                                 | `PASS` |