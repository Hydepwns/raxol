# `Raxol.Terminal.Driver.InputBuffer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/driver/input_buffer.ex#L1)

Input buffer management for Driver: accumulates bytes, detects incomplete
escape sequences, and flushes complete sequences for parsing.

# `incomplete_escape?`

Returns true if the buffer ends with an incomplete escape sequence
that needs more bytes before it can be dispatched.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
