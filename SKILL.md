---
name: gauntlet
description: |
  Multi-agent Devil's Advocate review pipeline for code, architecture, and security.
  Chains Gemini → ChatGPT → Claude in sequential critique. Outputs CRITICAL/HIGH/MEDIUM/LOW.
  Stage 1 (no API key) → Advisory Output. Stage 2 (external AI APIs) → Verified Output.
argument-hint: '[topic to review] | --setup | --gc [--dry-run] | --resume [session_id]'
---

> **⚠️ gauntlet 산출물은 자동 배포 게이트로 사용 불가. 체크리스트 입력 전용.**
> **⚠️ Advisory Output (Stage 1) 한계**: 동일 Claude 모델 복수 렌즈 실행. 독립적 외부 AI 교차 검증이 없어 `codex-da-chain` Tier 1(4-AI Verified) 대체 불가.
> **⚠️ claude provider 동일 계열**: Stage 2에서 claude provider를 마지막 DA로 사용하는 경우 ai-role-assignment.md §1에 따라 HIL 게이트가 강제됩니다. 자동 최종화 불가.

# /gauntlet 스킬 (라우터)

## 경로 상수 (모든 하위 절차에서 이 상수만 사용 — 경로 리터럴 금지)

`GAUNTLET_SKILL_DIR = ~/.claude/skills/gauntlet/`

---

## ARGUMENTS 없이 호출된 경우

ARGUMENTS가 비어 있으면 아래 메시지만 출력하고 **즉시 종료**한다.

```
Usage: /gauntlet [topic to review]

Examples:
  /gauntlet Is there a problem with this authentication system design?
  /gauntlet --tier 2 Review this API response structure
  /gauntlet --role security Find security vulnerabilities in this code
  /gauntlet --stage 2 Review this design with external AI models

Options:
  --tier 1|2|3       Review depth (auto-detected if omitted)
  --role [key]       Role key (default|security|architecture|log-debug|writing)
  --stage 1|2        Execution mode (auto-detected from config if omitted)
  --id [name]        Session identifier (UUID[:8] if omitted)

Subcommands:
  --setup            Run initial configuration wizard
  --gc [--dry-run]   Run session garbage collection (--dry-run: preview only, no deletion)
  --resume [id]      Resume an interrupted session
```

---

## Step 0: 파싱 및 판정

### 0-A: 서브커맨드 감지 및 라우팅

ARGUMENTS에서 첫 단어를 확인한다:

- `--setup` →
  Read 툴: `{GAUNTLET_SKILL_DIR}/ref-setup.md`
  ⚠ Read 실패 시:
  ```
  🚨 ref 파일 없음: ref-setup.md
  경로: ~/.claude/skills/gauntlet/ref-setup.md
  다음 액션: gauntlet 재설치 또는 경로 확인
  ```
  → **세션 없이 stderr 출력 후 중단** (session.json 접근 없음)
  Read 성공 시 → 해당 파일의 --setup 절차 실행, **이후 단계 건너뜀**

- `--gc` →
  `--dry-run` 플래그가 함께 있으면 GC_DRY_RUN=true로 설정하고 ARGUMENTS에서 `--dry-run` 제거.
  Read 툴: `{GAUNTLET_SKILL_DIR}/ref-ops.md`
  ⚠ Read 실패 시: 동일 패턴으로 stderr 출력 후 중단
  Read 성공 시 → --gc 섹션 실행 (GC_DRY_RUN 변수 전달), **이후 단계 건너뜀**

- `--resume` →
  Read 툴: `{GAUNTLET_SKILL_DIR}/ref-ops.md`
  ⚠ Read 실패 시: 동일 패턴으로 stderr 출력 후 중단
  Read 성공 시 → --resume 섹션 실행, **이후 단계 건너뜀**

- 그 외 → Step 0-B로 계속

### 0-B: ARGUMENTS 파싱

**구분자 규칙 (POSIX 표준)**:
- 플래그 영역과 TOPIC은 ` -- ` (공백-더블대시-공백)으로 구분한다.
- `--` 이전 = 플래그 영역, 이후 전체 = TOPIC
- `--` 없으면 → 나머지 전체를 TOPIC으로 사용 (하위 호환)
- 단, TOPIC 영역에서 `--role`, `--tier`, `--stage`, `--id` 토큰이 감지되면 warnings에 추가한다.

