# Bloque A — Sensado y captura

Responsable: Isaac Arias Picado

| Módulo         | Archivo            | Función                                                                 |
|----------------|--------------------|-------------------------------------------------------------------------|
| clk_enables    | `clk_enables.sv`   | Genera los ticks de un ciclo para captura, debounce y display.          |
| debounce       | `debounce.sv`      | Filtra botones y dedos, valida la entrada one-hot y la codifica a 0-5.  |
| finger_capture | `finger_capture.sv`| Mantiene la ventana de 3 símbolos para compararla con la contraseña.    |

## Interfaces hacia otros bloques

### Salidas

| Señal              | Va a | Uso                                                              |
|--------------------|------|------------------------------------------------------------------|
| `admin_pressed`    | C    | Pulso de un ciclo al presionar el botón de administrador.        |
| `test_pressed`     | C    | Pulso de un ciclo al presionar el botón de prueba.               |
| `reset_pressed`    | C    | Pulso de un ciclo al presionar el botón de reset.                |
| `finger_valid`     | B, C | Indica que el dedo detectado es válido (ninguno o un solo bit).  |
| `finger_symbol`    | B, C | Símbolo 0-5 del dedo estable.                                    |
| `window[8:0]`      | B, C | Ventana de 3 símbolos para compararla con la contraseña.         |
| `tick_display`     | D    | Pulso de 1 kHz para el refresco del display.                     |

### Entradas

| Señal           | Viene de | Uso                                            |
|-----------------|----------|------------------------------------------------|
| `clear_capture` | C        | Limpia la ventana de captura.                  |
| `reset`         | C / top  | Reset síncrono de todo el bloque.              |

## Documentos

- [clk_enables](./clk_enables.md)
- [debounce](./debounce.md)
- [finger_capture](./finger_capture.md)

## Simulaciones

Las formas de onda (waveform) y los transcript de cada testbench están en `docs/simulaciones/{modulo}/`, donde `{modulo}` es `clk_enables`, `debounce` o `finger_capture`.

## Estado

| Módulo         | TB                  | Tests | Estado |
|----------------|---------------------|-------|--------|
| clk_enables    | `tb_clk_enables`    | 4     | `PASS` |
| debounce       | `tb_debounce`       | 9     | `PASS` |
| finger_capture | `tb_finger_capture` | 6     | `PASS` |
