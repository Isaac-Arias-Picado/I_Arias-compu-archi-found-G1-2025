# clk_enables

## Propósito

Genera pulsos de un ciclo de reloj a partir de los 50 MHz de `CLK_FREQ_HZ`, para que otros módulos muestreen a frecuencias bajas sin dividir el reloj. Produce `tick_capture` cada 2 s y `tick_debounce` y `tick_display` cada 1 ms (1 kHz).

## Interfaz

| Puerto         | Dirección | Ancho | Descripción                                                              |
|----------------|-----------|-------|--------------------------------------------------------------------------|
| `clk`          | entrada   | 1     | Reloj de 50 MHz.                                                         |
| `reset`        | entrada   | 1     | Reset síncrono; pone los contadores y los ticks en 0.                    |
| `tick_capture` | salida    | 1     | Pulso de un ciclo cada `CAPTURE_CYCLES` ciclos.                          |
| `tick_debounce`| salida    | 1     | Pulso de un ciclo cada `DEBOUNCE_CYCLES` ciclos.                         |
| `tick_display` | salida    | 1     | Pulso de un ciclo cada `DEBOUNCE_CYCLES` ciclos.                         |

## Decisiones de diseño

1. Contador compartido entre debounce y display, ambos a 1 kHz. Ahorra flip-flops: un solo contador de `SHARED_BITS` bits en lugar de dos.
2. Reset síncrono mediante la habilitación `en = ~reset & ~is_max`. Es una restricción estructural: el reset entra por la lógica del contador y no por una entrada asíncrona.
3. El primer tick aparece después de un período completo y no de inmediato. El contador arranca en 0 y el tick se activa cuando llega a su valor máximo.
4. Ticks combinacionales, sin registro extra. Cada tick sale de comparar el contador con su máximo y de `~reset`, así dura exactamente un ciclo.

## Parámetros

| Parámetro         | Valor       | Uso                                                              |
|-------------------|-------------|------------------------------------------------------------------|
| `CAPTURE_CYCLES`  | 100,000,000 | Ciclos entre pulsos de `tick_capture` (2 s a 50 MHz).            |
| `DEBOUNCE_CYCLES` | 50,000      | Ciclos entre pulsos de `tick_debounce` y `tick_display` (1 ms).  |

## Ecuaciones booleanas

CAP_BITS = clog2(CAPTURE_CYCLES) = 27

SHARED_BITS = clog2(DEBOUNCE_CYCLES) = 16

is_max_cap = (cap_cnt = CAPTURE_CYCLES − 1)

is_max_shared = (shared_cnt = DEBOUNCE_CYCLES − 1)

tick_capture = is_max_cap ∧ ¬reset

tick_debounce = is_max_shared ∧ ¬reset

tick_display = is_max_shared ∧ ¬reset

en_cap = ¬reset ∧ ¬is_max_cap

en_shared = ¬reset ∧ ¬is_max_shared

cnt_next_cap[i] = en_cap ∧ (cap_cnt + 1)[i], para i = 0 a CAP_BITS − 1

cnt_next_shared[i] = en_shared ∧ (shared_cnt + 1)[i], para i = 0 a SHARED_BITS − 1

## Comportamiento

| Evento                                   | Contador                                   | Tick                         |
|------------------------------------------|--------------------------------------------|------------------------------|
| `reset` = 1                              | Vuelve a 0 en el siguiente flanco.         | Ambos en 0.                  |
| Contando (contador menor que el máximo)  | Incrementa 1 en cada ciclo.                | Ambos en 0.                  |
| Wrap (`cap_cnt` = 99,999,999 o `shared_cnt` = 49,999) | Vuelve a 0 en el siguiente flanco. | En 1 durante ese ciclo.      |

## Verificación

| Test                  | Verifica                                                                                      | Resultado |
|-----------------------|-----------------------------------------------------------------------------------------------|-----------|
| Período de captura    | `tick_capture` se activa cada `CAPTURE_CYCLES` ciclos.                                        | `PASS`    |
| Período compartido    | `tick_debounce` y `tick_display` se activan cada `DEBOUNCE_CYCLES` ciclos y coinciden.       | `PASS`    |
| Reset                 | `reset` pone los contadores y los ticks en 0.                                                 | `PASS`    |
| Primer tick           | El primer tick aparece después de un período completo y no de inmediato.                     | `PASS`    |
