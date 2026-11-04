# finger_capture

## Propósito

Mantiene una ventana de 3 símbolos de dedo. El bloque B compara `window` con las contraseñas de forma continua: no espera a que la ventana esté llena.

## Interfaz

| Puerto          | Dirección | Ancho | Descripción                                                                      |
|-----------------|-----------|-------|----------------------------------------------------------------------------------|
| `clk`           | entrada   | 1     | Reloj de 50 MHz.                                                                 |
| `reset`         | entrada   | 1     | Reset síncrono; vacía la ventana.                                                |
| `tick_capture`  | entrada   | 1     | Pulso de un ciclo cada 2 s; único momento en que la ventana puede desplazarse.   |
| `finger_valid`  | entrada   | 1     | Vale 1 cuando el símbolo actual es válido.                                       |
| `finger_symbol` | entrada   | 3     | Símbolo 0-5 del dedo actual.                                                     |
| `clear_capture` | entrada   | 1     | Limpia la ventana. Viene de C.                                                   |
| `window`        | salida    | 9     | Ventana de 3 símbolos de 3 bits.                                                 |

Layout de `window`: `[8:6]` es el símbolo más viejo, `[5:3]` el del medio y `[2:0]` el más nuevo.

## Comportamiento

| Condición                                              | `window` siguiente                                                      |
|--------------------------------------------------------|-------------------------------------------------------------------------|
| `reset` = 1 o `clear_capture` = 1                      | `000 000 000`                                                           |
| `tick_capture` = 1 y `finger_valid` = 1                | Desplaza: entra `finger_symbol` y sale el símbolo más viejo.            |
| `finger_valid` = 0 o `tick_capture` = 0                | Mantiene el valor actual.                                               |

Los símbolos con `finger_valid` = 0 se ignoran para que una lectura errónea no entre en la ventana ni desplace un símbolo válido.

## Ecuaciones booleanas

clear_all = reset ∨ clear_capture

shift_en = tick_capture ∧ finger_valid ∧ ¬clear_all

shifted = window[5:0] ∥ finger_symbol (concatenación de 9 bits)

mask_shift = shift_en

mask_hold = ¬shift_en ∧ ¬clear_all

window_next[i] = (mask_shift ∧ shifted[i]) ∨ (mask_hold ∧ window[i]), para i = 0 a 8

## Comportamiento típico

Partiendo de una ventana limpia (`000 000 000`):

| Tick | `finger_symbol` | `finger_valid` | `window`            |
|------|-----------------|----------------|---------------------|
| 1    | `001`           | 1              | `000 000 001`       |
| 2    | `010`           | 1              | `000 001 010`       |
| 3    | `011`           | 1              | `001 010 011`       |
| 4    | `100`           | 1              | `010 011 100`       |
| 5    | `100`           | 0              | `010 011 100` (sin cambio) |

La comparación es continua: `window` tiene valor en todo momento, incluso con la ventana parcialmente llena. Los ceros iniciales forman parte del valor.

## Verificación

| Test                        | Verifica                                                                                  | Resultado |
|-----------------------------|-------------------------------------------------------------------------------------------|-----------|
| Reset                       | `reset` lleva `window` a `000 000 000`.                                                   | `PASS`    |
| Clear                       | `clear_capture` lleva `window` a `000 000 000`.                                           | `PASS`    |
| Desplazamiento válido       | Con `tick_capture` y `finger_valid` en 1 entra `finger_symbol` y sale el símbolo más viejo. | `PASS` |
| Ignorar `finger_valid` = 0  | Con `finger_valid` en 0 `window` no cambia.                                               | `PASS`    |
| Secuencia de 4 símbolos     | Cuatro desplazamientos válidos dejan los últimos 3 símbolos en el orden correcto.          | `PASS`    |
| Sin `tick_capture`          | Sin `tick_capture` `window` no cambia aunque `finger_valid` sea 1.                         | `PASS`    |
