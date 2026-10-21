# seven_seg — Decodificador de siete segmentos

## Proposito e interfaz

Convierte un codigo de caracter de cinco bits en siete salidas combinacionales.
No necesita reloj, reset ni tick. display_ctrl seleccionara el caracter de cada
HEX y utilizara una instancia de este modulo por display.

| Puerto | Direccion | Ancho | Significado |
|---|---|---|---|
| char_code | Entrada | 5 | Codigo compatible con los caracteres de config_pkg |
| segments | Salida | 7 | {g,f,e,d,c,b,a}; 0 enciende, 1 apaga |

```text
     a
   -----
 f |   | b
   --g--
 e |   | c
   -----
     d
```

El orden y la polaridad son el contrato del modulo. Al asignar pines en top se
debe comprobar la correspondencia con la tarjeta. No incluye punto decimal.

## Tabla de salida

| Codigo hexadecimal | Caracter | segments[6:0] (gfedcba) |
|---|---|---|
| 00 | 0 | 1000000 |
| 01 | 1 | 1111001 |
| 02 | 2 | 0100100 |
| 03 | 3 | 0110000 |
| 04 | 4 | 0011001 |
| 05 | 5 | 0010010 |
| 06 | 6 | 0000010 |
| 07 | 7 | 1111000 |
| 08 | 8 | 0000000 |
| 09 | 9 | 0010000 |
| 0A | A | 0001000 |
| 0B | b | 0000011 |
| 0C | C | 1000110 |
| 0D | d | 0100001 |
| 0E | E | 0000110 |
| 0F | F | 0001110 |
| 10 | o | 0100011 |
| 11 | c | 0100111 |
| 12 | n | 0101011 |
| 13 | t | 0000111 |
| 14 a 1F | Apagado | 1111111 |

B y D se representan con minusculas para distinguirlas de 8 y 0.
CHAR_O produce una o minuscula; CHAR_c produce una c minuscula.
El codigo 1F puede utilizarse para apagar un HEX sin modificar config_pkg.

## Diseno estructural

Para cada codigo k entre 0 y 19 se genera un mintermino character[k].
La igualdad con una constante equivale al AND de los cinco literales de entrada,
invirtiendo aquellos cuyo bit en k sea cero. Por ejemplo:

character[1] = ~char_code[4] & ~char_code[3] & ~char_code[2] & ~char_code[1] & char_code[0]

Cada segmento es el NOT del OR de los minterminos de los caracteres que lo
encienden. Por ejemplo, el segmento a incluye 0, 2, 3, 5, 6, 7, 8, 9, A, C, E, F.
Para un codigo de 20 a 31 ningun mintermino esta activo y todos los segmentos
quedan en 1. Es una red combinacional de compuertas; no utiliza if, case,
ternarios, registros ni memoria. No hay estados ni tabla de transicion.

Los codigos se expresan como constantes locales en las comparaciones para que
este modulo pueda simularse solo. Coinciden con config_pkg, que no se modifica.

## Pruebas en EDA Playground

1. Seleccionar SystemVerilog y un simulador que lo soporte.
2. Pegar src/seven_seg.sv en Design y testsbenchs/BloqueD/tb_seven_seg.sv
   en Testbench. No hace falta pegar config_pkg para esta prueba aislada.
3. Indicar tb_seven_seg como top si la herramienta lo solicita.
4. Activar Open EPWave after run para inspeccionar dump.vcd.
5. Ejecutar. El resultado esperado es: PASS: 64 comprobaciones, 0 errores.

El banco recorre las 32 entradas en orden ascendente y descendente. Compara
cada salida contra una tabla de referencia independiente, detecta X/Z mediante
!== y termina con $fatal si hay discrepancias. Cada entrada dura 10 ns; la
simulacion completa dura 640 ns. En EPWave observar char_code y segments;
expandir segments para ver cada segmento.

Estado: banco preparado; pendiente de ejecutar en un simulador SystemVerilog.
La simulacion logica no verifica asignaciones de pines ni el display fisico.
