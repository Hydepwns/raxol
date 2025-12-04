# Development Roadmap

**Version**: v2.0.1
**Updated**: 2025-12-04
**Status**: CI workflow fixes complete, production ready

## Active Issues

### 1. Audit.LoggerTest - `:events_must_be_list` Error
- Location: `test/raxol/audit/logger_test.exs`
- Storage layer expects list, logger passes single event/map
- Fix: Wrap events in list in flush function

### 2. RuntimeTest - Tests Hang/Timeout
- Location: `test/raxol/runtime_test.exs`
- Tests hang waiting for events that never arrive
- Fix: Add timeouts or tag as `:integration`

### 3. Termbox2LoadingTest - NIF Loading
- Expected failure when `SKIP_TERMBOX2_TESTS=true`
- No action required

## Low Priority

### Credo Warnings
- Various code quality suggestions
- Non-blocking, address incrementally

### Distributed Test Infrastructure
- ~10 distributed session registry tests skipped
- Requires multi-node Erlang setup
- See `test/raxol/core/session/distributed_session_registry_test.exs`

## Hex.pm Publishing Checklist

- [ ] Resolve apps/raxol naming conflict (rename or remove)
- [ ] Verify package READMEs use GitHub links
- [ ] Test independent compilation of each package
- [ ] Authenticate: `mix hex.user auth`
- [ ] Publish order: raxol_core -> raxol_plugin -> raxol_liveview
- [ ] Create git tag: `git tag v2.0.1 && git push origin v2.0.1`

## Future Roadmap

### Platform Expansion (Q2 2025)
- WASM production support
- PWA capabilities
- Mobile terminal support
- Cloud session management

### Long-term Vision
- AI-powered command completion
- IDE integrations
- Natural language interfaces
- Collaborative terminal sessions

## Development Commands

```bash
# Testing
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test --exclude slow --exclude integration --exclude docker

# Quality
mix raxol.check
mix format
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix compile --warnings-as-errors
```
