# `Raxol.Terminal.Input.ControlSequenceHandler`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/input/control_sequence_handler.ex#L1)

Handles various control sequences for the terminal emulator.
Includes CSI, OSC, DCS, PM, and APC sequence handling.

## APC Sequences

APC (Application Program Command) sequences are used by the Kitty graphics
protocol for transmitting images. The format is:

    ESC _ G <control-data> ; <payload> ESC \

Where `G` indicates Kitty graphics and control-data contains key=value pairs.

# `handle_apc_sequence`

Handles an APC (Application Program Command) sequence.

APC sequences are used by the Kitty graphics protocol. The command
indicates the type of APC sequence:

* `G` - Kitty graphics protocol
* Other commands are logged and ignored

# `handle_csi_sequence`

Handles a CSI (Control Sequence Introducer) sequence.

# `handle_dcs_sequence`

Handles a DCS (Device Control String) sequence.

# `handle_osc_sequence`

Handles an OSC (Operating System Command) sequence.

# `handle_pm_sequence`

Handles a PM (Privacy Message) sequence.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
