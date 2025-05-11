# 🧪 Raxol Test Suite

Welcome! This directory contains Raxol's comprehensive test suite, designed for reliability, speed, and maintainability.

---

## 🗂️ Test Structure

- `test/support/` — Test helpers and support modules
  - `data_case.ex` — Database test setup
  - `test_helpers.ex` — Common test utilities
- `test/` — Test files organized by module or feature

---

## ✅ Best Practices

- **No `Process.sleep`:**
  Use event-based synchronization (`assert_receive`) or `Raxol.TestHelpers.wait_for_state/2` for polling.
- **Resource Cleanup:**
  Always use `on_exit` in `setup` blocks to clean up processes, ETS tables, and temp files.
- **Database Tests:**
  Use `Raxol.DataCase` and set `async: false` for shared state.
- **Test Isolation:**
  Use unique process names and reset shared state in `setup`.
- **Event-Based Testing:**
  Prefer `assert_receive` and `make_ref()` for precise event timing.

---

## 🧪 Test Categories

- **Unit Tests:**
  Test individual functions/modules (`ExUnit.Case`, `async: true`).
- **Integration Tests:**
  Test component interactions (`ExUnit.Case, async: false`).
- **Database Tests:**
  Use `Raxol.DataCase`, always `async: false`.
- **Performance Tests:**
  Use `ExUnit.Case, async: false`, may require longer timeouts.

---

## ▶️ Running Tests

```bash
mix test                      # Run all tests
mix test test/path/to/test.exs  # Run a specific test file
mix test test/path/to/test.exs:123  # Run a specific test
```

---

## ⚙️ Test Configuration

Configuration is in `config/test.exs`. Key settings:

- Database pool size: 10
- Logger level: `:warn`
- Assert receive timeout: 1000ms
- Test mode enabled
- Database enabled

---

## ➕ Adding New Tests

1. Choose the right test case (`ExUnit.Case`, `Raxol.DataCase`, or `Raxol.ConnCase`).
2. Follow best practices above.
3. Add cleanup in `setup` blocks.
4. Use helpers from `Raxol.TestHelpers`.
5. Document any special requirements.

---

## 🛠️ Test Helpers

- **Raxol.TestHelpers:**
  Event-based sync, process/ETS/registry cleanup, temp file handling.
- **Raxol.DataCase:**
  Transaction management, sandboxing, error handling, changeset validation.

---

## 🩺 Troubleshooting

- **Flaky Tests:**
  Replace `Process.sleep` with event-based sync, ensure cleanup, use unique state.
- **Database Issues:**
  Use `Raxol.DataCase`, set `async: false`, clean up after tests.
- **Process Cleanup:**
  Use `on_exit`, monitor process state, clean up resources.
- **Event Timing:**
  Use appropriate timeouts, add event tracing, check propagation.

---

Happy testing!
