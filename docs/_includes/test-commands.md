## Test Commands

```bash
# Run all tests
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test --exclude slow --exclude integration --exclude docker

# Run specific test file
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test test/path/to/test_file.exs

# Run failed tests
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test --failed

# With max failures
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test --max-failures 5

# With coverage
mix test --cover
```
