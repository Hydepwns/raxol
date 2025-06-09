# AI Agent Guide: Debugging and Fixing Test Failures in Raxol

## Overview

This guide is for future AI agents working on the Raxol codebase, especially when addressing test failures and syntax errors. It summarizes recent debugging steps, common pitfalls, and best practices.

---

## 1. Locating and Understanding Test Failures

- Use the provided `scripts/summarize_test_errors.sh` to quickly aggregate and locate failing tests.
- Review the output in `tmp/test_error_summary.txt` or `tmp/test_output.txt` for error details and stack traces.
- Use `grep` or code search tools to find references to failing functions, error keywords, or problematic keys (e.g., `KeyError`, `render_count`, `mounted`).

## 2. Common Pitfalls and Fixes

### KeyError in Test Helpers

- **Problem:** Tests may fail with `KeyError` for missing keys like `:render_count` or `:mounted` in component state.
- **Solution:** Ensure test helpers (e.g., `create_test_component/2` in `lib/raxol/test/test_helper.ex`) always call the component's `init/1` function to initialize required state keys.
- **Tip:** Check if the module exports `init/1` before calling it.

### Elixir Character Literals in Tests

- **Problem:** Syntax errors from incorrect character literal usage, e.g., `?()` or `?( )`.
- **Solution:** Use the correct Elixir syntax for character literals:
  - `?(` for open parenthesis
  - `?A` for the character 'A', etc.
- **Tip:** Do not add spaces or extra parentheses. The syntax is `?<char>`.

### Fixing Syntax Errors

- If you see a `MismatchedDelimiterError`, check for extra or missing parentheses, brackets, or braces.
- For character literals, always use the `?<char>` form.

## 3. Efficient Debugging Workflow

- After making changes, run `mix test --max-requires 1` for a quick feedback loop.
- Address syntax errors first, then logic errors or assertion failures.
- Use the test output to identify the exact file and line number of failures.
- If a test fails due to a state mismatch, check the test setup and helper functions.

## 4. Best Practices

- Keep test helpers up to date with the latest component API changes.
- When in doubt, check the implementation of the function/module under test.
- Use code search to find all usages of a problematic function or key.
- Document any non-obvious fixes or workarounds in this guide for future agents.

---

## Example Fixes

- **KeyError:**
  - Update test helpers to call `init/1`.
- **Character Literal Syntax:**
  - Replace `?()` or `?( )` with `?(`.
- **Assertion Failures:**
  - Compare the expected and actual values in the test output and adjust the test or implementation as needed.

---

## Additional Resources

- [Elixir Getting Started Guide](https://elixir-lang.org/getting-started/introduction.html)
- [ExUnit Documentation](https://hexdocs.pm/ex_unit/ExUnit.html)

---

_Update this guide as new issues and solutions are discovered._
