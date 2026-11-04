# attempt_ctrl

## Propósito

Detecta cuándo se completa un intento de contraseña de 3 dígitos. El intento empieza con el primer dígito distinto de 0 y termina al capturar el tercero. En ese momento genera `ready` para que la FSM evalúe la contraseña.

## Interfaz

| Puerto          | Dirección | Ancho | Descripción                                            |
|-----------------|-----------|-------|--------------------------------------------------------|
| `clk`           | entrada   | 1     | Reloj de 50 MHz.                                       |
| `reset`         | entrada   | 1     | Reset de encendido.                                    |
| `tick_capture`  | entrada   | 1     | Pulso cada 2 s (A).                                    |
| `finger_valid`  | entrada   | 1     | El patrón de dedos es válido (A).                      |
| `finger_symbol` | entrada   | 3     | Dígito capturado (A).                                  |
| `clear_capture` | entrada   | 1     | Cancela el intento (FSM).                              |
| `ready`         | salida    | 1     | Pulso de un ciclo: se completó un intento (FSM).       |

## Comportamiento

| Contador | Captura válida con dígito ≠ 0 | Captura válida con dígito 0 |
|----------|-------------------------------|-----------------------------|
| 0        | Pasa a 1                      | Se queda en 0               |
| 1        | Pasa a 2                      | Pasa a 2                    |
| 2        | Pasa a 0 y genera `ready`     | Pasa a 0 y genera `ready`   |

`reset` o `clear_capture` ponen el contador en 0.

`ready` sale un ciclo después de la tercera captura, porque en ese mismo flanco la ventana de `finger_capture` guarda el tercer dígito.