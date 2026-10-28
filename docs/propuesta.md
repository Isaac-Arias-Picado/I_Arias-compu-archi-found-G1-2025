# Proyecto Grupal 1 — Puerta con Contraseña (FPGA)

## 1. Hardware y herramientas

| Elemento | Valor |
|---|---|
| FPGA | DE10-Standard `5CSXFC6D6F31C6N` |
| Reloj | 50 MHz |
| Herramienta | Quartus, SystemVerilog |
| Diseño | Estructural: `assign`, compuertas, registros, tablas, parámetros del pkg. Sin `case`, `if`, ternario |
| Dedos | 5 bits. Válidos: `00000` (0) y one-hot para 1–5. Cualquier otro patrón = ausencia, se ignora |
| Motor | `10` abrir, `01` cerrar. PWM en línea activa, 0 en la otra. Desacople con 2 optoacopladores y puente H |
| Display | HEX0–HEX5 de la FPGA |
| Buzzer | Solo eventos importantes |

## 1.1 Patrones válidos del detector de dedos

| Patrón | Símbolo |
|---|---|
| `00000` | 0 |
| `00001` | 1 |
| `00010` | 2 |
| `00100` | 3 |
| `01000` | 4 |
| `10000` | 5 |
| cualquier otro | ausencia, se ignora |

## 2. Decisiones funcionales

| Tema | Decisión |
|---|---|
| Contraseña | 3 dígitos. El primero de 1 a 5 (es la operación de la ALU), los otros dos de 0 a 5 |
| Captura | Muestreo cada 2 s en un shift register de 3 símbolos |
| Intentos | Un intento empieza con el primer dígito distinto de 0 y se evalúa al capturar el tercero. Esto permite el sonido de contraseña inválida |
| Contraseñas | 2 espacios en memoria, equivalentes. Cualquier contraseña registrada abre si la puerta está cerrada y cierra si está abierta |
| Sin contraseñas | Estado `E` hasta que exista al menos una |
| Admin | Submodos 1 y 2 escogen el espacio. Si la contraseña ya existe se borra, si no se guarda en ese espacio |
| Reset | Borra todas las contraseñas. Si la puerta se está moviendo, termina el recorrido y luego pasa a `E` sin perder su posición |
| Test | Solo con la puerta cerrada. Abrir 50 %, esperar 1 s, cerrar 50 %, buzzer continuo |
| Viaje | Por tiempo. `T(s) = T_max · 7 / s` en ms con `T_max = 4 s` (provisional, se calibra con la maqueta). `s = 0` no mueve |
| Validación | Al validar suena VALID y se espera 1 s antes de mover, para que el sonido del motor no lo tape |
| ALU | `op` de 1 a 5, sin operación nula |
| Buzzer | Solo `REG_OK`, `VALID`, `INVALID`, `OPENING`, `CLOSING`, `TEST` |

## 3. Display

| HEX | Muestra | Valores |
|---|---|---|
| HEX5 | Velocidad normalizada | `0`–`F` |
| HEX4 | Modo / submodo | `n`, `1`, `2`, `t` |
| HEX3 | Dígito más nuevo | `0`–`5` |
| HEX2 | Dígito del medio | `0`–`5` |
| HEX1 | Dígito más viejo | `0`–`5` |
| HEX0 | Estado puerta | `E`, `C`, `A`, `o`, `c` |

La velocidad normalizada es `round(s · 15 / 7)`: 0, 2, 4, 6, 9, B, D, F. En `ADMIN`, `TEST` y `VALID`, HEX0 muestra la posición de la puerta.

## 4. ALU (3 bits, circular mod 8)

| `op` | Operación | Resultado |
|---|---|---|
| 1 | Suma | `(A + B) mod 8` |
| 2 | Resta | `(A - B) mod 8` |
| 3 | Multiplicación | `(A · B) mod 8` |
| 4 | Rotación izquierda | `rot_izq(A, B mod 3)` |
| 5 | Rotación derecha | `rot_der(A, B mod 3)` |

`op` = dígito más viejo (`window[8:6]`), A = `window[5:3]`, B = `window[2:0]`. Cualquier otro código da 0.

## 5. PWM y velocidades

Duty = `s / 7`. Frecuencia PWM = 1 kHz.

