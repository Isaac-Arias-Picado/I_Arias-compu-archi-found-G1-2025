# comparator

## Propósito

Compara la ventana de captura contra las dos contraseñas guardadas. Genera `match1` y `match2`, que valen 1 cuando la ventana es igual a ese espacio y el espacio está ocupado.

## Interfaz

| Puerto   | Dirección | Ancho | Descripción                                          |
|----------|-----------|-------|------------------------------------------------------|
| `window` | entrada   | 9     | Ventana de 3 símbolos. Viene del bloque A.           |
| `pass1`  | entrada   | 9     | Contraseña del espacio 1. Viene de `password_mem`.   |
| `pass2`  | entrada   | 9     | Contraseña del espacio 2. Viene de `password_mem`.   |
| `valid1` | entrada   | 1     | Espacio 1 ocupado.                                   |
| `valid2` | entrada   | 1     | Espacio 2 ocupado.                                   |
| `match1` | salida    | 1     | La ventana coincide con el espacio 1.                |
| `match2` | salida    | 1     | La ventana coincide con el espacio 2.                |

Es lógica combinacional: no tiene reloj ni reset.

## Decisiones de diseño

1. La comparación es continua. No espera a que la ventana esté llena, como se definió en `finger_capture`.
2. Un espacio vacío nunca coincide. Sin `valid`, la ventana vacía (`000 000 000`) igualaría una memoria en 0 y daría un acierto falso.
3. Si las dos contraseñas guardadas fueran iguales, `match1` y `match2` valen 1 a la vez. Qué hacer en ese caso lo decide la FSM.
4. La igualdad se arma con XOR bit a bit y un OR de reducción, sin comparador de alto nivel.

## Ecuaciones booleanas

diff1[i] = window[i] ⊕ pass1[i], para i = 0 a 8

diff2[i] = window[i] ⊕ pass2[i], para i = 0 a 8

equal1 = ¬(diff1[0] ∨ diff1[1] ∨ … ∨ diff1[8])

equal2 = ¬(diff2[0] ∨ diff2[1] ∨ … ∨ diff2[8])

match1 = equal1 ∧ valid1

match2 = equal2 ∧ valid2

## Verificación

| Test                              | Verifica                                                                  | Resultado   |
|-----------------------------------|---------------------------------------------------------------------------|-------------|
| Solo espacio 1                    | La ventana igual a `pass1` da `match1` = 1 y `match2` = 0.                | `PASS` |
| Solo espacio 2                    | La ventana igual a `pass2` da `match2` = 1 y `match1` = 0.                | `PASS` |
| Ninguno                           | Una ventana distinta de ambos da los dos `match` en 0.                    | `PASS` |
| Mismo valor en ambos              | Con `pass1` = `pass2` = ventana, ambos `match` valen 1.                   | `PASS` |
| Espacio vacío                     | Con `valid` = 0 no hay `match` aunque el dato sea igual.                  | `PASS` |
| Ventana vacía                     | `000 000 000` contra espacios vacíos no coincide.                         | `PASS` |
| Un dígito distinto                | Cambiar el dígito viejo, el del medio o el nuevo anula el `match`.        | `PASS` |
| Barrido de 512 ventanas           | Solo `PW_A` activa `match1` y solo `PW_B` activa `match2`.                | `PASS` |