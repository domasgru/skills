# Waiting on long runs

How every agent of this workflow waits on a command or a subagent that takes minutes: UI test runs, gates, VM runs, builds.

- **Start it in the background.** A command that can last longer than about 3 minutes starts with `run_in_background`. A foreground call is moved to the background after 180 s anyway, whatever its `timeout`, so a longer foreground call buys nothing.
- **End your turn to wait.** With the command running, end your turn with one line naming what you wait on, such as `Waiting on the UI run of NewNoteUITests.` Its completion notification resumes you, also when it fails. This holds in a subagent too: the subagent is resumed when its own background work ends, and its parent is notified again with its next report.
- **Never poll.** No `sleep`, `timeout`, `pgrep`, `lsof +r`, `select` or `read -t` to pass the time, and no reads of the output file to see whether it is done. Read the output file once, after the notification. A poll is denied in subagents (`hooks/block-polling.sh`), and it outlives work that has died.
- **A waiting subagent's report is interim.** When a subagent you dispatched stops while its own background work runs, the notification says so and its result is a waiting line. That is not its report. End your turn: its next notification brings the next report. Act only on a report that is not interim.
- **Your own report ends your work.** Ending a turn to wait is the one stop before it. Every other stop reads to your parent as your final report.
