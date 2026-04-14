# `Raxol.Terminal.Driver.Dispatch`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/driver/dispatch.ex#L1)

Event dispatching helpers for Driver: sends events to the dispatcher
and handles initial resize notification.

# `parse_test_input`

Parses test input data into an Event struct.

# `send_event_to_dispatcher`

Sends an event to the dispatcher pid, using direct send in test mode.

# `send_initial_resize_event`

Sends an initial resize event to the dispatcher based on current terminal size.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
