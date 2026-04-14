# `Raxol.Terminal.Commands.DeviceHandler`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/commands/device_handler.ex#L1)

Handles device-specific terminal commands like Device Attributes (DA) and Device Status Report (DSR).
This module provides direct implementations.

# `handle_c`

Handles Device Attributes (DA) request - CSI c command.

Primary DA (CSI 0 c or CSI c): Reports terminal capabilities
Secondary DA (CSI > 0 c): Reports terminal version and features

# `handle_n`

Handles Device Status Report (DSR) request - CSI n command.

CSI 5 n: Device Status Report - reports "OK" status
CSI 6 n: Cursor Position Report - reports current cursor position

---

*Consult [api-reference.md](api-reference.md) for complete listing*
