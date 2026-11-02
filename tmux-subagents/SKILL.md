---
name: tmux-subagents
description: Run every subagent as a live, attachable tmux session and control it exclusively through tmux - new-session to launch, send-keys to steer, capture-pane to read, kill-session to reap. Use when dispatching, steering, monitoring, or reaping any subagent CLI (claude, codex, agy, gemini), running parallel agent sessions, or when delegated work must stay observable, resumable, and watchable by the human.
---

# tmux Subagents

Every subagent runs as a live, interactive CLI session in tmux. tmux is the only control plane: launch with `new-session`, type with `send-keys`, read with `capture-pane`, end with `kill-session`. No opaque in-process delegation, no detached background agents. The human can `tmux attach -t <session>` at any time and watch a subagent work.

## 1. Layout

- One detached tmux session per subagent task, named `<project>-<task>` (e.g. `tmux-orche-audit`).
- Session starts in the repo dir: `tmux new-session -d -s <project>-<task> -c <repo-dir>`.
- Never dispatch into the human's attached sessions; always create your own.

## 2. Launch

1. Write the full directive to a file **inside the repo** (`<repo>/AGENT-TASK-<task>.md`) — see §3.
2. Create the session and launch the agent CLI in interactive mode with its auto-approve flag. Permission prompts are the #1 stall cause; an approval dialog in a captured pane is a launch violation — kill and relaunch with the right flag.

```
tmux new-session -d -s <project>-<task> -c <repo-dir>
tmux send-keys -t <project>-<task> '<launch line>' Enter
```

Launch lines (confirm once with `<cli> --help`, then record the working line in `<repo>/.agent/launch-lines.md`; next dispatch reads that file first):

| CLI | Launch line |
|---|---|
| agy | `agy --mode auto --dangerously-skip-permissions -i <repo>/AGENT-TASK-<task>.md` |
| claude | `claude --dangerously-skip-permissions` |
| codex | `codex --full-auto` (newer: `codex --dangerously-bypass-approvals-and-sandbox`) |
| gemini | `gemini --approval-mode yolo` (older: `gemini --yolo`) |

3. For TUI CLIs launched without `-i`, send a one-line pointer to the directive:

```
tmux send-keys -t <project>-<task> 'Read AGENT-TASK-<task>.md in the repo root and execute it exactly.' Enter
```

Never paste multi-line prompts through `send-keys` — newlines split into queued messages. Multiline content always travels in the directive file.

Done when: `tmux capture-pane -p -t <project>-<task>` shows the agent TUI running the task.

## 3. Directive contract

The directive file states:

- Role, scope, and the exact files/dirs the subagent may touch.
- Gates to run: the project's `verify` command (and build/test/lint/playwright as applicable).
- Commit policy (default: no commits unless the directive grants it).
- Destructive or outbound actions (delete, deploy, push) require explicit approval inside the directive.
- A required final grep-able line: `TASK-RESULT: PASS|FAIL`, with specifics above it.

## 4. Monitor and steer

- Read state: `tmux capture-pane -p -t <project>-<task> | tail -n 40`.
  - Spinner / streaming output = working.
  - Idle prompt with no `TASK-RESULT` marker = needs steering.
  - `TASK-RESULT:` present = collect the result (§5).
- Steer with `send-keys` one-liners only. If the steer needs more than one line, update the directive file and resend the pointer from §2.3.
- Capture on demand while doing other work; never sleep-loop on a pane.

## 5. Verify and reap

- Done = the pane shows a green `verify` run **and** `TASK-RESULT: PASS`. Claims that are not in the captured pane do not exist.
- 2 consecutive red verifies in the session → `tmux kill-session -t <project>-<task>`, write `.agent/BLOCKED-<task>.md` (what was tried, exact error, root-cause hypothesis), report to the human. Never a third blind retry.
- After collecting the result, always reap: `tmux kill-session -t <project>-<task>`. Do not leave idle agent sessions; audit with `tmux ls`.

## 6. Parallel dispatch

Multiple sessions at once, one task each, unique names:

```
for s in $(tmux list-sessions -F '#S' | grep '^<project>-'); do
  echo "== $s =="; tmux capture-pane -p -t "$s" | tail -n 5
done
```

Reap each as it finishes; the last one closed returns the orchestrator to single-threaded work.

## 7. Zero-cost smoke test

Before the first dispatch on a machine, prove the control plane:

```
tmux new-session -d -s subagent-smoke
tmux send-keys -t subagent-smoke 'echo SUBAGENT-READY' Enter
tmux capture-pane -p -t subagent-smoke | grep SUBAGENT-READY
tmux kill-session -t subagent-smoke
```

If any step fails, tmux control is broken — fix it before dispatching anything.
