# gauntlet

> [한국어](README.ko.md) | English
> **Canonical source: README.md (English). README.ko.md is a translation and may lag behind.**

> **Named after "to run the gauntlet"** — the ordeal of passing through a line of critics, one after another. That's exactly what gauntlet makes your design do.

**Solo AI flatters. gauntlet challenges.**

![gauntlet demo](assets/demo.gif)

**Make your AI attack your design, not agree with it.**

When you ask an AI to review your code, it finds reasons to approve — not problems to fix. gauntlet flips this:

- Ask 2–3 models independently → parallel opinions, no accumulation
- **gauntlet** → each AI's critique becomes the next AI's attack surface

Not tabs. Not parallel queries. **Sequential critique that accumulates.**

**Stage 1** — Free. Python 3 only. No API key required. Start now.  
**Stage 2** — Cross-validate with Gemini / OpenAI / Claude API (Verified Output).

> ⚠️ **Stage 1 limitation**: Stage 1 uses the same Claude model across all review steps — only the critique lens changes. This means bias can be shared across all lenses. Stage 1 output is labeled **Advisory** for this reason: treat it as a structured self-review aid, not an independent audit.  
> For high-stakes decisions (security, architecture), Stage 2 with external providers is recommended.  
> **Results never auto-confirm — your explicit approval is always required.**

---

## Who this is for

Claude Code users who have felt AI review is too agreeable. Specifically:

- You've received "Looks good" from an AI and merged — only to find a bug later
- You switch tabs to ask multiple models, but their answers don't build on each other
- You want counterarguments *before* you present a design to your team
- You're making a security or architecture change and need more than one perspective

---

## Why gauntlet?

| Approach | Problem |
|----------|---------|
| Ask Claude once | AI agrees with your framing |
| Switch tabs, ask 3 models | Parallel opinions — critiques don't compound |
| PR review bots | Improved in 2025 (Copilot Code Review GA, CodeRabbit support multi-round comments), but typically single-vendor, no sequential cross-critique between models |
| **gauntlet** | Each AI inherits the previous critique. Multiple perspectives reduce the chance of repeating the same oversight. |

**2026 context**: AI coding tools make building faster — but faster-wrong is worse than slow-right. As AI sycophancy and AI-generated code proliferate, adversarial review infrastructure has become the missing layer. gauntlet is that layer.

Built-in advantages:
- 🔍 **Multiple perspectives** — sequential critique surfaces issues that a single-pass review may miss
- 🔒 **Human control** — HIL gate blocks auto-finalization; your sign-off is always required
- 🔌 **Extensible** — add custom providers via `providers/{name}.json` + `providers/{name}.sh`; pipeline dispatch is manifest-driven (requires `governance_rules.json` registration)
- 📋 **Audit trail** — session history saved in `~/.gauntlet/sessions/` for traceability
- 💸 **Free to start** — Stage 1 needs no API key, no external service

---

## When to use

- Before a team code review, when you want to gather counterarguments yourself first
- Before an architecture decision, when you need to check "what have I missed?"
- After a security code change, when you need a quick vulnerability scan
- When you're worried about bias from relying on a single AI model's opinion

## When NOT to use

- Automated deployment gates (even with Advisory / Verified labels, results do not replace human review)
- Simple queries (asking Claude directly is faster)
- As a substitute for human code review — a gauntlet pass does not mean the code is safe
- As a security audit — CRITICAL findings are starting points for investigation, not a complete vulnerability list

---

## Installation

### Pre-flight check

```bash
command -v python3 >/dev/null 2>&1 || { echo "python3 is required. Install: brew install python3"; exit 1; }
# curl is required for Stage 2 only:
# command -v curl >/dev/null 2>&1 || { echo "curl is required for Stage 2"; exit 1; }
```

### Install

> ⚠ **This overwrites an existing installation.** Back up custom changes in `~/.claude/skills/gauntlet/` before running.

