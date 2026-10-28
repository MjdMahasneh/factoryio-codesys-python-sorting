"""Simulate PET plastic, HDPE plastic, and aluminium classification over Modbus TCP.

Factory I/O object values are stand-ins for material classes; no camera or ML model is used.
"""


import time
from pymodbus.client import ModbusTcpClient


# ============================================================
# CONFIGURATION
# ============================================================

PLC_HOST = "127.0.0.1"
PLC_PORT = 502
SLAVE_ID = 255

SENSOR_REGISTER = 0
CLASSIFICATION_REGISTER = 1

POLL_INTERVAL = 0.01  # Seconds


# Factory I/O sensor values -> simulated recyclable-material classification IDs
MATERIAL_CLASSES = {
    1: (1, "PET plastic"),   # Blue object
    4: (2, "HDPE plastic"),  # Green object
    7: (3, "Aluminium"),     # Metal object
}


# ============================================================
# CONNECT TO PLC
# ============================================================

client = ModbusTcpClient(
    host=PLC_HOST,
    port=PLC_PORT
)

if not client.connect():
    raise ConnectionError("Could not connect to CODESYS PLC.")

print("Connected to CODESYS PLC")

previous_sensor_value = None


# ============================================================
# MAIN LOOP
# ============================================================

try:
    while True:

        # Read the Factory I/O vision sensor through CODESYS
        response = client.read_holding_registers(
            address=SENSOR_REGISTER,
            count=1,
            slave=SLAVE_ID
        )

        if response.isError():
            print(f"Sensor read failed: {response}")
            time.sleep(POLL_INTERVAL)
            continue

        sensor_value = response.registers[0]

        # Simulate material classification from the Factory I/O sensor value
        class_id, material_name = MATERIAL_CLASSES.get(
            sensor_value,
            (0, "Unknown")
        )

        # Send classification result to the PLC
        # 0 = Unknown, 1 = PET plastic, 2 = HDPE plastic, 3 = Aluminium
        write_response = client.write_register(
            address=CLASSIFICATION_REGISTER,
            value=class_id,
            slave=SLAVE_ID
        )

        if write_response.isError():
            print(f"PLC write failed: {write_response}")
            time.sleep(POLL_INTERVAL)
            continue

        # Print only when the detected material changes
        if sensor_value != previous_sensor_value:
            print(
                f"Sensor: {sensor_value} | "
                f"Material: {material_name} | "
                f"Class ID sent to PLC: {class_id}"
            )

            previous_sensor_value = sensor_value

        time.sleep(POLL_INTERVAL)


except KeyboardInterrupt:
    print("\nStopping simulation...")


finally:
    # Clear the classification when stopping
    if client.connected:
        client.write_register(
            address=CLASSIFICATION_REGISTER,
            value=0,
            slave=SLAVE_ID
        )

    client.close()
    print("PLC connection closed.")
