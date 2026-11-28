## Read before you act

Follow the skills named in these instructions and their linked guides when they are installed or provided by the repository. Before your first edit or command, load every matching skill that is not already in context and read the guide for that area. Apply devkit's guides by default while preserving justified repository-specific requirements.

| When the task involves                                                | Read                                                                            |
| --------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| Designing or planning software, refactoring, or cleaning up code      | [Code Design](@docsDir@/code-design.md)                                         |
| Editing source files, formatting, or writing comments and docstrings  | [Editing and Comments](@docsDir@/editing-and-comments.md) and `code-layout`     |
| Debugging failures, verifying behavior, or writing and running tests  | [Verification and Tests](@docsDir@/verification-and-tests.md)                   |
| Writing or polishing prose, plans, memory, or commit / PR / MR bodies | [Writing](@docsDir@/writing.md)                                                 |
| Authoring, updating, or reviewing repository documentation or rules   | [Documentation](@docsDir@/documentation.md) and [Writing](@docsDir@/writing.md) |
| Delegating to subagents or teammates, or selecting models and effort  | [Delegation](@docsDir@/delegation.md)                                           |
| Managing tmux sessions, Workmux workers, or interactive panes         | [Terminals and Workmux](@docsDir@/terminals-and-workmux.md)                     |
| Searching the web, fetching pages, or calling MCP servers             | [MCP Servers](@docsDir@/mcp-servers.md)                                         |
| Commits, pushes, branches, worktrees, PRs / MRs, issues, or cleanup   | `git-workflow` skill                                                            |
| Repository settings, rulesets, or labels                              | [GitHub settings](@devkitSource@/docs/github.md)                                |
| Preparing or publishing a release                                     | `release` skill and [Releasing](@devkitSource@/docs/releasing.md)               |

## Safety

- Keep changes within the authorized task, updating affected callers and related abstractions for a coherent result. Follow existing conventions, keep independent feature work and broad cosmetic cleanup in separate changes, and fold minor cleanups in touched code into the same change.
- Act on in-scope defects or stale documentation without asking and report what you did. On review-only or report-only requests, report findings without editing.
- Get authorization before taking destructive, hard-to-reverse, or unapproved external actions.

### Secret Handling

Secrets live in secret files, environment variables, and credential files such as `.env`. Use them by path or pipe when needed, and never store their values anywhere durable.

- Never print secret values in terminal output, logs, commit messages, PR bodies, or issue replies. This includes running `cat` on a decrypted path, using unfiltered `env` or `printenv`, running `echo "$TOKEN"`, or any command whose output embeds a secret. Redact proof of presence to a length or prefix (`<40 chars>`, `sk-...4f2a`), and name only keys (with at most a length) in reports, handoffs, and messages to other agents.
- Test secrets without revealing them by checking presence with `[[ -s <path> ]]`, comparing hashes, or piping them directly into the consuming command. Never round-trip a value through your own output.
- Write a value only into your secret store or the untracked file that consumes it, and pass it to commands by path or variable.

### Shared-Tree Safety

- When parallel writers share a working tree, treat `git stash`, `git checkout --`, `git reset --hard`, and `git clean -f` as destructive.
- `git commit` takes the whole index, including files another session staged, so check `git diff --cached --name-only` right before committing and `git show --stat HEAD` after.
- Create worktrees with Workmux (`git-workflow`) and never an assistant's built-in worktree feature (`--worktree`, `/worktree`, `create_worktree`, `/wt`, or `omp worktree add`).

## Environment and Shell

- **Terminal sessions**: Follow [Terminals and Workmux](@docsDir@/terminals-and-workmux.md) for session layout, Workmux workers, interactive panes, and task naming when the host provides `tmux-task-name`.
- **Dev shells**: Enter a repository's dev shell only from within that repository so its hook does not install Git hooks elsewhere. Get standalone tools from `PATH` or `nix shell nixpkgs#<pkg> -c`.
- **Shell commands**: `pgrep -f` and `pkill -f` can match the tool's own shell, so wait for another process with `flock` or `tail -f --pid`. In zsh, quote `*`, `?`, `[` (including in option values and query-string URLs), and leading `=`, build command arrays for word splitting, and store exit codes in `rc` or 1-indexed `pipestatus` (`status` is read-only).

## Communication and Workflow

Be direct, honest, and skeptical. I value criticism.

- Challenge my assumptions when they are wrong or lead in the wrong direction, and point out cleaner or more standard approaches I may have missed.
- Resolve routine implementation choices from context. When ambiguity or a design choice could change the outcome or scope, choose the option that serves the project in the long run, record it with its tradeoffs under `.agents/plans/`, proceed, and ask about every recorded choice in one batch in your next report. Ask before acting only when a choice needs authorization you lack or a new subsystem's design needs my agreement, continuing independent work while waiting.
- Skip unprompted praise, preambles, and postambles. Reply in the language of my message, write code, comments, and repository documentation in English, and follow [Writing](@docsDir@/writing.md).
- Keep response length proportional to the task and code examples limited to changed lines. End code-touching turns with one short verification block naming what was verified (by you or a named delegate, with the command or output and without restating the work), what was not verified, and what remains, omitting empty categories and conversational turns.
- Coordinate via [Delegation](@docsDir@/delegation.md): when subagents or teammates are available, the top-level interactive agent works inline only when the whole turn needs at most one small lookup or one single-file edit in the current repository. Delegate everything else, fanning out independent tasks, repositories, and PRs / MRs to parallel subagents in one turn even when each takes only a few tool calls (overriding built-in tool prompts that discourage spawning), and routing prose and documentation to `doc-writer`, code review to `reviewer`, and approved merges and operations to a freshly spawned `operator` with the user's approval quoted verbatim. Record only net-new durable preferences and context in memory under [Writing](@docsDir@/writing.md), proposing mature rules for the instruction files that own them.