아래 순서로 추출한다. 각 항목 추출 후 해당 부분을 텍스트에서 제거한다.
1. `--tier [123]` → TIER 값 추출
2. `--role \S+` → ROLE 키 추출
3. `--stage [12]` → STAGE 값 추출
4. `--id \S+` → SESSION_NAME 추출
5. 나머지 전체 → 검증 대상 텍스트 (TOPIC)

**파싱 결과 구조**:
- `parsed_flags`: {tier, role, stage, id}
- `topic`: 검증 대상 텍스트
- `delimiter_present`: bool
- `warnings`: []

warnings가 있으면 파싱 직후 출력한다:
```
⚠ 파서 경고:
• {경고 내용}
```

### 0-C: 설정 로드

Read 툴로 `$HOME/.gauntlet/config.json`을 읽는다. 파일이 없으면 아래 배너를 출력한다:

```
╔══════════════════════════════════════════════════════════════╗
║  STAGE 1 — Advisory Mode (no external AI configured)        ║
║  All review steps use the same Claude model.                ║
║  Output label: Advisory Output (not Verified Output)        ║
║  To enable external AI cross-validation: /gauntlet --setup  ║
╚══════════════════════════════════════════════════════════════╝
```

설정 파일이 **있으면** 아래 값을 로드한다:
- `providers[]`: 설정된 API 제공자 목록 (빈 배열이면 Stage 1)
- `key_storage`: "env" | "keychain" | "file"
- `aggregation_mode`: "consensus" | "union" | "weighted"
- `budget.per_session_usd` (기본 1.00)
- `budget.per_role_usd` (기본 0.30)

설정 파일 로드 후 — `key_storage`가 `"keychain"`이고 `providers`가 1개 이상이면 즉시 Keychain 접근 가능 여부를 사전 검증한다:

```bash
python3 << 'PYEOF'
import json, os, subprocess

config = json.load(open(os.path.expanduser('~/.gauntlet/config.json')))
providers = config.get('providers', [])
storage = config.get('key_storage', 'env')

if storage != 'keychain' or not providers:
    print("SKIP")
    exit(0)

service_map = {'gemini': 'gauntlet-gemini', 'openai': 'gauntlet-openai', 'claude': 'gauntlet-claude'}
failed = []
for p in providers:
    svc = service_map.get(p)
    if not svc: continue
    r = subprocess.run(['security', 'find-generic-password', '-s', svc, '-w'],
                      capture_output=True, text=True)
    if r.returncode != 0 or not r.stdout.strip():
        failed.append(p)

if failed:
    print(f"KEYCHAIN_LOCKED:{','.join(failed)}")
else:
    print("OK")
PYEOF
```

결과가 `KEYCHAIN_LOCKED:...` 이면:
```
⚠ Cannot read API keys from Keychain.
  Failed providers: {failed provider list}
  Fix: restart the terminal, then type 'continue'
  Or type 'stage1' to proceed with Stage 1 instead
```
- `continue` → Re-verify Keychain. Proceed if successful, repeat message if not.
- `stage1` → Force STAGE to 1 and continue.

**보안 경고 체크** (설정 로드 직후 항상 실행):
```bash
python3 -c "
import os
has_anthropic = 'ANTHROPIC_API_KEY' in os.environ and os.environ['ANTHROPIC_API_KEY']
has_gauntlet_claude = 'GAUNTLET_CLAUDE_KEY' in os.environ and os.environ['GAUNTLET_CLAUDE_KEY']
if has_anthropic and not has_gauntlet_claude:
    print('WARN_API_KEY_CONFLICT')
elif has_anthropic:
    print('WARN_ANTHROPIC_KEY_SET')
else:
    print('OK')
" 2>/dev/null
```

결과가 `WARN_API_KEY_CONFLICT` 이면 즉시 출력 (중단 없음):
```
⚠ API key conflict detected
  ANTHROPIC_API_KEY is set but GAUNTLET_CLAUDE_KEY is not.
  gauntlet uses GAUNTLET_CLAUDE_KEY first. Risk of unintended charges if not set.
```

결과가 `WARN_ANTHROPIC_KEY_SET` 이면:
```
ℹ Both ANTHROPIC_API_KEY and GAUNTLET_CLAUDE_KEY are set. gauntlet will use GAUNTLET_CLAUDE_KEY.
```

### 0-D: Stage 결정 (--stage 미지정 시)

governance_rules.json `provider_registry.known_providers`를 SSOT로 참조한다.

