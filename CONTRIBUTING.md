# Contributing to gauntlet

## Quick Start

```bash
# 1. Clone or copy the skill
cp -r ~/.claude/skills/gauntlet /tmp/gauntlet-dev

# 2. Make changes in /tmp/gauntlet-dev
# 3. Test locally
cd /tmp/gauntlet-dev
/gauntlet --help
```

## File Map

```
SKILL.md              Router — subcommand detection, Stage/Tier/Role resolution
ref-pipeline.md       Step 1–10 pipeline (DA rounds, session management, HIL gate)
ref-setup.md          /gauntlet setup wizard
ref-ops.md            --gc / --resume operations
ref-common.md         session.json schema, atomic write pattern
ref-provider-guide.md How to add a new provider
gauntlet-roles.json   Role → lens mapping (Gemini / ChatGPT / Claude primary lens)
governance_rules.json DA coverage rules (INSUFFICIENT COVERAGE thresholds)
providers/            One .sh + .json per API provider
```

## Adding a Provider

See `ref-provider-guide.md` for the full spec. Short version:

1. Create `providers/<name>.sh` — reads prompt from stdin, writes response text to stdout
2. Create `providers/<name>.json` — metadata (model, display name, exit codes)
3. Add the provider key to `gauntlet-roles.json`
4. Test: `echo "test prompt" | bash providers/<name>.sh`

Provider exit codes:
- `0` — success
- `1` — validation failed
- `2` — provider error (auth, rate limit, network)
- `3` — contract broken (unexpected response shape)

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `GAUNTLET_GEMINI_KEY` | Gemini API key (Stage 2) |
| `GAUNTLET_OPENAI_KEY` | OpenAI API key (Stage 2) |
| `GAUNTLET_CLAUDE_KEY` | Anthropic API key — separate from `ANTHROPIC_API_KEY` to isolate billing |

## Submitting a PR

1. One change per PR — keep diffs small
2. If touching `ref-pipeline.md`, verify the changed step manually with `/gauntlet` on a sample input
3. If adding a provider, include a one-line test in the PR description: `echo "hello" | bash providers/<name>.sh`
4. Update `README.md` and `README.ko.md` if user-visible behavior changes

## Good First Issues

- Add a provider (Mistral, Cohere, Ollama local)
- Improve error messages in `providers/*.sh`
- Add `bats` unit tests for provider scripts
- Translate README to another language

## Code Style

- bash: `set -euo pipefail` at the top of every script
- API keys: never in command-line arguments — use `-H @file` or environment variables
- Python inline scripts: keep under 30 lines; extract to a `.py` file if longer
