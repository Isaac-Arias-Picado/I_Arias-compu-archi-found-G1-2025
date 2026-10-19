# Proyecto Grupal 1 — Puerta con Contraseña (FPGA)

## 1. Hardware y herramientas

| Elemento | Valor |
|---|---|
| FPGA | DE10-Standard `5CSXFC6D6F31C6N` |
| Reloj | 50 MHz |
| Herramienta | Quartus, SystemVerilog |
| Diseño | Estructural: `assign`, compuertas, registros, tablas, parámetros del pkg. Sin `case`, `if`, ternario |
| Dedos | 5 bits. Válidos: `00000` (0) y one-hot para 1–5. Cualquier otro patrón = ausencia, se ignora |
| Motor | `10` abrir, `01` cerrar. PWM en línea activa, 0 en la otra |
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
| Contraseña | 3 dígitos, cada uno 0–5 |
| Captura | Muestreo cada 2 s, shift register de 3 símbolos, comparación continua |
| Contraseñas | 2: abrir y cerrar, velocidad fija cada una |
| Sin contraseñas | Estado `E` hasta que exista al menos una |
| Reset | Borra todo, puerta cerrada, motor detenido |
| Admin | 5 submodos cíclicos con un botón |
| Test | Solo desde `S_CLOSED`/`S_ERROR`. Abrir 50 %, esperar 1 s, cerrar 50 %, buzzer continuo |
| Viaje | `T(s) = T_max · 7 / s`, `T_max = 4 s`, `s = 0` no mueve |
| ALU | `op=5` no hace nada (no cambia estado) |
| Buzzer | Solo `REG_OK`, `VALID`, `INVALID`, `OPENING`, `CLOSING`, `TEST` |

## 3. Display

| HEX | Muestra | Valores |
|---|---|---|
| HEX5 | Velocidad PWM | `0`–`7` |
| HEX4 | Modo / submode | `n`, `1`, `2`, `3`, `4`, `t` |
| HEX3 | Dígito más nuevo | `0`–`5` |
| HEX2 | Dígito del medio | `0`–`5` |
| HEX1 | Dígito más viejo | `0`–`5` |
| HEX0 | Estado puerta | `E`, `C`, `A`, `o`, `c` |

## 4. ALU (3 bits, circular mod 8)

| `op` | Operación | Resultado |
|---|---|---|
| 0 | Suma | `(A + B) mod 8` |
| 1 | Resta | `(A - B) mod 8` |
| 2 | Multiplicación | `(A · B) mod 8` |
| 3 | Rotación izquierda | `rot_izq(A, B mod 3)` |
| 4 | Rotación derecha | `rot_der(A, B mod 3)` |
| 5 | Nula | no cambia estado |

## 5. PWM y velocidades

Duty = `s / 7`. Frecuencia PWM = 1 kHz.

| `s` | Duty | `T(s)` |
|---|---|---|
| 0 | 0 % | sin movimiento |
| 1 | 14.3 % | `T_max · 7` |
| 2 | 28.6 % | `T_max · 7/2` |
| 3 | 42.9 % | `T_max · 7/3` |
| 4 | 57.1 % | `T_max · 7/4` |
| 5 | 71.4 % | `T_max · 7/5` |
| 6 | 85.7 % | `T_max · 7/6` |
| 7 | 100 % | `T_max` |

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

## 7. Submodos admin

| Submodo | Código | Acción |
|---|---|---|
| `M_NORMAL` | `3'd0` | Salir de admin |
| `M_REG_OPEN` | `3'd1` | Registrar contraseña de abrir |
| `M_REG_CLOSE` | `3'd2` | Registrar contraseña de cerrar |
| `M_DEL_OPEN` | `3'd3` | Eliminar contraseña de abrir |
| `M_DEL_CLOSE` | `3'd4` | Eliminar contraseña de cerrar |

## 8. Tabla de transición — FSM principal