| `s` | Duty | `T(s)` |
|---|---|---|
| 0 | 0 % | sin movimiento |
| 1 | 14.3 % | 28000 ms |
| 2 | 28.6 % | 14000 ms |
| 3 | 42.9 % | 9333 ms |
| 4 | 57.1 % | 7000 ms |
| 5 | 71.4 % | 5600 ms |
| 6 | 85.7 % | 4666 ms |
| 7 | 100 % | 4000 ms |

## 6. Estados FSM principal

| Estado | Código | Significado |
|---|---|---|
| `S_ERROR` | `3'd0` | Sin contraseñas |
| `S_CLOSED` | `3'd1` | Puerta cerrada |
| `S_OPENING` | `3'd2` | Abriendo |
| `S_OPEN` | `3'd3` | Puerta abierta |
| `S_CLOSING` | `3'd4` | Cerrando |
| `S_ADMIN` | `3'd5` | Administración |
| `S_TEST` | `3'd6` | Test |
| `S_VALID` | `3'd7` | Contraseña válida, espera 1 s antes de mover |

## 7. Submodos admin

| Submodo | Código | Acción |
|---|---|---|
| `M_NORMAL` | `3'd0` | Salir de admin |
| `M_SLOT1` | `3'd1` | Registrar o borrar en el espacio 1 |
| `M_SLOT2` | `3'd2` | Registrar o borrar en el espacio 2 |

## 8. Tabla de transición — FSM principal

Prioridad dentro de cada estado: `reset` > `admin_btn` > `test_btn` > `ready`.

| Estado | Condición | Siguiente | Acción |
|---|---|---|---|
| `S_ERROR` | `reset` | `S_ERROR` | Borrar contraseñas |
| `S_ERROR` | `admin_btn` | `S_ADMIN` | `mode ← M_SLOT1` |
| `S_ERROR` | `test_btn` y puerta cerrada | `S_TEST` | Fase 0, `speed ← TEST_SPEED` |
| `S_ERROR` | `ready` | `S_ERROR` | Buzzer `INVALID` |
| `S_CLOSED`/`S_OPEN` | `reset` | `S_ERROR` | Borrar contraseñas |
| `S_CLOSED`/`S_OPEN` | `admin_btn` | `S_ADMIN` | `mode ← M_SLOT1` |
| `S_CLOSED` | `test_btn` | `S_TEST` | Fase 0, `speed ← TEST_SPEED` |
| `S_CLOSED`/`S_OPEN` | `ready` y `match` | `S_VALID` | `speed ← s`, buzzer `VALID` |
| `S_CLOSED`/`S_OPEN` | `ready` y no `match` | igual | Buzzer `INVALID` |
| `S_VALID` | `reset` | `S_ERROR` | Borrar contraseñas |
| `S_VALID` | `wait_done` y `s≠0` | `S_OPENING`/`S_CLOSING` según la puerta | Timer `T(s)`, motor |
| `S_VALID` | `wait_done` y `s=0` | `S_CLOSED`/`S_OPEN` según la puerta | Sin movimiento |
| `S_OPENING`/`S_CLOSING` | `reset` | igual | Borrar contraseñas, el motor sigue |
| `S_OPENING`/`S_CLOSING` | `travel_done` | `S_OPEN`/`S_CLOSED` (`S_ERROR` si no hay contraseñas) | Motor off |
| `S_ADMIN` | `reset` | `S_ERROR` | Borrar contraseñas |
| `S_ADMIN` | `mode = M_NORMAL` | `S_CLOSED`/`S_OPEN` según la puerta (`S_ERROR` si no hay contraseñas) | — |
| `S_ADMIN` | `admin_btn` | `S_ADMIN` | `mode`: 1 → 2 → 0 |
| `S_ADMIN` | `ready` y `match` | `S_ADMIN` | Borrar la que coincide, `REG_OK`, `mode ← M_NORMAL` |
| `S_ADMIN` | `ready` y no `match` | `S_ADMIN` | Guardar en el espacio `mode`, `REG_OK`, `mode ← M_NORMAL` |
| `S_TEST` | fase 0 y `travel_done` | `S_TEST` | Fase 1, esperar 1 s |
| `S_TEST` | fase 1 y `wait_done` | `S_TEST` | Fase 2, cerrar |
| `S_TEST` | fase 2 y `travel_done` | `S_CLOSED` (`S_ERROR` si no hay contraseñas) | Motor off, buzzer off |

