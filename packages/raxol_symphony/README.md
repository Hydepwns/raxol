# Raxol Symphony

A Raxol port of [OpenAI Symphony](https://github.com/openai/symphony): an
orchestrator that turns tracker work into autonomous coding-agent runs. Each
issue gets an isolated workspace, runs an agent until the work reaches a
workflow-defined handoff state, and surfaces evidence (CI/PR/walkthrough) so
engineers manage outcomes rather than prompts.

Implements [`SPEC.md`](https://github.com/openai/symphony/blob/main/SPEC.md).

## Status

Phase 0 (skeleton). Not yet runnable. See `TODO.md` in the repo root for the
phasing.

## Trust posture

Designed for trusted developer-machine deployments. The default `raxol_agent`
runner uses `CommandHook` + `PermissionHook` to deny shell operations outside
the per-issue workspace. See `SPEC.md` s15 for hardening guidance.
