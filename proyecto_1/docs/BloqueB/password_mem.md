# password_mem

## Propósito

Guarda hasta dos contraseñas de 3 dígitos en dos espacios equivalentes, cada uno con su bandera de validez. La FSM del bloque C escribe, borra o limpia mediante pulsos de un ciclo.

## Interfaz

| Puerto      | Dirección | Ancho | Descripción                                                           |
|-------------|-----------|-------|-----------------------------------------------------------------------|
| `clk`       | entrada   | 1     | Reloj de 50 MHz.                                                      |
| `reset`     | entrada   | 1     | Reset síncrono; vacía ambos espacios.                                 |
| `window`    | entrada   | 9     | Ventana de captura que se guarda al escribir. Viene del bloque A.     |
| `wr1`       | entrada   | 1     | Pulso: guarda `window` en el espacio 1. Viene de C.                   |
| `wr2`       | entrada   | 1     | Pulso: guarda `window` en el espacio 2. Viene de C.                   |
| `del1`      | entrada   | 1     | Pulso: borra el espacio 1. Viene de C.                                |
| `del2`      | entrada   | 1     | Pulso: borra el espacio 2. Viene de C.                                |
| `clear_all` | entrada   | 1     | Pulso: borra ambos espacios. Viene de C.                              |
| `pass1`     | salida    | 9     | Contraseña del espacio 1.                                             |
| `pass2`     | salida    | 9     | Contraseña del espacio 2.                                             |
| `valid1`    | salida    | 1     | Vale 1 si el espacio 1 está ocupado.                                  |
| `valid2`    | salida    | 1     | Vale 1 si el espacio 2 está ocupado.                                  |

## Decisiones de diseño

1. Los dos espacios son equivalentes. Qué significa cada uno (abrir o cerrar) lo decide la FSM, no la memoria.
2. Prioridad por espacio: borrado (`reset`, `clear_all` o `del`) sobre escritura, y escritura sobre mantener. Así un `wr` simultáneo con un borrado nunca deja datos a medias.
3. Al borrar se pone `pass` en 0 además de `valid` en 0, para que no quede un valor viejo en la salida.
4. Escribir sobre un espacio ocupado lo sobrescribe, como pide el modo de registro.
5. `reset` y `clear_all` hacen lo mismo. `reset` entra por la lógica de entrada de los registros, igual que en `finger_capture`.

## Tabla de transición (por espacio)

| `kill` | `wr` | Siguiente `pass`  | Siguiente `valid` |
|--------|------|-------------------|-------------------|
| 1      | X    | `000 000 000`     | 0                 |
| 0      | 1    | `window`          | 1                 |
| 0      | 0    | Sin cambio        | Sin cambio        |

`kill` = `reset` ∨ `clear_all` ∨ `del` del espacio.

## Ecuaciones booleanas

clear_any = reset ∨ clear_all

Espacio 1 (el espacio 2 es igual con `wr2` y `del2`):

kill1 = clear_any ∨ del1

load1 = wr1 ∧ ¬kill1

hold1 = ¬wr1 ∧ ¬kill1

pass1_next[i] = (load1 ∧ window[i]) ∨ (hold1 ∧ pass1[i]), para i = 0 a 8

valid1_next = load1 ∨ (hold1 ∧ valid1)

## Verificación

| Test                                  | Verifica                                                                  | Resultado   |
|---------------------------------------|---------------------------------------------------------------------------|-------------|
| Reset                                 | Tras `reset` ambos espacios quedan vacíos y en 0.                         | `PASS` |
| `wr1`                                 | Guarda la ventana, activa `valid1` y no toca el espacio 2.                | `PASS` |
| Mantener                              | Sin pulsos la memoria no cambia aunque `window` cambie.                   | `PASS` |
| `wr2`                                 | Guarda la ventana, activa `valid2` y no toca el espacio 1.                | `PASS` |
| Sobrescritura                         | `wr1` sobre un espacio ocupado reemplaza la contraseña.                   | `PASS` |
| `del1` y `del2`                       | Cada uno vacía solo su espacio.                                           | `PASS` |
| `wr1` y `wr2` simultáneos             | Se guardan ambos espacios en el mismo ciclo.                              | `PASS` |
| `clear_all`                           | Vacía ambos espacios.                                                     | `PASS` |
| `reset` con datos                     | Vacía ambos espacios.                                                     | `PASS` |
| Prioridad                             | `del`, `clear_all` y `reset` ganan sobre `wr` en el mismo ciclo.          | `PASS` |