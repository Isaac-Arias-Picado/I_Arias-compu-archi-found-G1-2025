# fsm_main

## Propósito

Máquina de estados principal. Recuerda si la puerta está abierta o cerrada, decide cuándo moverla, maneja la administración de contraseñas y la secuencia de prueba, y genera las órdenes para la memoria, el motor, el buzzer y el display.

## Interfaz

| Puerto             | Dirección | Ancho | Descripción                                                          |
|--------------------|-----------|-------|----------------------------------------------------------------------|
| `clk`              | entrada   | 1     | Reloj de 50 MHz.                                                     |
| `reset`            | entrada   | 1     | Reset de encendido (top). Pone todos los registros en 0.             |
| `rst`              | entrada   | 1     | Pulso del botón reset (A).                                           |
| `adm`              | entrada   | 1     | Pulso del botón admin (A).                                           |
| `tst`              | entrada   | 1     | Pulso del botón de prueba (A).                                       |
| `ready`            | entrada   | 1     | Pulso: se completó un intento de 3 dígitos (`attempt_ctrl`).         |
| `match1`, `match2` | entrada   | 1     | La ventana coincide con el espacio 1 o 2 y está ocupado (B).         |
| `valid1`, `valid2` | entrada   | 1     | El espacio 1 o 2 está ocupado (B).                                   |
| `alu_result`       | entrada   | 3     | Velocidad calculada con los 3 dígitos (B).                           |
| `wait_done`        | entrada   | 1     | Pasó 1 s desde `timer_start` (`timer_travel`).                       |
| `travel_done`      | entrada   | 1     | Terminó el tiempo de viaje (`timer_travel`).                         |
| `state`            | salida    | 3     | Estado actual (D).                                                   |
| `mode`             | salida    | 3     | Submodo de admin: 0 normal, 1 espacio 1, 2 espacio 2 (D).            |
| `door_open_flag`   | salida    | 1     | 1 si la puerta está abierta (D).                                     |
| `speed`            | salida    | 3     | Velocidad guardada (D, `timer_travel`).                              |
| `motor_dir`        | salida    | 2     | `10` abrir, `01` cerrar, `00` detener (D).                           |
| `bz_code`          | salida    | 3     | Código de sonido (D).                                                |
| `bz_start`         | salida    | 1     | Pulso para sonidos finitos (D).                                      |
| `timer_start`      | salida    | 1     | Pulso: reinicia el contador (`timer_travel`).                        |
| `clear_capture`    | salida    | 1     | Limpia la ventana y el intento (A, `attempt_ctrl`).                  |
| `wr1`, `wr2`       | salida    | 1     | Pulso: guardar la ventana en el espacio 1 o 2 (B).                   |
| `del1`, `del2`     | salida    | 1     | Pulso: borrar el espacio 1 o 2 (B).                                  |
| `clear_all`        | salida    | 1     | Pulso: borrar todas las contraseñas (B).                             |

## Decisiones de diseño

1. Las 2 contraseñas son equivalentes. Cualquiera abre si la puerta está cerrada y cierra si está abierta.
2. En admin, el submodo escoge el espacio. Si la contraseña ingresada ya existe se borra, si no se guarda en ese espacio.
3. La contraseña se evalúa al completar un intento de 3 dígitos, lo que permite el sonido INVALID.
4. La operación de la ALU es el primer dígito, de 1 a 5.
5. `S_VALID` espera 1 s antes de mover para que se escuche el sonido VALID, que el sonido continuo del motor cancelaría.
6. El reset borra las contraseñas pero no detiene un movimiento en curso, para no perder la posición de la puerta.
7. Prioridad de eventos: `rst` > `adm` > `tst` > `ready`. Cada fila lleva negadas las condiciones de las filas de arriba de su mismo estado.
8. Cada registro tiene su propio hold. Si ninguna fila lo carga, mantiene su valor. `mode` solo se mantiene en ADMIN y `tphase` solo en TEST, fuera de esos estados valen 0.
9. Las filas que van a `S_ERROR` no aportan término a `state_next`, porque su código es 0. Solo apagan el hold.
10. Los sonidos continuos (OPENING, CLOSING, TEST) dependen del estado. Los finitos (VALID, INVALID, REG_OK) se piden con un pulso de `bz_start`.

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

