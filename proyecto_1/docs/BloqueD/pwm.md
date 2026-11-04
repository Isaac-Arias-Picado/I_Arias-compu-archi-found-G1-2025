# PWM — Control del ciclo de trabajo

## Interfaz

| Puerto | Direccion | Ancho | Funcion |
|---|---|---|---|
| clk | Entrada | 1 | Reloj principal |
| reset | Entrada | 1 | Apaga la salida; reinicia registros al flanco positivo |
| speed | Entrada | 3 | Velocidad solicitada de 0 a 7 |
| pwm_out | Salida | 1 | PWM hacia motor_ctrl |

Parametros por defecto: CLK_FREQ_HZ=50_000_000 y PWM_FREQ_HZ=1000.
En top deben enlazarse a config_pkg::CLK_FREQ_HZ y config_pkg::PWM_FREQ_HZ.
Los valores por defecto permiten probar pwm.sv sin copiar el paquete.
config_pkg no se modifica. No utiliza ticks del Bloque A.

Requisitos de parametrizacion: frecuencias positivas, division exacta de
CLK_FREQ_HZ entre PWM_FREQ_HZ y PERIOD_CYCLES >= 7. El diseno esta previsto
para los valores del proyecto; no valida configuraciones incorrectas.

## Periodo y tabla de salida

PERIOD_CYCLES = CLK_FREQ_HZ / PWM_FREQ_HZ = 50_000.
Cada ciclo dura 20 ns; cada periodo dura 1 ms. El contador recorre 0 a 49_999.
El umbral H(s) es el entero mas cercano a PERIOD_CYCLES*s/7.

| speed | Ciclos altos H(s) | Duty real |
|---|---|---|
| 0 | 0 | 0 % |
| 1 | 7143 | 14.286 % |
| 2 | 14286 | 28.572 % |
| 3 | 21429 | 42.858 % |
| 4 | 28571 | 57.142 % |
| 5 | 35714 | 71.428 % |
| 6 | 42857 | 85.714 % |
| 7 | 50000 | 100 % |

La salida es alta al inicio del periodo y baja cuando counter alcanza H(s).
El error de redondeo es menor que un ciclo. En 0 y 7 la salida es constante;
la frecuencia de 1 kHz se observa externamente en velocidades intermedias.
PWM controla energia aplicada, no garantiza proporcionalidad de velocidad mecanica.

## Registros y transiciones

| Condicion al flanco | counter siguiente | active_speed siguiente | running siguiente |
|---|---|---|---|
| reset=1 | 0 | 0 | 0 |
| reset=0 y running=0 | 0 | speed | 1 |
| reset=0 y counter=PERIOD_CYCLES-1 | 0 | speed | 1 |
| Otro caso | counter+1 | Mantener | 1 |

El primer flanco despues de liberar reset inicia el primer periodo y toma speed.
Un cambio posterior solo se toma al empezar el siguiente periodo. La entrada
speed debe estar sincronizada al reloj por el bloque que la produce.
reset debe permanecer activo durante al menos un flanco para reiniciar registros.
La salida se enmascara con reset incluso entre flancos.

## Ecuaciones estructurales

- period_end = (counter == PERIOD_CYCLES-1)
- count_en = running & ~period_end & ~reset
- counter_next = mascara(count_en) & (counter+1)
- load_speed = ~reset & (~running | period_end)
- hold_speed = ~reset & ~load_speed
- speed_next = (mascara(load_speed) & speed) | (mascara(hold_speed) & active_speed)
- running_next = ~reset
- threshold = OR de los umbrales constantes enmascarados por (active_speed == s)
- pwm_out = running & ~reset & (counter < threshold)

La suma, comparadores y mascaras se sintetizan como compuertas. Las divisiones
del umbral solo operan sobre constantes durante elaboracion. Los always_ff solo
almacenan valores siguientes. No hay if, case ni ternarios en el diseno.

## Pruebas en EDA Playground

1. Elegir SystemVerilog/Verilog y Aldec Riviera Pro si esta disponible.
2. Pegar src/pwm.sv en Design y testsbenchs/BloqueD/tb_pwm.sv en Testbench.
3. Activar Open EPWave after run y ejecutar. Top: tb_pwm.
4. Buscar el mensaje final PASS PWM, con 0 errores.
5. En EPWave agregar speed, reset, pwm_out y expected. Las dos ultimas deben coincidir.

El banco usa 50 MHz y tiempos reales: tarda aproximadamente 22 ms simulados.
Compara cada ciclo contra un modelo independiente y cuenta ciclos altos por
periodo. Prueba las ocho velocidades durante dos periodos cada una, cambios
sin reset a distintos puntos del periodo, reset entre flancos y reinicio.
Los estimulos cambian en flancos negativos para evitar carreras con el DUT.

Estado: pendiente de ejecutar en un simulador SystemVerilog. Registrar el
resultado real y guardar el transcript antes de marcarlo como aprobado.