| Estado | Condición | Siguiente | Acción |
|---|---|---|---|
| `S_ERROR` | `reset` | `S_ERROR` | Borrar todo, motor off |
| `S_ERROR` | `admin_btn` | `S_ADMIN` | `mode ← M_REG_OPEN` |
| `S_ERROR` | `test_btn` | `S_TEST` | Iniciar test |
| `S_ERROR` | otro | `S_ERROR` | — |
| `S_CLOSED` | `reset` | `S_ERROR` | Borrar todo, motor off |
| `S_CLOSED` | `admin_btn` | `S_ADMIN` | `mode ← M_REG_OPEN` |
| `S_CLOSED` | `test_btn` | `S_TEST` | Iniciar test |
| `S_CLOSED` | `match_open && s≠0` | `S_OPENING` | `speed ← s`, timer `T(s)`, motor abrir |
| `S_CLOSED` | `match_open && s=0` | `S_CLOSED` | Buzzer `VALID`, sin movimiento |
| `S_CLOSED` | otro | `S_CLOSED` | — |
| `S_OPENING` | `timer_done` | `S_OPEN` | Motor off |
| `S_OPENING` | `reset` | `S_ERROR` | Borrar todo, motor off |
| `S_OPENING` | otro | `S_OPENING` | Motor sigue |
| `S_OPEN` | `reset` | `S_ERROR` | Borrar todo, motor off |
| `S_OPEN` | `admin_btn` | `S_ADMIN` | `mode ← M_REG_OPEN` |
| `S_OPEN` | `test_btn` | `S_TEST` | Iniciar test |
| `S_OPEN` | `match_close && s≠0` | `S_CLOSING` | `speed ← s`, timer `T(s)`, motor cerrar |
| `S_OPEN` | `match_close && s=0` | `S_OPEN` | Buzzer `VALID`, sin movimiento |
| `S_OPEN` | otro | `S_OPEN` | — |
| `S_CLOSING` | `timer_done` | `S_CLOSED` | Motor off |
| `S_CLOSING` | `reset` | `S_ERROR` | Borrar todo, motor off |
| `S_CLOSING` | otro | `S_CLOSING` | Motor sigue |
| `S_ADMIN` | `reset` | `S_ERROR` | Borrar todo, motor off |
| `S_ADMIN` | `admin_btn` | `S_ADMIN` | Avanzar submodo cíclico |
| `S_ADMIN` | `mode = M_NORMAL` | `S_CLOSED` o `S_OPEN` según `door_open_flag` | — |
| `S_ADMIN` | match en submode exitoso | `S_ADMIN` | `mode ← M_NORMAL`, beep |
| `S_ADMIN` | otro | `S_ADMIN` | — |
| `S_TEST` | `reset` | `S_ERROR` | Borrar todo, motor off |
| `S_TEST` | secuencia completa | `S_CLOSED` | Motor off, buzzer off |
| `S_TEST` | otro | `S_TEST` | Sigue secuencia |

## 9. Tabla — FSM de captura

| Estado | Condición | Siguiente | Acción |
|---|---|---|---|
| `CAP_IDLE` | `capture_tick` y símbolo válido | `CAP_SHIFT` | Desplazar símbolo |
| `CAP_SHIFT` | siguiente ciclo | `CAP_IDLE` | Limpiar tick |
| cualquiera | `reset` | `CAP_IDLE` | Limpiar registro |
| cualquiera | `match` (open o close) | `CAP_IDLE` | Limpiar registro |

## 10. Tabla — FSM de administración

| Submodo | Evento | Acción |
|---|---|---|
| `M_NORMAL` | — | Nada |
| `M_REG_OPEN` | 3 dígitos capturados | Sobrescribir contraseña de abrir. Beep `REG_OK`. → `M_NORMAL` |
| `M_REG_CLOSE` | 3 dígitos capturados | Sobrescribir contraseña de cerrar. Beep `REG_OK`. → `M_NORMAL` |
| `M_DEL_OPEN` | 3 dígitos coinciden con abrir | Borrar contraseña de abrir. Beep `REG_OK`. → `M_NORMAL` |
| `M_DEL_CLOSE` | 3 dígitos coinciden con cerrar | Borrar contraseña de cerrar. Beep `REG_OK`. → `M_NORMAL` |
| `M_DEL_*` | 3 dígitos no coinciden | Beep `INVALID`, permanece en submode |

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

Contenido: `CLK_FREQ_HZ`, `CAPTURE_TIME_S`, `DEBOUNCE_MS`, `PW_LEN`, `PW_DIGIT_BITS`, `PWM_FREQ_HZ`, `PWM_COUNTER_MAX`, `T_MAX_S`, `TRAVEL_TIME_LUT[0:7]`, `TEST_SPEED`, `TEST_WAIT_MS`, frecuencias de buzzer, `DISPLAY_REFRESH_HZ`, `state_t`, `admin_mode_t`, `alu_op_t`, `buzzer_event_t`.

## 13. Módulos

| Archivo | Función |
|---|---|
| `config_pkg.sv` | Parámetros, tipos, LUT de tiempos |
| `top.sv` | Integración |
| `clk_enables.sv` | Ticks: captura 2 s, debounce, refresh display, beeps |
| `debounce.sv` | Botones y one-hot (validación de patrón) |
| `finger_capture.sv` | Shift register 3×3 bits |
| `password_mem.sv` | 2 contraseñas + flags válidas |
| `comparator.sv` | Ventana vs contraseñas |
| `alu.sv` | `op`, `A`, `B` → resultado 3 bits |
| `fsm_main.sv` | Estados de puerta + admin + test |
| `timer_travel.sv` | Conteo `T(s)` desde LUT |
| `pwm.sv` | `s` → duty |
| `motor_ctrl.sv` | Dirección + PWM |
| `buzzer_ctrl.sv` | Eventos → tono/patrón |
| `display_ctrl.sv` | Multiplexación HEX0–HEX5 |
| `seven_seg.sv` | Hex → 7 segmentos |

## 14. Orden de implementación

1. `config_pkg.sv`
2. `clk_enables.sv`, `debounce.sv`, `seven_seg.sv`
3. `finger_capture.sv`, `comparator.sv`, `password_mem.sv`
4. `alu.sv`, `pwm.sv`, `motor_ctrl.sv`
5. `timer_travel.sv`, `buzzer_ctrl.sv`
6. `fsm_main.sv`
7. `display_ctrl.sv`, `top.sv`
8. Testbenches e integración