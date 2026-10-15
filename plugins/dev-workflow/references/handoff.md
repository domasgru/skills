# Handoffs

How the workflow's agents pass work to each other. Read by every agent that dispatches another; every agent's report follows the Report section.

## Why

An agent works best in a small context. A child's result lands whole in its parent's context and stays there, and so does every file the parent reads. So work travels in files, a report carries only what the parent needs to decide its next step, and a decision that needs a source read in full is made by an agent whose context holds little else.

## Dispatching

- Give each child the **paths** of its inputs and of its output, never their content. Don't paste a file, a finding or another child's report into a prompt; name the file.
- Give each child its own output path. Two children never write the same file.
- Never write a file whose content you received from a child: the child writes its own output.
- Per call, set `effort` when the step is lighter than the child's definition assumes (a delta pass), and `model` only for the fallback below.

## Report

A report is the child's final message: the parent reads it as the result, so it is the last thing the child does, after every command it started has finished.

```
Status: done | partial | blocked | failed
Output: <path>[, <path>...]
<the role's summary fields, as its definition gives them>
```

- `done`: the work is complete and in the output files. `partial`: part of it is; the output says what is left and how to continue (a handoff). `blocked`: it cannot go on without a decision; say which. `failed`: it broke; say how.
- Short: a few lines, at most about 300 words. Detail goes in the output file.
- A parent never treats `partial` as done: it dispatches a fresh agent of the same role, pointed at the output and the handoff, or reports `partial` itself.

## Waiting

- **On a child agent:** end your turn. Its report resumes you, and the harness does not report you finished while a child of yours still runs. Never poll for it.
- **On a command you started:** never end your turn while it runs. Once you have no running child, your end of turn is read as your report, and a background command does not count as a child. Run a long command in the foreground (Bash `timeout: 600000`), or its steps as separate foreground calls. When one step outlasts a call, start it with `run_in_background` as `bash ${CLAUDE_PLUGIN_ROOT}/scripts/bg.sh run <dir> -- <command>`, then call `bash ${CLAUDE_PLUGIN_ROOT}/scripts/bg.sh wait <dir>` in the foreground until it reports the command ended. Never start a second copy of a command that is still running.
- **When you have nothing left to wait on and work is unfinished**, do not end your turn: finish it, or report `partial` or `blocked`.
- A child's report without a status line, or one that says it is still waiting, is not completion: `SendMessage` the child to finish and report.

## Resuming

- Prefer a fresh agent over `SendMessage` to one that has done a lot of work: point the fresh one at the earlier one's output and its handoff or state file. `SendMessage` is for a short follow-up to a child that has read little, such as a reviewer asked to add a status line.
- To fold the human's answers into a design, dispatch a fresh architect: the plan and its `state.md` carry what it needs.

## Model fallback

- **Overloaded** (a transient error): dispatch it again once on the same model.
- **Rate-limited or out of credits** for its model: dispatch it again with `model: "opus"`, and pass `model: "opus"` to every later dispatch of yours that would have used the failed model. When `opus` is the model that failed, use `sonnet`.
- Record the substitution where the step logs its decisions. For the design arena, the Synthesis decision records that both candidates came from one model, so the human knows the model diversity was lost.