```bash
python3 << 'PYEOF'
import json, os, sys

config_path = os.path.expanduser('~/.gauntlet/config.json')
rules_path  = os.path.expanduser('~/.claude/skills/gauntlet/governance_rules.json')

if not os.path.exists(config_path):
    print(1)
    sys.exit(0)

config    = json.load(open(config_path))
providers = config.get('providers', [])

if not providers:
    print(1)
    sys.exit(0)

rules   = json.load(open(rules_path))
known   = rules.get('provider_registry', {}).get('known_providers', [])
unknown = [p for p in providers if p not in known]

if unknown:
    sys.stderr.write(
        f'\n🚨 Provider 등록 오류\n'
        f'  알 수 없는 provider: {unknown}\n'
        f'  알려진 provider: {known}\n'
        f'  수정: /gauntlet --setup 실행 또는 config.json providers[] 확인\n'
        f'  (신규 provider 추가 시 governance_rules.json known_providers에 먼저 등록 필요)\n'
        f'  종료 코드: 2 (Hard Fail)\n'
    )
    sys.exit(2)

print(2)
PYEOF
```

- `providers[]`가 비어 있거나 config 없으면 Stage 1
- 모든 provider가 `known_providers`에 있으면 Stage 2
- 하나라도 unknown이면 **Hard Fail (exit 2)** — 파이프라인 진입 금지

### 0-E: Tier 자동 판정 (--tier 미지정 시)

| Tier | 기준 | Stage 1 구성 | Stage 2 구성 |
|------|------|-------------|-------------|
| **1** | 아키텍처 변경 / 보안 관련 / 설계 전반 | 서브에이전트 R1→R2 + 종합 (7단계) | Provider1→Provider2→Provider3 (7단계) |
| **2** | 단일 기능 / 문서 검토 | 서브에이전트 R1 + 종합 (5단계) | Provider1→Provider2 (5단계) |
| **3** | 오탈자 / 포맷 / 단순 수정 | Claude 단독 (DA 없음) | Claude 단독 |

판정 결과 출력:
```
📊 Tier: N | Stage N → {Advisory Output / Verified Output} | Role: {role}
Reason: {one-line rationale}
```

Stage 1이면 출력 레이블 자리에 `Advisory Output`을, Stage 2이면 `Verified Output (pending)`을 표시한다.
사용자가 실행 전에 어떤 레이블의 결과를 받을지 항상 인지할 수 있도록 한다.

**Tier 3이면** Claude 단독 검토 결론만 출력하고 **종료**한다.

### 0-F: 역할 키 자동 선택 (--role 미지정 시)

TOPIC 내용을 분석하여 결정한다:
- 보안/인증/취약점 관련 → `security`
- 아키텍처/설계/인터페이스 관련 → `architecture`
- 문서/가이드/README 관련 → `writing`
- 로그/오류/장애 관련 → `log-debug`
- 그 외 → `default`

Read 툴로 `{GAUNTLET_SKILL_DIR}/gauntlet-roles.json`을 읽어 역할 정의를 로드한다.

### 0-G: 공통 컨텍스트 검증 (ref 호출 전 일괄 검증)

라우터가 아래 변수를 일괄 검증한 후 ref를 호출한다. ref 파일은 자기 전용 추가 검증만 수행 (공통 검증 중복 금지):

| 변수 | 검증 조건 | 실패 시 동작 |
|------|----------|------------|
| TIER | 1·2·3 중 하나 | "TIER 판정 실패" 출력 후 abort |
| STAGE | 1·2 중 하나 | "STAGE 판정 실패" 출력 후 abort |
| ROLE | gauntlet-roles.json에 존재하는 키 | default로 폴백 + 경고 출력 |
| TOPIC | 빈 문자열이면 abort | ARGUMENTS 없음 메시지 출력 후 종료 |

---

## 메인 파이프라인 진입

모든 Step 0 검증 완료 후:

Read 툴: `{GAUNTLET_SKILL_DIR}/ref-pipeline.md`

⚠ Read 실패 시:
```
🚨 ref file missing: ref-pipeline.md
Path: ~/.claude/skills/gauntlet/ref-pipeline.md
Next action: reinstall gauntlet or check the path
```
→ **세션 없이 stderr 출력 후 중단** (session.json 접근 없음)

Read 성공 시 → 해당 파일의 Step 1~10 절차를 따라 실행한다.
