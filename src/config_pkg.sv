// config_pkg.sv
package config_pkg;

    // Reloj
    parameter int CLK_FREQ_HZ = 50_000_000;

    // Contraseña
    parameter int PW_LEN          = 3;   // 3 digitos
    parameter int PW_DIGIT_BITS   = 3;   // cada digito 0-5 -> 3 bits
    parameter int PW_DIGIT_MAX    = 5;
    parameter int PW_WINDOW_BITS  = PW_LEN * PW_DIGIT_BITS;  // 9 bits

    //  Captura de dedos 
    parameter int CAPTURE_TIME_S = 2;
    parameter int CAPTURE_CYCLES = CAPTURE_TIME_S * CLK_FREQ_HZ;

    // Debounce 
    parameter int DEBOUNCE_TICK_HZ  = 1000;                              // 1 kHz
    parameter int DEBOUNCE_CYCLES   = CLK_FREQ_HZ / DEBOUNCE_TICK_HZ;
    parameter int DEBOUNCE_MS       = 20;
    parameter int DEBOUNCE_SAMPLES  = (DEBOUNCE_MS * DEBOUNCE_TICK_HZ) / 1000;  // 20

    // Display 
    parameter int DISPLAY_REFRESH_HZ = 1000;
    parameter int DISPLAY_CYCLES     = CLK_FREQ_HZ / DISPLAY_REFRESH_HZ;
    parameter int DISPLAY_NUM_HEX    = 6;

    // PWM
    parameter int PWM_FREQ_HZ        = 100;                          // 100 Hz
    parameter int PWM_COUNTER_MAX    = CLK_FREQ_HZ / PWM_FREQ_HZ;
    parameter int PWM_SPEED_BITS     = 3;                            // 0-7
    parameter int PWM_SPEED_MAX      = 7;

    // Viaje de puerta
    // T(s) = T_MAX_MS * 7 / s  (s = 1..7), en milisegundos.
    // El timer cuenta ticks de 1 ms, por eso los tiempos van en ms.
    // T_MAX_S es provisional: se calibra midiendo la maqueta.
    parameter int T_MAX_S       = 4;                  // 4 s a 100 %
    parameter int T_MAX_MS      = T_MAX_S * 1000;
    parameter int TRAVEL_MS_1   = T_MAX_MS * 7;       // 28000
    parameter int TRAVEL_MS_2   = T_MAX_MS * 7 / 2;   // 14000
    parameter int TRAVEL_MS_3   = T_MAX_MS * 7 / 3;   // 9333
    parameter int TRAVEL_MS_4   = T_MAX_MS * 7 / 4;   // 7000
    parameter int TRAVEL_MS_5   = T_MAX_MS * 7 / 5;   // 5600
    parameter int TRAVEL_MS_6   = T_MAX_MS * 7 / 6;   // 4666
    parameter int TRAVEL_MS_7   = T_MAX_MS;           // 4000
    parameter int TRAVEL_MS_MAX = TRAVEL_MS_1;        // viaje mas largo, tope del contador

    // Test 
    parameter logic [2:0] TEST_SPEED    = 3'd4;   // ~50 %
    parameter int         TEST_WAIT_MS  = 1000;   // espera entre abrir y cerrar
    parameter int         TEST_WAIT_CYCLES = (CLK_FREQ_HZ / 1000) * TEST_WAIT_MS;

    // Buzzer 
    parameter int BUZZER_TEST_HZ    = 1000;
    parameter int BUZZER_REG_OK_HZ  = 1000;
    parameter int BUZZER_VALID_HZ   = 1000;
    parameter int BUZZER_INVALID_HZ = 500;
    parameter int BUZZER_OPENING_HZ = 800;
    parameter int BUZZER_CLOSING_HZ = 600;

    // Semi-periodos precalculados 
    parameter int BUZZER_TEST_HALF    = CLK_FREQ_HZ / (2 * BUZZER_TEST_HZ);
    parameter int BUZZER_REG_OK_HALF  = CLK_FREQ_HZ / (2 * BUZZER_REG_OK_HZ);
    parameter int BUZZER_VALID_HALF   = CLK_FREQ_HZ / (2 * BUZZER_VALID_HZ);
    parameter int BUZZER_INVALID_HALF = CLK_FREQ_HZ / (2 * BUZZER_INVALID_HZ);
    parameter int BUZZER_OPENING_HALF = CLK_FREQ_HZ / (2 * BUZZER_OPENING_HZ);
    parameter int BUZZER_CLOSING_HALF = CLK_FREQ_HZ / (2 * BUZZER_CLOSING_HZ);

    // Duraciones y patrones
    parameter int BUZZER_BEEP_MS        = 100;
    parameter int BUZZER_BEEP_CYCLES    = (CLK_FREQ_HZ / 1000) * BUZZER_BEEP_MS;
    parameter int BUZZER_INVALID_MS     = 500;
    parameter int BUZZER_INVALID_CYCLES = (CLK_FREQ_HZ / 1000) * BUZZER_INVALID_MS;
    parameter int BUZZER_GAP_MS         = 100;
    parameter int BUZZER_GAP_CYCLES     = (CLK_FREQ_HZ / 1000) * BUZZER_GAP_MS;

    //  Codificacion de estados 
    typedef enum logic [2:0] {
        S_ERROR   = 3'd0,
        S_CLOSED  = 3'd1,
        S_OPENING = 3'd2,
        S_OPEN    = 3'd3,
        S_CLOSING = 3'd4,
        S_ADMIN   = 3'd5,
        S_TEST    = 3'd6,
        S_VALID   = 3'd7
    } state_t;

    // Submodos de admin 
    typedef enum logic [2:0] {
        M_NORMAL = 3'd0,
        M_SLOT1  = 3'd1,
        M_SLOT2  = 3'd2
    } admin_mode_t;

    // Operaciones ALU 
    typedef enum logic [2:0] {
        OP_SUMA    = 3'd0,
        OP_RESTA   = 3'd1,
        OP_MULT    = 3'd2,
        OP_ROT_IZQ = 3'd3,
        OP_ROT_DER = 3'd4,
        OP_NULA    = 3'd5
    } alu_op_t;

    // Eventos de buzzer 
    typedef enum logic [2:0] {
        BZ_NONE    = 3'd0,
        BZ_TEST    = 3'd1,
        BZ_REG_OK  = 3'd2,
        BZ_VALID   = 3'd3,
        BZ_INVALID = 3'd4,
        BZ_OPENING = 3'd5,
        BZ_CLOSING = 3'd6
    } buzzer_event_t;

    // Direccion del motor 
    typedef enum logic [1:0] {
        MOTOR_STOP  = 2'b00,
        MOTOR_OPEN  = 2'b10,
        MOTOR_CLOSE = 2'b01
    } motor_dir_t;

    // Caracteres para display 
    // 0-F estandar + letras extendidas para estados y modos
    parameter logic [4:0] CHAR_0 = 5'h00;
    parameter logic [4:0] CHAR_1 = 5'h01;
    parameter logic [4:0] CHAR_2 = 5'h02;
    parameter logic [4:0] CHAR_3 = 5'h03;
    parameter logic [4:0] CHAR_4 = 5'h04;
    parameter logic [4:0] CHAR_5 = 5'h05;
    parameter logic [4:0] CHAR_6 = 5'h06;
    parameter logic [4:0] CHAR_7 = 5'h07;
    parameter logic [4:0] CHAR_8 = 5'h08;
    parameter logic [4:0] CHAR_9 = 5'h09;
    parameter logic [4:0] CHAR_A = 5'h0A;   // estado: abierta
    parameter logic [4:0] CHAR_C = 5'h0C;   // estado: cerrada
    parameter logic [4:0] CHAR_E = 5'h0E;   // estado: error
    parameter logic [4:0] CHAR_F = 5'h0F;   // velocidad maxima
    parameter logic [4:0] CHAR_O = 5'h10;   // estado: abriendo ('o')
    parameter logic [4:0] CHAR_c = 5'h11;   // estado: cerrando ('c')
    parameter logic [4:0] CHAR_n = 5'h12;   // modo: normal ('n')
    parameter logic [4:0] CHAR_t = 5'h13;   // modo: test ('t')

endpackage