```bash
# Run this entire block at once
# 1. Clone the repository (skip if already cloned)
[ ! -d gauntlet-skill ] && git clone https://github.com/aniboy2k-gif/gauntlet-skill.git
cd gauntlet-skill
set -e

# 2. Copy skill files
#    Note: This overwrites an existing installation. Back up custom changes first.
mkdir -p ~/.claude/skills/
cp -r gauntlet/ ~/.claude/skills/gauntlet/

# 3. Grant execute permission to provider scripts (required for Stage 2)
find ~/.claude/skills/gauntlet/providers -maxdepth 1 -name '*.sh' -exec chmod +x {} +

# 4. (Recommended) Symlink data directory to workspace
#    Default: ~/workspace/gauntlet-data. Override by setting GAUNTLET_DATA before running.
GAUNTLET_DATA="${GAUNTLET_DATA:-$HOME/workspace/gauntlet-data}"
mkdir -p "$GAUNTLET_DATA"

if [ -L "$HOME/.gauntlet" ]; then
  echo "~/.gauntlet symlink already exists — skipping."
elif [ -d "$HOME/.gauntlet" ]; then
  echo "~/.gauntlet is a real directory. To replace with a symlink:"
  echo "  mv ~/.gauntlet \"$GAUNTLET_DATA\" && ln -s \"$GAUNTLET_DATA\" ~/.gauntlet"
  echo "  If the symlink fails, restore with: mv \"$GAUNTLET_DATA\" ~/.gauntlet"
elif [ -e "$HOME/.gauntlet" ]; then
  echo "~/.gauntlet exists (not a directory or symlink). Check manually."
else
  ln -s "$GAUNTLET_DATA" "$HOME/.gauntlet" && echo "Symlink created: ~/.gauntlet → $GAUNTLET_DATA"
fi

set +e
# 5. Verify
ls ~/.claude/skills/gauntlet/SKILL.md \
  && find ~/.claude/skills/gauntlet/providers -name '*.sh' -perm -u+x | grep -q . \
  && echo "✅ Installation complete" \
  || echo "⚠ Verification failed — check the steps above."
```

> **Note**: `ln -s` is not silent on failure — if `~/.gauntlet` already exists, it prints an error to stderr (e.g., `ln: ~/.gauntlet: File exists`). The script above handles all cases explicitly so this should not occur during a normal install.

---

## Quick Start

### 1. Use it right now (no setup needed)

```bash
/gauntlet Is there a problem with this authentication system design?
/gauntlet --role security Find vulnerabilities in this JWT implementation
/gauntlet --tier 1 Review this entire architecture design
```

### 2. For external AI cross-validation (optional)

```bash
/gauntlet --setup    # API key setup wizard — run once
/gauntlet --stage 2 Cross-validate this design with external AI
```

### 3. Reading the results

```
Advisory Output  → Stage 1 (Claude internal review — same model, different angles)
Verified Output  → Stage 2 (includes external AI from different vendors)

Issues classified as CRITICAL / HIGH / MEDIUM / LOW
Final verdict: "Approval possible + number of unresolved CRITICALs"

Consensus tags:
  [Strong consensus]       2+ AIs found the same issue with independent evidence
  [Single AI: Gemini]      Only 1 AI found it — external validation recommended

Recommended next steps by severity:
  CRITICAL → Stop. Investigate and resolve before merge or deployment.
  HIGH     → Address before team review. Document if deferring.
  MEDIUM   → Review and triage. Acceptable to defer with a ticket.
  LOW      → Consider in next refactor pass. Safe to defer.

* A Human-in-the-Loop (HIL) gate fires at the final step.
  Results remain in Draft state until you explicitly accept them.
  Note: gauntlet supports both English and Korean confirmation phrases.
  To accept: type "확정해주세요", "이대로 Finalized 처리", "confirm", or "finalize"
  Not accepted: "좋네요", "네", "looks good", or "ok" alone are not accepted as confirmation.
```

#### Example output (Stage 1, Tier 2)

```
📊 Tier: 2 | Stage 1 (Advisory) | Role: security
Reason: JWT implementation — security-sensitive

[Step 1/5] Initializing session...
[Step 2/5] Draft analysis...
[Step 3/5] DA review (attack-surface lens)...
  → CRITICAL: JWT secret stored in env without rotation policy
  → HIGH: No token expiry validation on refresh path
[Step 4/5] Reflection...
[Step 5/5] Synthesis

Advisory Output
──────────────
CRITICAL (1): Secret management — no rotation path defined
HIGH    (1): Missing expiry check on /auth/refresh
MEDIUM  (0): —
LOW     (2): Logging gaps, no rate-limit on token endpoint

Verdict: Review required before merge. 1 unresolved CRITICAL.
[Single AI: Claude] — Stage 2 recommended for independent validation.

* HIL gate active. Type "확정해주세요", "confirm", or "finalize" to finalize.
```

