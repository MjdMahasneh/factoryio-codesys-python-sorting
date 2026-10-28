PROGRAM PLC_PRG
VAR
    // ========================================
    // ENCODER PULSE DETECTION
    // ========================================

    // Detect rising edges from the entry conveyor encoder
    entryPulse : R_TRIG;

    // Detect rising edges from the exit conveyor encoder
    exitPulse : R_TRIG;


    // ========================================
    // OBJECT DETECTION AND CLASSIFICATION
    // ========================================

    // Previous classification received from Python
    // Used to detect a new object when class changes from 0 to 1, 2, or 3
    previousClass : INT := 0;

    // TRUE for one PLC cycle when a new object is detected
    newObject : BOOL;


    // ========================================
    // OBJECT TRACKING
    // ========================================

    // Track up to 32 objects simultaneously
    // Stage 0 = Empty slot
    // Stage 1 = Object travelling on entry conveyor
    // Stage 2 = Object travelling on exit conveyor
    objectStage : ARRAY[1..32] OF INT;

    // Store each object's material classification
    // 1 = PET plastic, 2 = HDPE plastic, 3 = Aluminium
    objectClass : ARRAY[1..32] OF INT;

    // Entry encoder count at which an object reaches the conveyor transfer
    objectEntryTarget : ARRAY[1..32] OF DINT;

    // Exit encoder count at which an object reaches its assigned sorter
    objectExitTarget : ARRAY[1..32] OF DINT;

    // Index used to iterate through the 32 tracking slots
    slot : INT;

    // Encoder offset for the sorter corresponding to an object's class
    targetOffset : DINT;

    // Prevents storing the same object in multiple tracking slots
    stored : BOOL;


    // ========================================
    // SORTER ACTIVATION
    // ========================================

    // Trigger flags for the three sorters
    // TRUE for one PLC cycle when an object reaches its target
    fireSorter1 : BOOL;
    fireSorter2 : BOOL;
    fireSorter3 : BOOL;

    // Pulse timers controlling how long each sorter turns
    // Duration configured using FIO.sorterTurnDuration
    sorterTimer1 : TP;
    sorterTimer2 : TP;
    sorterTimer3 : TP;

END_VAR