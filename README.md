# Claude Code Workflow — installable, minimally invasive

A **Plan → Dev → Review** workflow for Claude Code that drops into any existing project
with one folder + a few prefixed shim files. Saves tokens by routing planning/review to
Opus and bulk implementation to Haiku.

```
🧠 /wf-plan (Opus)  →  ⚙️  /wf-dev (Haiku) × N  →  🔍 /wf-review (Opus)
```

## Footprint on your project

After installing into `~/myproject/`, **the only new top-level thing is nothing** — everything
lives inside `.claude/`:

```
~/myproject/
├── (your existing files untouched)
└── .claude/
    ├── (your existing agents/commands/hooks/skills untouched)
    ├── agents/wf-*.md              ← 3 prefixed files
    ├── commands/wf-*.md            ← 9 prefixed files (/wf-plan, /wf-dev, …)
    ├── hooks/wf-*.sh               ← 4 prefixed files
    ├── skills/wf-workflow-intro/   ← 1 prefixed folder
    ├── workflow/                   ← THE ONLY NEW NAMESPACE
    │   ├── plans/                  ← active + completed plans
    │   ├── summaries/              ← daily summaries + checkpoints
    │   ├── archive/                ← done plans
    │   ├── WORKFLOW.md             ← agent-facing rules
    │   ├── README.md               ← human docs
    │   ├── checkpoint.sh           ← 0-token emergency save (5h-limit safe)
    │   ├── settings.snippet.json   ← merge guide
    │   └── uninstall.sh
    └── settings.json               ← MERGED, not overwritten
```

To uninstall: `bash .claude/workflow/uninstall.sh` → removes everything.

## Install

```bash
# From inside this template directory:
bash install.sh ~/your-project

# Re-run after updating to refresh:
bash install.sh ~/your-project --force
```

`install.sh` will:
- Copy `wf-*` prefixed files into the canonical `.claude/{agents,commands,hooks,skills}/` locations (skipped if they exist; `--force` to overwrite).
- Copy `.claude/workflow/` wholesale (data + docs + scripts).
- Merge `settings.json` deep — adds the workflow's `hooks` and `permissions.allow` entries to your existing config (needs `jq`; falls back to printing the snippet for manual merge).
- Print a one-line hint to optionally add `@.claude/workflow/WORKFLOW.md` to your project's CLAUDE.md.

## Commands (all prefixed to avoid collisions)

| Command | Role | Model |
|---|---|---|
| `/wf-plan <task>` | Plan a task | Opus (planner subagent) |
| `/wf-dev` | Execute next step | Haiku (developer subagent) |
| `/wf-review` | Audit `git diff` | Opus (reviewer subagent) |
| `/wf-morning` | Load yesterday's context | main session |
| `/wf-evening` | Daily summary + tomorrow plan | main session |
| `/wf-handoff` | Brief a human reviewer | main session |
| `/wf-checkpoint <reason>` | Emergency save (uses tokens) | main session |
| `/wf-status` | Show progress | main session |
| `/wf-interrupt <change>` | Edit the active plan | main session |

Plus pure-bash escape hatch (no tokens, works during 5h-limit):

```bash
bash .claude/workflow/checkpoint.sh "ran out, picking up tomorrow"
```

## Why this is minimally invasive

- **0 files at project root.** All new files are inside `.claude/`.
- **Prefix `wf-`** on every file in canonical `.claude/` subdirs — clear ownership, zero collision with your existing agents/commands/hooks.
- **One namespace `.claude/workflow/`** holds everything else (data, docs, scripts).
- **settings.json merged, never overwritten.** Your existing hooks and permissions stay.
- **Project's `CLAUDE.md` untouched.** Workflow has its own `WORKFLOW.md` inside its namespace; reference it from your CLAUDE.md if you want it always loaded, otherwise it's loaded contextually via slash commands and the skill description.
- **Clean uninstall:** one script removes everything; optionally backs up plans/summaries first.

## Full docs

After installing, the project-facing docs live at:
- `.claude/workflow/README.md` — full usage manual (Chinese + English)
- `.claude/workflow/WORKFLOW.md` — agent-facing rules / behavior contract

This top-level README only covers installation. Everything else is in the namespace.

## Developing this repo

Runtime data under `.claude/workflow/{plans,summaries,archive}/` is gitignored in this repo so dogfooding doesn't pollute commits. Downstream projects should add the same patterns to their own `.gitignore` if they want the same behavior.

## Standalone test

You can also use this template directory itself as a working project to try the
workflow before installing it elsewhere:

```bash
cd workflow/   # this directory
claude
/wf-plan add a CHANGELOG to this template
/wf-dev
/wf-review
```