---

## How It Works

### What is Devil's Advocate (DA)?

Originally from the Catholic canonization process — before a decision is made, someone deliberately takes the opposing position to stress-test the reasoning. gauntlet implements this as an AI pipeline. Each reviewer is designed to criticize, not agree. **Sequential**, not parallel: each AI receives the previous AI's critique as input, so criticism accumulates rather than resets.

### Execution flow

**Stage 1, Tier 2 example** (5 steps shown to user):

```
/gauntlet [topic]
    ↓ [1] Claude — Draft analysis
    ↓ [2] Claude — DA #1 (conservative lens: worst-case, all assumptions questioned)
    ↓ [3] Claude — Reflection #1 (draft updated with DA findings)
    ↓ [4] Claude — Synthesis
    ↓ [5] HIL gate — waits for your explicit confirmation
```

**Stage 1, Tier 1** (7 steps): adds a second DA round + reflection before synthesis.  
**Stage 2**: replaces Claude subagents with external provider chain (Gemini → OpenAI → Claude API).

> Note: The step count shown to users excludes internal initialization steps. `ref-pipeline.md` defines Steps 1–10 including session setup, lock management, and cleanup.

> **Independence Caveat (Stage 1)**: All review steps use the same Claude model. Sequential critique changes the *framing* of each step, not the underlying model. This can surface issues that a single-pass review may miss, but does not eliminate shared model bias. For decisions where model independence matters, use Stage 2 with external providers.

### Execution Mode (Stage) — determined by setup

| | Stage 1 | Stage 2 |
|---|---|---|
| Setup | Not required | `/gauntlet --setup` |
| Method | Claude subagents, multiple lenses in sequence | Configurable 1–3 provider chain (Tier 1: P1→P2→P3, Tier 2: P1→P2) |
| Independence | Same model, different perspectives (shared bias possible) | Different vendor models — higher independence. Note: orchestrator layer (Claude) still frames each prompt. |
| Cost | Free | Based on API usage |
| Output label | Advisory Output | Verified Output |

### Review depth (Tier) — auto-detected based on risk and impact

| Tier | Detection criteria (examples) | Steps |
|------|-------------------------------|-------|
| Tier 1 | Security-related, architecture change, broad impact | 7-step review (Draft → 2× DA + 2× Reflection → Synthesis → HIL) |
| Tier 2 | Single feature, document review | 5-step review (Draft → 1× DA + 1× Reflection → Synthesis → HIL) |
| Tier 3 | Typos, formatting | Claude solo review (DA skipped) |

**Tier detection examples:**

| Input | Detected Tier | Reason |
|-------|---------------|--------|
| `JWT implementation review` | Tier 1 | Security-sensitive |
| `Review this API response structure` | Tier 2 | Single-feature scope |
| `Fix typo in README` | Tier 3 | Formatting only |
| `Refactor auth middleware across 5 files` | Tier 1 | Broad impact |

You can force a tier with `--tier 1`. Tier 3 is only for changes with effectively zero review impact.

---

## Roles (--role)

Injects a criticism lens tailored to the review topic. If omitted, auto-selected by analyzing TOPIC.

A lens is a specialized critique perspective injected at each review step.

| Key | When to use |
|----|------------|
| `default` | General design and implementation |
| `security` | Authentication, sessions, input handling, vulnerabilities |
| `architecture` | New architecture, layer structure, interface design |
| `log-debug` | Error logs, incident root cause tracing |
| `writing` | Guides, technical docs, READMEs |

---

## Stage 2 Setup

> **Read first**: gauntlet uses dedicated `GAUNTLET_*` variables — not your system-wide API keys — for two reasons: (1) to prevent unintended pay-per-use billing on your existing Claude Max/Pro plan, and (2) to keep gauntlet's API costs separately trackable from other tools. Do not copy your existing `ANTHROPIC_API_KEY` into `GAUNTLET_CLAUDE_KEY` unless you specifically want to use a different billing account.