## Registros

| Registro         | Ancho | Se carga en                                         | Si ninguna fila lo carga |
|------------------|-------|-----------------------------------------------------|--------------------------|
| `state`          | 3     | Toda fila que cambia de estado.                     | Se mantiene.             |
| `mode`           | 3     | Entrada a admin, botón admin, registro o borrado.   | Se mantiene solo en ADMIN. |
| `speed`          | 3     | Contraseña correcta (`alu_result`) o entrada a test (`TEST_SPEED`). | Se mantiene. |
| `tphase`         | 2     | Cambio de fase del test.                            | Se mantiene solo en TEST. |
| `door_open_flag` | 1     | Fin de un viaje de apertura o de cierre.            | Se mantiene.             |

## Tabla de transiciones

| Estado          | Condición                 | Señal      | Siguiente       | Acción                                                         |
|-----------------|---------------------------|------------|-----------------|----------------------------------------------------------------|
| ERROR           | `rst`                     | —          | ERROR           | `clear_all`, `clear_capture`.                                  |
| ERROR           | `adm`                     | `e_adm`    | ADMIN           | `mode ← 1`.                                                    |
| ERROR           | `tst` y puerta cerrada    | `e_tst`    | TEST            | `speed ← TEST_SPEED`, `timer_start`.                           |
| ERROR           | `ready`                   | `e_rdy`    | ERROR           | INVALID, `clear_capture`.                                      |
| CLOSED/OPEN     | `rst`                     | `co_rst`   | ERROR           | `clear_all`, `clear_capture`.                                  |
| CLOSED/OPEN     | `adm`                     | `co_adm`   | ADMIN           | `mode ← 1`.                                                    |
| CLOSED          | `tst`                     | `c_tst`    | TEST            | `speed ← TEST_SPEED`, `timer_start`.                           |
| CLOSED/OPEN     | `ready` y `match`         | `co_ok`    | VALID           | `speed ← alu_result`, VALID, `timer_start`, `clear_capture`.   |
| CLOSED/OPEN     | `ready` y no `match`      | `co_bad`   | Igual           | INVALID, `clear_capture`.                                      |
| VALID           | `rst`                     | `v_rst`    | ERROR           | `clear_all`.                                                   |
| VALID           | `wait_done` y `speed` ≠ 0 | `v_go`     | OPENING/CLOSING | `timer_start`.                                                 |
| VALID           | `wait_done` y `speed` = 0 | `v_stay`   | CLOSED/OPEN     | No se mueve.                                                   |
| OPENING/CLOSING | `rst`                     | —          | Igual           | `clear_all`, el motor sigue.                                   |
| OPENING         | `travel_done`             | `opg_done` | OPEN*           | `door_open_flag ← 1`.                                          |
| CLOSING         | `travel_done`             | `clg_done` | CLOSED*         | `door_open_flag ← 0`.                                          |
| ADMIN           | `rst`                     | `a_rst`    | ERROR           | `clear_all`, `clear_capture`, `mode ← 0`.                      |
| ADMIN           | `mode` = 0                | `a_exit`   | CLOSED/OPEN*    | Salir.                                                         |
| ADMIN           | `adm`                     | `a_adm`    | ADMIN           | `mode`: 1 → 2 → 0.                                             |
| ADMIN           | `ready` y `match`         | `a_del`    | ADMIN           | Borrar el espacio que coincide, REG_OK, `mode ← 0`.            |
| ADMIN           | `ready` y no `match`      | `a_wr`     | ADMIN           | Guardar en el espacio `mode`, REG_OK, `mode ← 0`.              |
| TEST            | `rst`                     | —          | Igual           | `clear_all`, el test sigue.                                    |
| TEST            | fase 0 y `travel_done`    | `t_p0`     | TEST            | `tphase ← 1` (espera 1 s), `timer_start`.                      |
| TEST            | fase 1 y `wait_done`      | `t_p1`     | TEST            | `tphase ← 2` (cerrar), `timer_start`.                          |
| TEST            | fase 2 y `travel_done`    | `t_end`    | CLOSED*         | `tphase ← 0`.                                                  |