## 9. Tabla — contador de intentos (`attempt_ctrl`)

Una captura válida es `tick_capture` con `finger_valid`.

| Contador | Captura válida con dígito ≠ 0 | Captura válida con dígito 0 |
|---|---|---|
| 0 | Pasa a 1 | Se queda en 0 |
| 1 | Pasa a 2 | Pasa a 2 |
| 2 | Pasa a 0 y genera `ready` | Pasa a 0 y genera `ready` |

`reset` o `clear_capture` ponen el contador en 0. `ready` sale un ciclo después de la tercera captura, cuando la ventana ya tiene los 3 dígitos.

## 10. Tabla — administración

| Evento en `S_ADMIN` | Acción |
|---|---|
| `admin_btn` | Pasa al siguiente submodo (1 → 2 → `n`) |
| Intento que coincide con alguna contraseña | Borrar esa contraseña. Beep `REG_OK`. → `M_NORMAL` |
| Intento que no coincide | Guardar en el espacio del submodo (sobrescribe si estaba ocupado). Beep `REG_OK`. → `M_NORMAL` |
| `M_NORMAL` | Salir de admin |

## 11. Buzzer

| Evento | Frecuencia | Patrón |
|---|---|---|
| `TEST` | 1 kHz | continuo durante test |
| `REG_OK` | 1 kHz | 1 beep de 100 ms |
| `VALID` | 1 kHz | 2 beeps de 100 ms |
| `INVALID` | 500 Hz | 1 beep de 500 ms |
| `OPENING` | 2 kHz | continuo mientras abre |
| `CLOSING` | 1.5 kHz | continuo mientras cierra |

## 12. Paquete de configuración

Archivo: `config_pkg.sv`. Único punto de cambio de tiempos, frecuencias, códigos y LUT de velocidades. Ningún otro archivo contiene números mágicos.

Contenido: `CLK_FREQ_HZ`, `CAPTURE_TIME_S`, `DEBOUNCE_MS`, `PW_LEN`, `PW_DIGIT_BITS`, `PWM_FREQ_HZ`, `PWM_COUNTER_MAX`, `T_MAX_S`, `T_MAX_MS`, `TRAVEL_MS_1`–`TRAVEL_MS_7`, `TRAVEL_MS_MAX`, `TEST_SPEED`, `TEST_WAIT_MS`, frecuencias de buzzer, `DISPLAY_REFRESH_HZ`, `state_t`, `admin_mode_t`, `buzzer_event_t`.

## 13. Módulos

| Bloque | Archivo | Función |
|---|---|---|
| — | `config_pkg.sv` | Parámetros, tipos, LUT de tiempos |
| A | `clk_enables.sv` | Ticks: captura 2 s, debounce, refresh display |
| A | `debounce.sv` | Botones y one-hot (validación de patrón) |
| A | `finger_capture.sv` | Shift register 3×3 bits |
| B | `alu.sv` | `op`, `A`, `B` → velocidad de 3 bits |
| B | `password_mem.sv` | 2 contraseñas + banderas de validez |
| B | `comparator.sv` | Ventana vs contraseñas → `match1`, `match2` |
| C | `timer_travel.sv` | Espera de 1 s y fin de viaje `T(s)` desde la LUT |
| C | `attempt_ctrl.sv` | Detecta intentos de 3 dígitos → `ready` |
| C | `fsm_main.sv` | Estados de puerta + admin + test |
| C | `top.sv` | Integración |
| D | `pwm.sv` | `s` → duty |
| D | `motor_ctrl.sv` | Dirección + PWM |
| D | `buzzer_ctrl.sv` | Eventos → tono/patrón |
| D | `display_ctrl.sv` | Contenido de HEX0–HEX5 |
| D | `seven_seg.sv` | Código → 7 segmentos |

## 14. Orden de implementación

1. `config_pkg.sv`
2. `clk_enables.sv`, `debounce.sv`, `seven_seg.sv`
3. `finger_capture.sv`, `comparator.sv`, `password_mem.sv`
4. `alu.sv`, `pwm.sv`, `motor_ctrl.sv`
5. `timer_travel.sv`, `attempt_ctrl.sv`, `buzzer_ctrl.sv`
6. `fsm_main.sv`
7. `display_ctrl.sv`, `top.sv`
8. Testbenches e integración