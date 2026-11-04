# Bloque B — Datos (cálculo y memoria)

Responsable: Byron Josué Bolaños Porras

| Módulo       | Archivo           | Función                                                                    |
|--------------|-------------------|----------------------------------------------------------------------------|
| alu          | `alu.sv`          | Calcula la velocidad de la puerta (0 a 7) a partir de los 3 dígitos.       |
| password_mem | `password_mem.sv` | Guarda dos contraseñas con sus banderas de validez.                        |
| comparator   | `comparator.sv`   | Compara la ventana con ambas contraseñas y genera `match1` y `match2`.     |

## Interfaces hacia otros bloques

### Entradas

| Señal          | Viene de | Uso                                                                      |
|----------------|----------|--------------------------------------------------------------------------|
| `window[8:0]`  | A        | Ventana de 3 símbolos. `[8:6]` es `op`, `[5:3]` es A y `[2:0]` es B.     |
| `wr1`, `wr2`   | C        | Pulso de un ciclo para guardar la ventana en el espacio 1 o 2.           |
| `del1`, `del2` | C        | Pulso de un ciclo para borrar el espacio 1 o 2.                          |
| `clear_all`    | C        | Pulso de un ciclo para borrar ambos espacios.                            |
| `reset`        | C / top  | Reset síncrono; vacía la memoria.                                        |

### Salidas

| Señal              | Va a | Uso                                                                  |
|--------------------|------|----------------------------------------------------------------------|
| `match1`, `match2` | C    | La ventana coincide con el espacio 1 o 2 (y está ocupado).           |
| `valid1`, `valid2` | C    | Espacio ocupado. Sin ninguno ocupado la FSM queda en `S_ERROR`.      |
| `result[2:0]`      | C, D | Velocidad `s` de 0 a 7 para el timer, el PWM y el display.           |

`pass1` y `pass2` solo conectan `password_mem` con `comparator` dentro del bloque.

## Conexión en `top.sv`

- `alu`: `op = window[8:6]`, `a = window[5:3]`, `b = window[2:0]`.
- `password_mem`: `window` entra completo; `pass1`, `pass2`, `valid1` y `valid2` van a `comparator`.
- `comparator`: `valid1` y `valid2` también van a la FSM.

## Documentos

- [alu](./alu.md)
- [password_mem](./password_mem.md)
- [comparator](./comparator.md)

## Simulaciones

Las formas de onda (waveform) y los transcript de cada testbench están en `docs/simulaciones/{modulo}/`, donde `{modulo}` es `alu`, `password_mem` o `comparator`.

## Estado

| Módulo       | TB                    | Tests | Estado      |
|--------------|-----------------------|-------|-------------|
| alu          | `tb_alu`              | 13    | `PASS` |
| password_mem | `tb_password_mem`     | 15    | `PASS` |
| comparator   | `tb_comparator`       | 11    | `PASS` |