| Provider | Use this variable | Do NOT use |
|---------|-------------------|-----------|
| Claude API | `GAUNTLET_CLAUDE_KEY` | `ANTHROPIC_API_KEY` |
| Gemini | `GAUNTLET_GEMINI_KEY` | `GOOGLE_API_KEY` |
| OpenAI | `GAUNTLET_OPENAI_KEY` | `OPENAI_API_KEY` |

### Setup wizard

Run `/gauntlet --setup` and follow the prompts:

1. **Provider selection** — choose multiple from `gemini`, `openai`, `claude` (v1.0 supported providers)
2. **API key storage** — environment variable / macOS Keychain / encrypted file
3. **Aggregation mode** — how multiple AI findings are combined:
   - `consensus`: only issues found by 2+ AIs are surfaced (lower noise, may miss edge cases)
   - `union`: all issues from any AI are included (higher coverage, more review effort)
   - `weighted`: issues weighted by AI confidence score (balanced, default recommended)
4. **Budget cap** — per-session API cost cap (default $1.00; **currently config storage only — real-time enforcement planned for v1.1. Monitor your API provider dashboard directly.**)
5. **Connection test** — verify actual connection with configured keys

### Adding a custom provider

Add `{name}.json` (manifest) and `{name}.sh` (API call script) to the `providers/` directory, then register `"<name>"` in `governance_rules.json` → `provider_registry.known_providers[]`. The pipeline dispatches providers dynamically — no changes to `SKILL.md` or `ref-pipeline.md` required. See `ref-provider-guide.md` for the full 5-step procedure.

---

## Comparison with ChatGPT integration (codex-plugin-cc)

OpenAI's **codex-plugin-cc** is an MCP plugin that calls ChatGPT as a tool from Claude Code. Claude asks ChatGPT questions when needed and retrieves results — a one-way structure.

gauntlet serves a different purpose.

| | codex-plugin-cc | gauntlet |
|---|---|---|
| Structure | Claude → ChatGPT one-way call | Multiple AIs sequential cross-critique |
| Purpose | Leverage ChatGPT's capabilities | Structured adversarial review — same orchestrator (Claude) frames all prompts |
| AI role | ChatGPT as Claude's tool | Each AI picks up the previous AI's critique, reducing the chance of repeating the same judgment error |
| Setup | 1 OpenAI API key required | Stage 1 requires no setup |

The two skills are not substitutes for each other. Including OpenAI in gauntlet Stage 2 is a natural combination.

---

## Session Management

```bash
/gauntlet --gc                     # Clean up old sessions (default: 30-day TTL, max 50)
/gauntlet --resume [session_id]    # Resume an interrupted session
```

---

## Requirements

### Supported environments

| Environment | Supported |
|-------------|-----------|
| Claude Code CLI (`claude`) | ✅ |
| VSCode Claude Code extension | ✅ |
| JetBrains Claude Code extension | ✅ |
| Claude desktop app (claude.ai app) | ❌ |

> The Claude desktop app is not Claude Code. It does not support `/gauntlet` slash commands or the Bash tool.

### Dependencies

- **Python 3** — Required for all stages. Used for session initialization, session.json management, result.json generation, and more. Fails immediately at Step 1 if missing.
  - macOS Monterey and later: pre-installed
  - Linux: check with `python3 --version`. Install with `sudo apt install python3` if missing
  - Windows: untested (WSL recommended)
- Stage 2 only: `curl` + API key (at least one of Gemini / OpenAI / Claude API)

---

## Known Limitations

