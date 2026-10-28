
(* =====================================================
   1. CONVEYOR AND SORTER BELT CONTROL
   ===================================================== *)

(* Run both conveyors continuously *)
FIO.oEntryConveyor := TRUE;
FIO.oExitConveyor := TRUE;

(* Run all three sorter belts continuously.
   The turning mechanisms are controlled separately. *)
FIO.oSorter1Belt := TRUE;
FIO.oSorter2Belt := TRUE;
FIO.oSorter3Belt := TRUE;


(* =====================================================
   2. ENCODER POSITION COUNTING
   ===================================================== *)

(* R_TRIG detects a FALSE-to-TRUE transition on encoder A.
   Each rising edge represents one encoder cycle.
   Entry and exit conveyors have independent counters. *)

entryPulse(CLK := FIO.iEncoderA);
exitPulse(CLK := FIO.iExitEncoderA);

(* Increment the entry conveyor position counter *)
IF entryPulse.Q THEN
    FIO.entryEncoderCount := FIO.entryEncoderCount + 1;
END_IF;

(* Increment the exit conveyor position counter *)
IF exitPulse.Q THEN
    FIO.exitEncoderCount := FIO.exitEncoderCount + 1;
END_IF;


(* =====================================================
   3. RECEIVE PYTHON CLASSIFICATION AND REGISTER OBJECT
   ===================================================== *)

(* Read the material class written by Python through Modbus.
   0 = Unknown / no detected material
   1 = PET plastic (blue)
   2 = HDPE plastic (green)
   3 = Aluminium (metal) *)
FIO.materialClass := WORD_TO_INT(FIO.pythonMaterialClass);

(* Detect a new object when the classification changes
   from 0 to a valid material class.
   This prevents registering the same object every PLC scan. *)
newObject := (previousClass = 0) AND
             (FIO.materialClass >= 1) AND
             (FIO.materialClass <= 3);

(* Remember the current class for the next PLC scan *)
previousClass := FIO.materialClass;

IF newObject THEN

    (* Flag ensures that the new object is stored only once *)
    stored := FALSE;

    (* Search for an available slot in the 32-object tracking array *)
    FOR slot := 1 TO 32 DO

        IF (objectStage[slot] = 0) AND NOT stored THEN

            (* Stage 1: object is on the entry conveyor *)
            objectStage[slot] := 1;

            (* Store the classification for this specific object *)
            objectClass[slot] := FIO.materialClass;

            (* Calculate the entry encoder count at which
               the object should reach the second conveyor *)
            objectEntryTarget[slot] :=
                FIO.entryEncoderCount + FIO.visionToTransferCounts;

            (* Prevent storing this object in another slot *)
            stored := TRUE;

        END_IF;

    END_FOR;

END_IF;


(* =====================================================
   4. OBJECT TRACKING: ENTRY -> TRANSFER -> SORTER
   ===================================================== *)

(* Reset sorter trigger flags at the start of each PLC scan.
   They become TRUE only when an object reaches its target. *)
fireSorter1 := FALSE;
fireSorter2 := FALSE;
fireSorter3 := FALSE;

(* Recalculate how many objects are currently being tracked *)
FIO.pendingObjects := 0;

(* Process every object tracking slot *)
FOR slot := 1 TO 32 DO

    (* ---------------------------------------------
       STAGE 1: OBJECT ON ENTRY CONVEYOR
       --------------------------------------------- *)

    IF objectStage[slot] = 1 THEN

        (* Check whether the entry conveyor has moved
           far enough for the object to reach the transfer point *)
        IF FIO.entryEncoderCount >= objectEntryTarget[slot] THEN

            (* Select the sorter offset based on material class *)
            targetOffset := 0;

            CASE objectClass[slot] OF
                1: targetOffset := FIO.sorter1Offset;  (* PET plastic *)
                2: targetOffset := FIO.sorter2Offset;  (* HDPE plastic *)
                3: targetOffset := FIO.sorter3Offset;  (* Aluminium *)
            END_CASE;

            IF targetOffset > 0 THEN

                (* Switch position tracking to the exit conveyor.
                   The exit target is relative to its current count. *)
                objectExitTarget[slot] :=
                    FIO.exitEncoderCount + targetOffset;

                (* Stage 2: object is now tracked on exit conveyor *)
                objectStage[slot] := 2;

            ELSE

                (* Invalid offset: release this tracking slot *)
                objectStage[slot] := 0;

            END_IF;

        END_IF;

    END_IF;


    (* ---------------------------------------------
       STAGE 2: OBJECT ON EXIT CONVEYOR
       --------------------------------------------- *)

    IF objectStage[slot] = 2 THEN

        (* Check whether the object has reached
           its assigned sorter's encoder position *)
        IF FIO.exitEncoderCount >= objectExitTarget[slot] THEN

            (* Activate only the sorter matching the object's class *)
            CASE objectClass[slot] OF
                1: fireSorter1 := TRUE;  (* Blue -> Sorter 1 *)
                2: fireSorter2 := TRUE;  (* Green -> Sorter 2 *)
                3: fireSorter3 := TRUE;  (* Metal -> Sorter 3 *)
            END_CASE;

            (* Release the tracking slot for future objects *)
            objectStage[slot] := 0;

            (* Count this object as having received a sort command.
               This does not confirm physical sorting success. *)
            FIO.sortedObjects := FIO.sortedObjects + 1;

        END_IF;

    END_IF;


    (* Count objects still travelling on either conveyor *)
    IF objectStage[slot] <> 0 THEN
        FIO.pendingObjects := FIO.pendingObjects + 1;
    END_IF;

END_FOR;


(* =====================================================
   5. SORTER ACTIVATION TIMERS
   ===================================================== *)

(* TP = pulse timer.
   When a sorter receives a trigger, its timer generates
   a pulse lasting FIO.sorterTurnDuration.

   Current setting: 500 ms.

   Each sorter has an independent timer. *)

sorterTimer1(IN := fireSorter1, PT := FIO.sorterTurnDuration);
sorterTimer2(IN := fireSorter2, PT := FIO.sorterTurnDuration);
sorterTimer3(IN := fireSorter3, PT := FIO.sorterTurnDuration);


(* =====================================================
   6. SEND SORTER COMMANDS TO FACTORY I/O
   ===================================================== *)

(* Timer outputs control the turning mechanisms.
   The sorter belts remain running from Section 1.

   TRUE  = turn mechanism activated
   FALSE = turn mechanism deactivated *)

FIO.oSorter1Turn := sorterTimer1.Q;
FIO.oSorter2Turn := sorterTimer2.Q;
FIO.oSorter3Turn := sorterTimer3.Q;
