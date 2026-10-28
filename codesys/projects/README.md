# CODESYS controller project

Create a **Standard Project** for **CODESYS Control Win V3 x64**, with a Structured Text `PLC_PRG`, and save it here as:

```text
recyclable-material-sorting.project
```

Follow [Sections 3–7 of the main README](../../README.md#3-set-up-codesys-and-its-modbus-tcp-server) to configure the Ethernet adapter, Modbus TCP server, variable mapping and cyclic task. The readable PLC source is in [../source](../source):

- `FIO.gvl` — global I/O, material classes and calibration settings.
- `PLC_PRG_declaration.st` — the `PLC_PRG` declaration.
- `PLC_PRG_implementation_tracking.st` — conveyor control, object tracking and sorter actuation.

Paste the declaration and implementation into their separate CODESYS editor panes. These are source listings, rather than a configured controller project or an XML import package. The source and documented setup are sufficient to reconstruct the controller; a preconfigured binary `.project` is not included.

Use the class labels **PET plastic**, **HDPE plastic** and **Aluminium** consistently. Retain the `FIO` GVL name, variable identifiers and Modbus addresses from the README so the PLC, Factory I/O and Python communicate correctly.
