# buzzer_ctrl — Tonos y patrones

## Funcion e interfaz

Genera una onda cuadrada para un buzzer pasivo. La frecuencia determina el tono;
la envolvente determina la duracion de los beeps y silencios. No necesita ticks
del Bloque A: utiliza el reloj principal y contadores propios.

| Puerto | Direccion | Ancho | Funcion |
|---|---|---|---|
| clk | Entrada | 1 | Reloj principal, previsto 50 MHz |
| reset | Entrada | 1 | Apaga salida; borra registros al flanco positivo |
| event_code | Entrada | 3 | Codigo compatible con buzzer_event_t de config_pkg |
| event_start | Entrada | 1 | Pulso de un ciclo para iniciar un aviso finito |
| buzzer_out | Salida | 1 | Onda cuadrada activa alta |

Las entradas deben estar sincronizadas al reloj. reset debe abarcar un flanco.
En top enlazar los nueve parametros a las constantes homonimas de config_pkg.
Los valores por defecto son autonomos y corresponden a los tiempos nominales
previstos a 50 MHz. No se modifica ni se importa config_pkg.
Todos los semiperiodos y duraciones deben ser enteros positivos, al menos 1.

## Eventos y prioridad

| Codigo | Evento | Frecuencia nominal | Patron |
|---|---|---|---|
| 0 | NONE | - | Sin continuo; con event_start cancela el aviso finito |
| 1 | TEST | 1000 Hz | Continuo mientras event_code=1 |
| 2 | REG_OK | 1000 Hz | Un beep de 100 ms |
| 3 | VALID | 1000 Hz | 100 ms sonido, 100 ms silencio, 100 ms sonido |
| 4 | INVALID | 500 Hz | Un beep de 500 ms |
| 5 | OPENING | 2000 Hz | Continuo mientras event_code=5 |
| 6 | CLOSING | Aproximadamente 1500 Hz | Continuo mientras event_code=6 |
| 7 | Reservado | - | Con event_start cancela; sin pulso no inicia aviso |

Los continuos no necesitan event_start. Los eventos 2, 3 y 4 se almacenan solo
al recibir event_start y terminan automaticamente, aunque event_code permanezca
igual o vuelva a NONE sin pulso. Un segundo pulso reinicia un aviso identico o
sustituye el anterior. No hay cola. Un continuo cancela el aviso finito; este no
se reanuda cuando termina el continuo. reset tiene prioridad sobre todo.
event_start debe durar un solo ciclo; mantenerlo activo reinicia el tono.

Contrato para Bloque C: si desea escuchar VALID completo antes de OPENING,
debe programar esa secuencia; si activa OPENING enseguida, el tono continuo
interrumpe VALID. TEST debe permanecer seleccionado durante toda la prueba,
incluida su espera intermedia.

## Parametros y frecuencia

BUZZER_*_HALF representa ciclos por semiperiodo. f_real=50_000_000/(2*HALF).
Los valores por defecto son 25000, 25000, 25000, 50000, 12500 y 16666 para
TEST, REG_OK, VALID, INVALID, OPENING y CLOSING. CLOSING resulta aproximadamente
1500.06 Hz por el redondeo a ciclos enteros.

BUZZER_BEEP_CYCLES=5_000_000, BUZZER_GAP_CYCLES=5_000_000,
BUZZER_INVALID_CYCLES=25_000_000. La duracion total de VALID es 15_000_000 ciclos.

Al integrar, revisar la aritmetica de config_pkg: sus expresiones originales
MS * CLK_FREQ_HZ pueden exceder un int de 32 bits antes de dividir entre 1000.
Los defaults de este modulo usan los valores nominales ya calculados; no
copiar automaticamente parametros de duracion sin verificar sus valores.

## Tabla de transicion del patron

Prioridad de arriba hacia abajo:

| Condicion | Activo siguiente | Codigo siguiente | Tiempo siguiente |
|---|---|---|---|
| reset | 0 | 0 | 0 |
| Evento continuo | 0 | 0 | 0 |
| event_start y codigo 2/3/4 | 1 | event_code | 0 |
| event_start y codigo 0/7 | 0 | 0 | 0 |
| Activo y ultimo ciclo | 0 | 0 | 0 |
| Activo, otro ciclo | 1 | Mantener | Tiempo+1 |
| Inactivo | 0 | 0 | 0 |

La salida finita esta habilitada durante todo REG_OK/INVALID. En VALID se
habilita cuando elapsed < BEEP o elapsed >= BEEP+GAP. Al completar la duracion
total se desactiva. El contador de tono recorre 0 a 2*HALF-1 y la salida es alta
en su primera mitad. Se reinicia con event_start, cambios de continuo y silencio.

## Ecuaciones de implementacion

- finite_start = ~reset & ~continuous & event_start & finite_valid
- cancel_pattern = reset | continuous | event_start
- pattern_next = finite_start | (pattern_active & ~pattern_done & ~cancel_pattern)
- elapsed_next = mascara(pattern_active & ~pattern_done & ~cancel_pattern) & (elapsed+1)
- code_next = OR de codigo nuevo y anterior bajo sus mascaras de carga/retencion
- tone_enable = ~reset & (continuous | finite_sound)
- tone_next = mascara(tone_enable & ~event_start & ~continuous_changed & ~tone_end) & (tone_counter+1)
- buzzer_out = tone_enable & (tone_counter < half_period)

Duracion y semiperiodo se seleccionan por decodificacion y mascaras. Los registros
solo almacenan valores siguientes; no se usan if, case ni ternarios en el diseno.
La tabla de salida de tono es alta para contador < HALF y baja en el resto.

## EDA Playground y pruebas

1. SystemVerilog/Verilog; Aldec Riviera Pro si esta disponible.
2. Design: src/buzzer_ctrl.sv. No necesita otros modulos ni config_pkg.
3. Testbench: testsbenchs/BloqueD/tb_buzzer_ctrl.sv. Top: tb_buzzer_ctrl.
4. Activar Open EPWave after run y ejecutar.
5. Resultado esperado: PASS BUZZER_CTRL: ... comprobaciones, 0 errores.

Agregar event_code, event_start, reset, buzzer_out y expected en EPWave.
El banco acelera los tiempos mediante parametros: semiperiodos 5/5/5/10/3/4,
BEEP=40, GAP=20, INVALID=100 ciclos. No son frecuencias reales de audio.
La prueba compara cada ciclo con una referencia de intervalos temporales y
verifica tonos, pausas, terminacion, ausencia de repeticion automatica,
repeticion con pulso, sustitucion, prioridad continua, cancelacion y reset.
La validacion de frecuencias nominales con parametros por defecto queda pendiente,
asi como la prueba fisica con el buzzer y su etapa de conexion.

Estado: banco preparado; pendiente ejecutar simulacion HDL. No marcar PASS hasta
tener el transcript real.
