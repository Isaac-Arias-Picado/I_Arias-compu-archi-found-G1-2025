# debounce

## Propósito

Limpia las entradas de botones y del detector de dedos. En los botones solo sincroniza y detecta flancos. En los dedos filtra la señal durante 20 ms, valida que haya como máximo un dedo activo y codifica el resultado a un símbolo de 0 a 5.

## Interfaz

| Puerto          | Dirección | Ancho | Descripción                                                              |
|-----------------|-----------|-------|--------------------------------------------------------------------------|
| `clk`           | entrada   | 1     | Reloj de 50 MHz.                                                         |
| `reset`         | entrada   | 1     | Reset síncrono del filtro de dedos y de los pulsos de admin y test.      |
| `tick_debounce` | entrada   | 1     | Pulso de 1 kHz que avanza el filtro de dedos.                            |
| `btn_admin`     | entrada   | 1     | Señal cruda del botón de administrador.                                  |
| `btn_test`      | entrada   | 1     | Señal cruda del botón de prueba.                                         |
| `btn_reset`     | entrada   | 1     | Señal cruda del botón de reset.                                          |
| `finger_raw`    | entrada   | 5     | Señales crudas de los sensores de dedo, un bit por sensor.               |
| `admin_pressed` | salida    | 1     | Pulso de un ciclo al presionar el botón de administrador.                |
| `test_pressed`  | salida    | 1     | Pulso de un ciclo al presionar el botón de prueba.                       |
| `reset_pressed` | salida    | 1     | Pulso de un ciclo al presionar el botón de reset.                        |
| `finger_valid`  | salida    | 1     | Vale 1 cuando `stable` no tiene bits activos o tiene solo uno.           |
| `finger_symbol` | salida    | 3     | Símbolo 0-5 del dedo estable.                                            |

## Dos caminos distintos

### Botones

Los tres botones pasan por dos flip-flops de sincronización y un detector de flanco que usa `admin_prev`, `test_prev` y `reset_prev`. La FPGA tiene Schmitt trigger, así que no se aplica filtro de 20 ms. Los flip-flops de sincronización no se resetean con `reset` para no cancelar `reset_pressed`. En cambio, `admin_pressed` y `test_pressed` sí se enmascaran con `~reset`.

### Detector de dedos

La señal viene de hardware externo sin Schmitt trigger, por lo que necesita un filtro de 20 ms. El proceso tiene cuatro pasos:

1. Sincronización con dos flip-flops (`finger_ff1` y `finger_ff2`).
2. Filtro de estabilidad: el valor debe mantenerse durante 20 muestras consecutivas a 1 kHz.
3. Validación: `popcount(stable)` debe ser menor o igual a 1.
4. Codificación a símbolo 0-5.

## Filtro de estabilidad

Variables del filtro:

- `candidate` (5 bits): valor que se está observando.
- `count` (5 bits, `STAB_BITS`): número de muestras consecutivas iguales a `candidate`.
- `stable` (5 bits): valor confirmado que consumen la validación y el encoder.

`DEBOUNCE_SAMPLES` vale 20. Las cuatro transiciones ocurren solo cuando `tick_debounce` = 1. En cualquier otro ciclo el filtro mantiene sus valores.

| Condición                                              | `candidate`    | `count`   | `stable`          |
|--------------------------------------------------------|----------------|-----------|-------------------|
| `reset` = 1                                            | `00000`        | 0         | `00000`           |
| `raw_sync` distinto de `candidate`                     | `raw_sync`     | 1         | Sin cambio        |
| `raw_sync` igual a `candidate` y `count` < 19          | Sin cambio     | `count` + 1 | Sin cambio      |
| `raw_sync` igual a `candidate` y `count` = 19          | Sin cambio     | 20        | `candidate`       |

Con `count` = 20 el contador se satura: `raw_sync` igual a `candidate` no cambia nada. Así, `stable` se actualiza cuando se completan 20 muestras iguales seguidas.

## Validación y codificación

Ecuaciones:

popcount = stable[0] + stable[1] + stable[2] + stable[3] + stable[4]

finger_valid = (popcount ≤ 1)

finger_symbol[0] = stable[0] ∨ stable[2] ∨ stable[4]

finger_symbol[1] = stable[1] ∨ stable[2]

finger_symbol[2] = stable[3] ∨ stable[4]

Tabla de codificación:

| `stable[4:0]` | `finger_symbol[2:0]` | Significado         |
|---------------|----------------------|---------------------|
| `00000`       | `000`                | Sin dedo presente   |
| `00001`       | `001`                | Símbolo 1           |
| `00010`       | `010`                | Símbolo 2           |
| `00100`       | `011`                | Símbolo 3           |
| `01000`       | `100`                | Símbolo 4           |
| `10000`       | `101`                | Símbolo 5           |

Cualquier valor con dos o más bits activos da `finger_valid` = 0. En ese caso `finger_symbol` no es válido y `finger_capture` lo descarta.

## Verificación

| Test                        | Verifica                                                                                         | Resultado |
|-----------------------------|--------------------------------------------------------------------------------------------------|-----------|
| Flanco de `admin_pressed`   | Cada presión de `btn_admin` produce un único pulso.                                              | `PASS`    |
| Flanco de `test_pressed`    | Cada presión de `btn_test` produce un único pulso.                                               | `PASS`    |
| Flanco de `reset_pressed`   | Cada presión de `btn_reset` produce un único pulso.                                              | `PASS`    |
| Enmascaramiento             | `admin_pressed` y `test_pressed` quedan en 0 mientras `reset` está activo.                       | `PASS`    |
| Sin filtro en botones       | Los botones no pasan por el filtro de 20 ms.                                                     | `PASS`    |
| Filtro de dedos             | Un valor distinto no llega a `stable` antes de 20 muestras consecutivas.                         | `PASS`    |
| Actualización de `stable`   | Después de 20 muestras iguales, `stable` toma ese valor.                                         | `PASS`    |
| Reinicio de `count`         | Un cambio durante el conteo reinicia `count` en 1.                                               | `PASS`    |
| Validación y codificación   | Dos o más dedos dan `finger_valid` = 0; un dedo produce el símbolo correspondiente.              | `PASS`    |
