# `Raxol.Core.Accessibility.AnnouncementQueue`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/accessibility/announcement_queue.ex#L1)

Pure-functional helpers for announcement queue management, priority sorting,
history tracking, and delivery.  Used by AccessibilityServer.

# `enqueue_focus`

Appends a high-priority focus announcement to both queue and history.

# `limited_history`

Returns history limited to `limit` entries (or all when nil).

# `parse_focus_change_event_data`

Parses event dispatcher arguments into `{old_focus, new_focus}` tuples.
Returns `{nil, nil}` when the event cannot be parsed.

# `pop`

Returns {next_message, updated_announcements_state} or {nil, state} when empty.

# `process`

Returns the announcement state map after processing a new announcement.
Does nothing if announcements should not be processed.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