- **Stage 1 bias**: Stage 1 uses the same Claude model across all review steps — only the critique lens changes. All lenses share the same training bias. This is a fundamental structural limitation; Stage 1 output is labeled Advisory for this reason. For security or architecture decisions with real consequences, use Stage 2.
- **Budget cap**: ⚠️ The API cost cap currently only saves the config value — it does **not** block requests or enforce a spend limit. Real-time enforcement is planned for v1.1 (planned mechanism: pre-flight cost estimate via provider token-count API + per-session hard cap with early exit). Until then, monitor your API provider dashboard directly. Tier 1 Stage 2 makes up to 3 provider calls per session; check your provider's usage page before running in batch.
- **Degraded Mode**: If a provider fails (API quota exceeded, connection error), that provider is SKIPPED and only partial results are shown. If 2 or more providers are SKIPPED in Tier 1, auto-finalization is blocked (**INSUFFICIENT COVERAGE**) — retry or switch to manual review.
- **CDP**: Chrome DevTools Protocol integration is not supported and not planned. (gauntlet uses direct API calls and Claude subagents, not browser automation.)
- **Output scope**: Results are for reference only. Does not replace professional review, legal, or security audits.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `AUTH: GAUNTLET_*_KEY not set` | Environment variable missing | Export the key in your shell: `export GAUNTLET_GEMINI_KEY=...` |
| `NETWORK: JSON parse failed` | Provider returned unexpected response | Check your API key is valid. Run the connection test: `/gauntlet --setup` |
| `RATE_LIMIT: ...` | API quota exceeded | Wait and retry, or switch to a different provider |
| `python3: command not found` | Python 3 not installed | Install Python 3 (`brew install python3` on macOS) |
| Session hangs at HIL gate | Waiting for explicit confirmation | Type `확정해주세요`, `이대로 Finalized 처리`, `confirm`, or `finalize` |
| Stage 2 not running | Stage 2 not configured | Run `/gauntlet --setup` first |
| `/gauntlet --resume` fails | Session ID not found or expired | Check `~/.gauntlet/sessions/` for available sessions. Run `--gc` to clean up. |

---

## Translation Roadmap

| Document | Current | Target | Timeline |
|----------|---------|--------|----------|
| README.md | ✅ English | — | Done |
| README.ko.md | ✅ Korean | — | Done |
| SKILL.md (frontmatter + messages) | ✅ English | — | Done |
| providers/*.sh (comments) | ✅ English | — | Done |
| providers/*.json (lens_hint) | ✅ English | — | Done |
| gauntlet-roles.json (description/use_when/avoid_when) | ✅ EN+KO locale map | — | Done |
| ref-pipeline.md | Korean + English Overview | Full English | v2 (medium-term) |
| ref-setup.md | Korean + English Overview | Full English | v2 (medium-term) |
| ref-ops.md | Korean + English Overview | Full English | v2 (medium-term) |
| ref-common.md | Korean + English Overview | Full English | v2 (medium-term) |
| ref-provider-guide.md | Korean + English Overview | Full English | v2 (medium-term) |

> **v1.1 milestone**: Each ref file now has an English Overview comment block at the top. Full English translation of procedural body text remains v2.

---

## File Structure (Reference)

```
~/.claude/skills/gauntlet/
├── SKILL.md                  — Execution instructions (router)
├── ref-pipeline.md           — Steps 1–10 main pipeline
├── ref-setup.md              — --setup wizard procedure
├── ref-ops.md                — --gc / --resume procedure
├── ref-common.md             — session.json schema, atomic write patterns
├── ref-provider-guide.md     — Guide for adding new providers
├── gauntlet-roles.json       — Role definitions (single source of truth)
├── governance_rules.json     — DA coverage rules (thresholds, exit code mapping)
├── config.example.json       — ~/.gauntlet/config.json template
├── project.example.json      — Per-project .gauntlet.json template
└── providers/
    ├── gemini.json           — Gemini integration manifest
    ├── gemini.sh             — Gemini API call script
    ├── openai.json           — OpenAI integration manifest
    ├── openai.sh             — OpenAI API call script
    ├── claude.json           — Claude API integration manifest
    └── claude.sh             — Claude API call script

~/.gauntlet/                  — Runtime (auto-created on first run)
├── config.json               — Created by /gauntlet --setup
├── audit.log                 — Operations audit log
└── sessions/{project_id}/{session_id}/
    ├── session.json          — Session metadata (immutable)
    ├── session.lock          — PID lock (removed after HIL acceptance)
    ├── result.json           — Final result
    └── r0-draft.txt, r1-*.txt ...
```

To add a new provider, see `ref-provider-guide.md`. You can extend the chain without modifying `SKILL.md`.