\* Pasa a ERROR si no hay contraseñas registradas.

Mientras está en VALID, OPENING, CLOSING o TEST, `clear_capture` = 1 para que nadie arranque un intento a medias.

## Ecuaciones booleanas

Decodificación:

is_error = (state = S_ERROR), is_closed = (state = S_CLOSED), y así con los 8 estados

m0 = (mode = 0), m1 = (mode = 1), m2 = (mode = 2)

ph0 = (tphase = 0), ph1 = (tphase = 1), ph2 = (tphase = 2)

spd0 = (speed = 0)

match = match1 ∨ match2

has_pw = valid1 ∨ valid2

co = is_closed ∨ is_open

Filas:

e_adm = is_error ∧ ¬rst ∧ adm

e_tst = is_error ∧ ¬rst ∧ ¬adm ∧ tst ∧ ¬door_open_flag

e_rdy = is_error ∧ ¬rst ∧ ¬adm ∧ ¬(tst ∧ ¬door_open_flag) ∧ ready

co_rst = co ∧ rst

co_adm = co ∧ ¬rst ∧ adm

c_tst = is_closed ∧ ¬rst ∧ ¬adm ∧ tst

co_ok = co ∧ ¬rst ∧ ¬adm ∧ ¬(is_closed ∧ tst) ∧ ready ∧ match

co_bad = co ∧ ¬rst ∧ ¬adm ∧ ¬(is_closed ∧ tst) ∧ ready ∧ ¬match

v_rst = is_valid ∧ rst

v_go = is_valid ∧ ¬rst ∧ wait_done ∧ ¬spd0

v_stay = is_valid ∧ ¬rst ∧ wait_done ∧ spd0

opg_done = is_opening ∧ ¬rst ∧ travel_done

clg_done = is_closing ∧ ¬rst ∧ travel_done

a_rst = is_admin ∧ rst

a_exit = is_admin ∧ ¬rst ∧ m0

a_adm = is_admin ∧ ¬rst ∧ ¬m0 ∧ adm

a_del = is_admin ∧ ¬rst ∧ ¬m0 ∧ ¬adm ∧ ready ∧ match

a_wr = is_admin ∧ ¬rst ∧ ¬m0 ∧ ¬adm ∧ ready ∧ ¬match

t_p0 = is_test ∧ ¬rst ∧ ph0 ∧ travel_done

t_p1 = is_test ∧ ¬rst ∧ ph1 ∧ wait_done

t_end = is_test ∧ ¬rst ∧ ph2 ∧ travel_done

Estado:

hold_st = ¬(e_adm ∨ e_tst ∨ co_rst ∨ co_adm ∨ c_tst ∨ co_ok ∨ v_rst ∨ v_go ∨ v_stay ∨ opg_done ∨ clg_done ∨ a_rst ∨ a_exit ∨ t_end)

state_next = ¬reset ∧ ((e_adm ∨ co_adm) ∧ S_ADMIN ∨ (e_tst ∨ c_tst) ∧ S_TEST ∨ co_ok ∧ S_VALID ∨ (v_go ∧ ¬door_open_flag) ∧ S_OPENING ∨ (v_go ∧ door_open_flag) ∧ S_CLOSING ∨ (v_stay ∧ ¬door_open_flag) ∧ S_CLOSED ∨ (v_stay ∧ door_open_flag) ∧ S_OPEN ∨ (opg_done ∧ has_pw) ∧ S_OPEN ∨ (clg_done ∧ has_pw) ∧ S_CLOSED ∨ (a_exit ∧ has_pw ∧ ¬door_open_flag) ∧ S_CLOSED ∨ (a_exit ∧ has_pw ∧ door_open_flag) ∧ S_OPEN ∨ (t_end ∧ has_pw) ∧ S_CLOSED ∨ hold_st ∧ state)

Demás registros:

mode_hold = is_admin ∧ ¬rst ∧ ¬m0 ∧ ¬adm ∧ ¬ready

