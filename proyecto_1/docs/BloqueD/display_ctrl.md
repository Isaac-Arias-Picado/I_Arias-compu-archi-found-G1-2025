# display_ctrl — Seleccion del contenido de HEX0 a HEX5

## Interfaz

Red combinacional que selecciona seis caracteres y utiliza seis instancias de
seven_seg. Cada HEX tiene conexiones independientes, por lo que no necesita
barrido ni reloj. Usa los codigos de estado y modo de config_pkg.

| Puerto | Direccion | Ancho | Funcion |
|---|---|---|---|
| reset | Entrada | 1 | Apaga los seis HEX mientras este activo |
| state | Entrada | 3 | Estado principal del Bloque C |
| mode | Entrada | 3 | Submodo de administracion del Bloque C |
| speed | Entrada | 3 | Velocidad seleccionada, 0 a 7 |
| window | Entrada | 9 | Ultimo intento, copiado en top desde la ventana de captura |
| door_open_flag | Entrada | 1 | Posicion recordada por C |
| HEX0 a HEX5 | Salida | 7 cada una | Segmentos activos bajos, orden gfedcba |

door_open_flag es una entrada requerida. Durante ADMIN, TEST y VALID la puerta
no se mueve, y HEX0 muestra A si vale 1 y C si vale 0. Es la posicion
recordada, no una medicion de posicion durante el movimiento. En los demas
estados se ignora.

## Distribucion y tabla de salida

| HEX | Contenido |
|---|---|
| HEX0 | Estado: E/C/o/A/c o posicion recordada |
| HEX1 | window[2:0], simbolo mas nuevo |
| HEX2 | window[5:3], simbolo intermedio |
| HEX3 | window[8:6], simbolo mas viejo |
| HEX4 | Modo: n, 1, 2, t |
| HEX5 | Velocidad normalizada 0 a F |

Ejemplo: state=CLOSED, modo normal, speed=4, window=123 produce de izquierda
a derecha HEX5..HEX0: 9 n 1 2 3 C. El intento se lee en el mismo orden en que
se ingreso.

| state | HEX0 | HEX4 |
|---|---|---|
| 0 ERROR | E | n |
| 1 CLOSED | C | n |
| 2 OPENING | o | n |
| 3 OPEN | A | n |
| 4 CLOSING | c | n |
| 5 ADMIN | A/C segun door_open_flag | 1 o 2 segun mode |
| 6 TEST | A/C segun door_open_flag | t |
| 7 VALID | A/C segun door_open_flag | n |

mode solo es distinto de 0 dentro de ADMIN, por eso HEX4 muestra n cuando
mode=0 y el valor de mode en otro caso. reset apaga todo; al liberarlo se
muestran inmediatamente las entradas actuales.

La velocidad se normaliza a la escala 0-F que pide el enunciado:

| speed | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|---|
| HEX5 | 0 | 2 | 4 | 6 | 9 | b | d | F |

Cada valor es round(15*speed/7).

## Implementacion estructural

Los comparadores decodifican estados y modos. Cada caracter se selecciona por
OR de constantes enmascaradas por las condiciones de su fila. Para cada HEX,
reset selecciona el codigo 1F, que seven_seg representa como apagado.

- position_state = (state=ADMIN) | (state=TEST) | (state=VALID)
- state_char = OR de codigos E/C/o/A/c bajo las condiciones de la tabla
- mode_char = t si TEST, n si mode=0, mode en otro caso
- speed_hex = OR de 2/4/6/9/B/D/F enmascarados por speed=1..7
- char = mascara(~reset) & contenido | mascara(reset)

Las mascaras tienen cinco bits. Seis decodificadores generan las salidas
finales, sin registros ni if/case/ternarios. No hay estados propios ni tabla de
transicion: los cambios dependen directamente de las entradas.

## Prueba en EDA Playground

1. SystemVerilog/Verilog; Aldec Riviera Pro si esta disponible.
2. Design: pegar src/seven_seg.sv y debajo src/display_ctrl.sv completos.
3. Testbench: testsbenchs/BloqueD/tb_display_ctrl.sv.
4. Top: tb_display_ctrl. Activar Open EPWave after run y ejecutar.
5. Esperar PASS DISPLAY_CTRL: 1545 escenarios, 9270 salidas comprobadas, 0 errores.

El banco compara los segmentos finales con una tabla independiente. Recorre
1024 combinaciones de estado, modo, velocidad y posicion; las 512 ventanas
posibles; reset en los ocho estados; y restauracion al liberar reset.
Cada escenario dura 10 ns: total 15450 ns. Observar state, mode, speed, window,
door_open_flag, reset y HEX0..HEX5. expected empaqueta {HEX5,...,HEX0}.
Para inspeccionar un caso simple, ir al ultimo intervalo de 10 ns: 9 n 1 2 3 C.
