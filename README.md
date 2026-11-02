# tmux-orche

Agent skills for solo developers who run their subagents in tmux.

Built on the engine of [Lbin91/solo-dev-agent-skills](https://github.com/Lbin91/solo-dev-agent-skills) — one developer, one machine, one subscription — with one added constraint: **tmux is the only control plane for subagents.** A subagent you cannot attach to, watch, and steer is a subagent you cannot debug.

## Why this exists

I tried a fair number of orchestration setups — in-process agent fan-out, RPC-style coordination frameworks, orchestration CLIs. The one thing that actually stuck was none of them: it was **passing data between sessions with tmux**. `send-keys` in, `capture-pane` out, one session per agent — the same three primitives launch, steer, and reap, and every byte an agent produces sits in a pane I can attach to and read myself. Nothing else came close on usefulness per moving part, so tmux became the control plane.

## Principles

1. **tmux is the subagent control plane.** Subagents are created, steered, read, and reaped exclusively through tmux primitives — `new-session`, `send-keys`, `capture-pane`, `kill-session`. No opaque in-process delegation, no orphan background jobs that outlive their pane.
2. **Subagents run directly in sessions.** Every subagent is a live, interactive agent CLI (claude / codex / agy / gemini / omo) in its own detached tmux session. The orchestrator types into the session and reads from the pane; the human can `tmux attach -t <session>` and watch work happen in real time.
3. **Verification is the only currency.** One `verify` command decides what "done" means. A subagent's self-report is worth nothing until the orchestrator captures a green verify — or a grep-able `TASK-RESULT: PASS` marker — from its pane. Trust captured bytes, not paraphrase.
4. **Fail closed early.** Two consecutive red verifies inside a subagent session → kill the session, write a short blocked report, hand back to the human. Retry loops burn the budget for nothing.
5. **Never block the human on facts.** `capture-pane` answers what happened; a throwaway script answers what would happen. The human answers only taste, product policy, and credentials.
6. **Environment over instructions.** A failure that happens twice becomes a lint rule, a banned pattern, or a recorded launch line in the repo — not a longer prompt. Proven facts get written down; agents forget, files don't.
7. **Small verifiable units.** One task per tmux session, ~100-line diffs, each ending in a green verify. Sequence so the tree is never broken between steps.

## Skills

| Skill | Purpose |
|---|---|
| `tmux-subagents` | Launch, steer, monitor, and reap subagents as live, attachable tmux sessions |

## Install

```
./install.sh              # copies skills into ~/.agents/skills
./install.sh <skill-dir>  # or another harness's skill directory
```

Installation copies (not symlinks), so re-run `./install.sh` after pulling updates. Restart your agent session after installing.

## Sources & inspiration

- [Lbin91/solo-dev-agent-skills](https://github.com/Lbin91/solo-dev-agent-skills) — the engine: verification-first trust ladder, fail-closed, small units; principles 3–7 adapted from it.
- `agy-dispatch` (local skill) — the proven tmux dispatch pattern on this machine: session-per-task, file-based directives, completion-marker recovery.
