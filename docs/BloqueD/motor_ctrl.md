# motor_ctrl — Direccion del motor

## Interfaz y contrato

Modulo combinacional sin reloj, contadores ni estados. Dirige el PWM a una de
las dos entradas activas altas del puente H. No alimenta directamente el motor.
Los codigos coinciden con motor_dir_t de config_pkg; no necesita importar el
paquete para poder probarse solo. No se modifica config_pkg.

| Puerto | Direccion | Ancho | Funcion |
|---|---|---|---|
| reset | Entrada | 1 | Fuerza ambas salidas a 0 |
| motor_dir | Entrada | 2 | 00 detener, 10 abrir, 01 cerrar, 11 no valido |
| pwm_in | Entrada | 1 | PWM recibido desde pwm.sv |
| motor_lines | Salida | 2 | {linea_abrir, linea_cerrar} |

## Tabla de salida

| reset | motor_dir | pwm_in | motor_lines |
|---|---|---|---|
| 1 | cualquiera | cualquiera | 00 |
| 0 | 00 | cualquiera | 00 |
| 0 | 10 | 0 | 00 |
| 0 | 10 | 1 | 10 |
| 0 | 01 | 0 | 00 |
| 0 | 01 | 1 | 01 |
| 0 | 11 | cualquiera | 00 |

## Ecuaciones

motor_lines[1] = ~reset & motor_dir[1] & ~motor_dir[0] & pwm_in

motor_lines[0] = ~reset & ~motor_dir[1] & motor_dir[0] & pwm_in

Cada salida exige una direccion distinta. Su AND es cero para entradas binarias
estables porque contiene motor_dir[1] & ~motor_dir[1]. No se utilizan if, case,
ternarios ni registros. No hay tabla de transicion porque no almacena estado.
No modifica el duty ni la frecuencia de la entrada PWM.

## Integracion

Conectar pwm.pwm_out a pwm_in; la direccion proviene del Bloque C. En top se
asignan motor_lines[1] y motor_lines[0] a los pines del puente H. Verificar el
sentido fisico de giro al montar el mecanismo.

El Bloque C debe ordenar detener antes de invertir. Este modulo no incorpora
tiempo muerto ni interbloqueo temporal. La tabla describe la logica estable y
la simulacion RTL no verifica retardos o transitorios electricos. Antes de usar
el motor se deben confirmar polaridades, habilitacion y requisitos del puente H.
00 significa desactivar ambas entradas; frenado o giro libre dependen del driver.

## Prueba aislada en EDA Playground

1. SystemVerilog/Verilog, simulador Aldec Riviera Pro si esta disponible.
2. Design: contenido de src/motor_ctrl.sv.
3. Testbench: contenido de testsbenchs/BloqueD/tb_motor_ctrl.sv.
4. Top, si se solicita: tb_motor_ctrl. Activar Open EPWave after run.
5. Ejecutar. Resultado esperado: PASS MOTOR_CTRL: 32 combinaciones comprobadas, 0 errores.

Prueba las 16 combinaciones en ambos sentidos. Compara contra una tabla
independiente y comprueba que no aparezca 11. Duracion: 320 ns.
Senales a observar: reset, motor_dir, pwm_in, motor_lines, expected.

## Prueba con el PWM real

1. Design: pegar src/pwm.sv y, debajo, src/motor_ctrl.sv.
2. Testbench: testsbenchs/BloqueD/tb_pwm_motor_ctrl.sv, sustituyendo el anterior.
3. Top: tb_pwm_motor_ctrl. Ejecutar.
4. Resultado esperado: PASS PWM + MOTOR_CTRL: 18 periodos, ... comprobaciones, 0 errores.

Prueba las ocho velocidades al abrir y cerrar, detener y direccion invalida con
velocidad maxima, cambios de direccion pasando por detener y reset entre flancos.
Cuenta los ciclos altos de cada salida durante periodos completos de 1 ms.
Duracion aproximada: 18 ms. Observar motor_dir, speed, pwm_out y motor_lines;
expandir motor_lines para distinguir las dos rutas.

Estado: ambos bancos preparados; pendiente ejecutar simulacion HDL y guardar
sus resultados. No equivale a validacion del puente H o del motor fisico.
