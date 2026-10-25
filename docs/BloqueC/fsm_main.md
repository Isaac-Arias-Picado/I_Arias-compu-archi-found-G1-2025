# fsm_main

## Propósito

Máquina de estados principal. Recuerda si la puerta está abierta o cerrada, decide cuándo moverla, maneja la administración de contraseñas y la secuencia de prueba, y genera las órdenes para la memoria, el motor, el buzzer y el display.

## Interfaz

| Puerto           | Dirección | Ancho | Descripción                                                            |
|------------------|-----------|-------|------------------------------------------------------------------------|
| `clk`            | entrada   | 1     | Reloj de 50 MHz.                                                       |
| `reset_pressed`  | entrada   | 1     | Pulso del botón reset (A).                                             |
| `admin_pressed`  | entrada   | 1     | Pulso del botón admin (A).                                             |
| `test_pressed`   | entrada   | 1     | Pulso del botón de prueba (A).                                         |
| `ready`          | entrada   | 1     | Pulso: se completó un intento de 3 dígitos (`attempt_ctrl`).           |
| `match1`, `match2` | entrada | 1     | La ventana coincide con el espacio 1 o 2 y está ocupado (B).           |
| `valid1`, `valid2` | entrada | 1     | El espacio 1 o 2 está ocupado (B).                                     |
| `alu_result`     | entrada   | 3     | Velocidad calculada con los 3 dígitos (B).                             |
| `wait_done`      | entrada   | 1     | Pasó 1 s desde `timer_start` (`timer_travel`).                         |
| `travel_done`    | entrada   | 1     | Terminó el tiempo de viaje (`timer_travel`).                           |
| `state`          | salida    | 3     | Estado actual (D).                                                     |
| `mode`           | salida    | 3     | Submodo de admin: 0 normal, 1 espacio 1, 2 espacio 2 (D).              |
| `door_open_flag` | salida    | 1     | 1 si la puerta está abierta (D).                                       |
| `speed`          | salida    | 3     | Velocidad guardada (D, `timer_travel`).                                |
| `motor_dir`      | salida    | 2     | `10` abrir, `01` cerrar, `00` detener (D).                             |
| `bz_code`        | salida    | 3     | Código de sonido (D).                                                  |
| `bz_start`       | salida    | 1     | Pulso para sonidos finitos (D).                                        |
| `timer_start`    | salida    | 1     | Pulso: reinicia el contador (`timer_travel`).                          |
| `clear_capture`  | salida    | 1     | Limpia la ventana y el intento (A, `attempt_ctrl`).                    |
| `wr1`, `wr2`     | salida    | 1     | Pulso: guardar la ventana en el espacio 1 o 2 (B).                     |
| `del1`, `del2`   | salida    | 1     | Pulso: borrar el espacio 1 o 2 (B).                                    |
| `clear_all`      | salida    | 1     | Pulso: borrar todas las contraseñas (B).                               |

## Decisiones de diseño

1. Las 2 contraseñas son equivalentes. Cualquiera abre si la puerta está cerrada y cierra si está abierta.
2. En admin, el submodo escoge el espacio. Si la contraseña ingresada ya existe se borra, si no se guarda en ese espacio.
3. La contraseña se evalúa al completar un intento de 3 dígitos, lo que permite el sonido INVALID.
4. La operación de la ALU es el primer dígito, de 1 a 5.
5. `S_VALID` espera 1 s antes de mover para que se escuche el sonido VALID, que el sonido continuo del motor cancelaría.
6. El reset borra las contraseñas pero no detiene un movimiento en curso, para no perder la posición de la puerta.
7. Prioridad de eventos: `reset` > `admin` > `test` > `ready`.

## Estados

| Código | Estado      | Significado                       |
|--------|-------------|-----------------------------------|
| 0      | `S_ERROR`   | Sin contraseñas.                  |
| 1      | `S_CLOSED`  | Puerta cerrada.                   |
| 2      | `S_OPENING` | Abriendo.                         |
| 3      | `S_OPEN`    | Puerta abierta.                   |
| 4      | `S_CLOSING` | Cerrando.                         |
| 5      | `S_ADMIN`   | Administración.                   |
| 6      | `S_TEST`    | Prueba.                           |
| 7      | `S_VALID`   | Contraseña válida, espera 1 s.    |

## Tabla de transiciones

| Estado          | Condición                 | Siguiente          | Acción                                        |
|-----------------|---------------------------|--------------------|-----------------------------------------------|
| ERROR           | `rst`                     | ERROR              | Borrar contraseñas.                           |
| ERROR           | `adm`                     | ADMIN              | `mode ← 1`.                                   |
| ERROR           | `tst` y puerta cerrada    | TEST               | Fase 0.                                       |
| ERROR           | `ready`                   | ERROR              | INVALID.                                      |
| CLOSED/OPEN     | `rst`                     | ERROR              | Borrar contraseñas.                           |
| CLOSED/OPEN     | `adm`                     | ADMIN              | `mode ← 1`.                                   |
| CLOSED          | `tst`                     | TEST               | Fase 0.                                       |
| CLOSED/OPEN     | `ready` y `match`         | VALID              | Guardar velocidad.                            |
| CLOSED/OPEN     | `ready` y no `match`      | Igual              | INVALID.                                      |
| VALID           | `wait_done` y `speed` ≠ 0 | OPENING/CLOSING    | Arrancar motor.                               |
| VALID           | `wait_done` y `speed` = 0 | CLOSED/OPEN        | No se mueve.                                  |
| OPENING/CLOSING | `rst`                     | Igual              | Borrar contraseñas, el motor sigue.           |
| OPENING/CLOSING | `travel_done`             | OPEN/CLOSED*       | Motor apagado.                                |
| ADMIN           | `rst`                     | ERROR              | Borrar contraseñas.                           |
| ADMIN           | `mode` = 0                | CLOSED/OPEN*       | Salir.                                        |
| ADMIN           | `adm`                     | ADMIN              | `mode`: 1 → 2 → 0.                            |
| ADMIN           | `ready` y `match`         | ADMIN              | Borrar, REG_OK, `mode ← 0`.                   |
| ADMIN           | `ready` y no `match`      | ADMIN              | Guardar en espacio `mode`, REG_OK, `mode ← 0`.|
| TEST            | fase 0 y `travel_done`    | TEST               | Fase 1 (espera 1 s).                          |
| TEST            | fase 1 y `wait_done`      | TEST               | Fase 2 (cerrar).                              |
| TEST            | fase 2 y `travel_done`    | CLOSED*            | Fin.                                          |

\* Pasa a ERROR si no hay contraseñas registradas.