mode_next = ¬reset ∧ ((e_adm ∨ co_adm) ∧ M_SLOT1 ∨ (a_adm ∧ m1) ∧ M_SLOT2 ∨ mode_hold ∧ mode)

tphase_hold = is_test ∧ ¬(t_p0 ∨ t_p1 ∨ t_end)

tphase_next = ¬reset ∧ (t_p0 ∧ 1 ∨ t_p1 ∧ 2 ∨ tphase_hold ∧ tphase)

spd_hold = ¬(e_tst ∨ c_tst ∨ co_ok)

speed_next = ¬reset ∧ (co_ok ∧ alu_result ∨ (e_tst ∨ c_tst) ∧ TEST_SPEED ∨ spd_hold ∧ speed)

door_next = ¬reset ∧ (opg_done ∨ (door_open_flag ∧ ¬clg_done))

Salidas:

motor_dir[1] = is_opening ∨ (is_test ∧ ph0)

motor_dir[0] = is_closing ∨ (is_test ∧ ph2)

bz_start = co_ok ∨ e_rdy ∨ co_bad ∨ a_del ∨ a_wr

bz_code = is_opening ∧ BZ_OPENING ∨ is_closing ∧ BZ_CLOSING ∨ is_test ∧ BZ_TEST ∨ co_ok ∧ BZ_VALID ∨ (e_rdy ∨ co_bad) ∧ BZ_INVALID ∨ (a_del ∨ a_wr) ∧ BZ_REG_OK

timer_start = e_tst ∨ c_tst ∨ co_ok ∨ v_go ∨ t_p0 ∨ t_p1

clear_capture = rst ∨ e_rdy ∨ co_ok ∨ co_bad ∨ a_del ∨ a_wr ∨ is_valid ∨ is_opening ∨ is_closing ∨ is_test

wr1 = a_wr ∧ m1, wr2 = a_wr ∧ m2

del1 = a_del ∧ match1, del2 = a_del ∧ match2

clear_all = rst

## Verificación

El testbench usa `timer_travel` real y un modelo simple de la memoria del bloque B. El tick de 1 ms se acelera a uno cada 2 ciclos.

| Test | Verifica                                                                              | Resultado |
|------|---------------------------------------------------------------------------------------|-----------|
| 1    | Al encender queda en ERROR, puerta cerrada y motor quieto.                            | `PASS`    |
| 2    | En ERROR un intento suena INVALID y no cambia de estado.                              | `PASS`    |
| 3    | Admin entra en el submodo 1, guarda en el espacio 1 con REG_OK y sale a CLOSED.       | `PASS`    |
| 4    | Una contraseña incorrecta suena INVALID y la puerta no cambia.                        | `PASS`    |
| 5    | La contraseña correcta pasa a VALID, abre después de 1 s y queda OPEN.                | `PASS`    |
| 6    | Con la puerta abierta la misma contraseña cierra y queda CLOSED.                      | `PASS`    |
| 7    | Con velocidad 0 pasa a VALID y vuelve a CLOSED sin moverse.                           | `PASS`    |
| 8    | El botón admin pasa al submodo 2, guarda en el espacio 2 y rotar 1 → 2 → 0 sale.      | `PASS`    |
| 9    | La contraseña del espacio 2 también abre.                                             | `PASS`    |
| 10   | El botón de prueba se ignora con la puerta abierta.                                   | `PASS`    |
| 11   | En admin, repetir una contraseña la borra y sale a OPEN porque queda otra.            | `PASS`    |
| 12   | La contraseña borrada suena INVALID.                                                  | `PASS`    |
| 13   | Reset durante el cierre borra las contraseñas, el motor sigue y al terminar pasa a ERROR. | `PASS` |
| 14   | La prueba abre a `TEST_SPEED`, espera, cierra y sin contraseñas termina en ERROR.     | `PASS`    |
| 15   | Con reset y admin en el mismo ciclo gana el reset.                                    | `PASS`    |
| 16   | Borrar la última contraseña regresa a ERROR.                                          | `PASS`    |

Los 16 tests suman 30 comprobaciones, todas en `PASS` en Questa.