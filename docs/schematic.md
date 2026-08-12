flowchart TD
    subgraph User_Interface ["User & Sensor Inputs"]
        B1["5x Table Selection Buttons"]
        US["Ultrasonic Sensor (Obstacle Detection)"]
        IR["3-Channel IR Line Array (PC0, PC2, PC3)"]
        ACK["Delivery OK Button (PC11)"]
    end

    subgraph Vega_Controller ["Vega RISC-V Controller"]
        V_PROC["Table Selection & Safety Logic"]
        LCD["16x2 LCD Display"]
    end

    subgraph Inter_Board ["Inter-Board Parallel Interface"]
        P_BUS["3-Bit Parallel Data (PC6, PC8, PC9)"]
        STOP_LINE["E-Stop / Obstacle Interrupt Line (PC10)"]
    end

    subgraph STM32_Controller ["STM32 Microcontroller"]
        FSM["Intersection & Motion State Machine"]
        TIM2["TIM2 PWM Generator (PA0, PA3)"]
        GPIO_DIR["Direction Control (PA4, PA5, PB8, PB9)"]
        LEDs["Status LEDs (PB0, PB7, PB14)"]
    end

    subgraph Actuation ["Power & Drive Hardware"]
        L298N["L298N Dual H-Bridge Driver"]
        MOTORS["Left & Right DC Gear Motors / Wheels"]
        PWR["Battery Pack (12V Power Bus & 5V Regulators)"]
    end

    %% Interface Connections
    B1 -->|Button Pins| V_PROC
    US -->|Trig / Echo| V_PROC
    V_PROC -->|Display Table / 'Obstacle Detected!'| LCD
    
    V_PROC -->|Target Table ID| P_BUS
    V_PROC -->|Active High Obstacle Flag| STOP_LINE

    P_BUS -->|GPIO Reads| FSM
    STOP_LINE -->|Highest Priority Check| FSM
    IR -->|Line Tracking Inputs| FSM
    ACK -->|User Arrival Sign-off| FSM

    FSM -->|Target Indicator| LEDs
    FSM -->|Duty Cycle Control| TIM2
    FSM -->|H-Bridge Phase Selection| GPIO_DIR

    TIM2 -->|PA0 (CH1), PA3 (CH4) PWM| L298N
    GPIO_DIR -->|IN1, IN2, IN3, IN4| L298N
    PWR -->|12V Supply| L298N
    PWR -->|5V / 3.3V Step-Down| Vega_Controller
    PWR -->|5V / 3.3V Step-Down| STM32_Controller
    L298N -->|Motor Outputs A & B| MOTORS
