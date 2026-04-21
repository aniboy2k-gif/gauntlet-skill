# ref-provider-guide.md — gauntlet 신규 Provider 추가 가이드
#
# 이 파일은 운영 문서입니다. SKILL.md를 수정하지 않고 AI 제공자를 추가하는 방법을 안내합니다.
# 트리거: /gauntlet --add-provider <name> (또는 사용자 직접 참조)
#

<!-- English Overview (for non-Korean contributors)
  File: ref-provider-guide.md
  Role: Operational guide for adding new Stage 2 AI providers without modifying SKILL.md.
  Triggered by: /gauntlet --add-provider <name> or direct reference by the operator.
  Steps covered: API key storage (env / keychain / file), config.json providers[] entry,
    role mapping, Keychain service name convention (gauntlet-<provider>),
    and smoke-test checklist before enabling in production sessions.
-->
# v1.2 현재 상태 (C2 fix 이후):
# providers/*.sh는 ref-pipeline.md가 config.providers[]를 읽어 동적으로 호출합니다.
# 하드코딩된 gemini/openai/claude 분기가 제거되어 manifest-driven 방식으로 동작합니다.
# 신규 Provider를 추가하려면:
#   1. providers/<name>.sh + providers/<name>.json 생성
#   2. governance_rules.json known_providers[]에 "<name>" 등록 (미등록 시 Hard Fail)
#   3. config.json providers[]에 활성화
# ref-pipeline.md 수정 불필요 — 동적 dispatch로 자동 인식됩니다.

---

## 신규 Provider 추가 (OCP 가이드)

**SKILL.md를 수정하지 않고** 신규 AI 제공자를 추가할 수 있다. `providers/<name>.json` + `providers/<name>.sh` 두 파일만 추가하면 된다.

### 파일 구조

```
~/.claude/skills/gauntlet/providers/
├── gemini.json       ← manifest (API 메타데이터)
├── gemini.sh         ← executable (stdin→stdout, exit 0/1/2/3)
├── openai.json
├── openai.sh
├── claude.json
└── claude.sh
```

### manifest 스키마 (`providers/<name>.json`)

```json
{
  "schema_version": "1.0",
  "name": "<name>",
  "display_name": "표시용 이름",
  "key_env": "GAUNTLET_<NAME>_KEY",
  "key_service": "gauntlet-<name>",
  "default_model": "모델명",
  "lens_hint": "비판 관점 한 줄 힌트",
  "timeout_sec": 60
}
```

| 필드 | 필수 | 설명 |
|------|------|------|
| `schema_version` | ✅ | "1.0" 고정 |
| `name` | ✅ | 파일명과 동일 (소문자, kebab-case) |
| `key_env` | ✅ | API 키 환경변수명 (`GAUNTLET_` 접두어 필수) |
| `key_service` | ✅ | Keychain 서비스명 (`gauntlet-` 접두어 필수) |
| `default_model` | ✅ | 기본 모델 ID |
| `lens_hint` | ✅ | 역할 프롬프트에 추가될 관점 힌트 |
| `timeout_sec` | ✅ | 최대 실행 시간(초) |

### executable 계약 (`providers/<name>.sh`)

```
stdin  : 검토할 텍스트 (UTF-8)
stdout : CRITICAL/HIGH/MEDIUM/LOW 계층 분류 결과
stderr : 오류 메시지 (PROVIDER_ERROR: AUTH|RATE_LIMIT|NETWORK|CONTRACT)
exit   : 0=성공  1=VALIDATION_FAILED  2=PROVIDER_ERROR  3=CONTRACT_BROKEN
```

exit code는 governance_rules.json `exit_code_to_skip_mapping`과 연동된다:
- exit 0·1: SKIPPED 카운트 증가 없음
- exit 2·3: SKIPPED +1

### 예시: `providers/mistral.sh`

```bash
#!/bin/bash
# Mistral AI provider for gauntlet
PROMPT=$(cat)
MISTRAL_KEY="${GAUNTLET_MISTRAL_KEY:-}"

if [ -z "$MISTRAL_KEY" ]; then
  echo "PROVIDER_ERROR: AUTH — GAUNTLET_MISTRAL_KEY not set" >&2
  exit 2
fi

RESPONSE=$(curl -s -X POST "https://api.mistral.ai/v1/chat/completions" \
  -H "Authorization: Bearer $MISTRAL_KEY" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "
import json, sys
prompt = sys.stdin.read()
print(json.dumps({'model': 'mistral-large-latest', 'messages': [{'role': 'user', 'content': prompt}]}))
" <<< "$PROMPT")")

python3 -c "
import json, sys

def parse_raw_json(raw):
    try:
        return json.loads(raw)
    except Exception as e:
        sys.stderr.write(f'NETWORK: JSON parse failed — {e}\n')
        sys.exit(2)

def classify_provider_error(d):
    if d.get('object') == 'error':
        msg = d.get('message', '')
        if 'Unauthorized' in msg or 'API key' in msg:
            return 'AUTH'
        if 'rate limit' in msg.lower():
            return 'RATE_LIMIT'
        return 'NETWORK'
    return None

def extract_response_text(d):
    try:
        return d['choices'][0]['message']['content']
    except (KeyError, IndexError, TypeError) as e:
        sys.stderr.write(f'CONTRACT: unexpected Mistral response shape — {e}\n')
        sys.exit(3)

d = parse_raw_json(sys.stdin.read())
err_type = classify_provider_error(d)
if err_type:
    sys.stderr.write(f'{err_type}: Mistral API error\n')
    sys.exit(2)
print(extract_response_text(d))
" <<< "$RESPONSE"
```

### 신규 Provider 등록 절차 (5단계)

1. `providers/<name>.json` 작성 (manifest 스키마 준수)
2. `providers/<name>.sh` 작성 (executable 계약 준수, chmod +x)
3. **`governance_rules.json`의 `provider_registry.known_providers[]`에 `"<name>"` 추가** ← 필수
   - 미등록 시 SKILL.md Step 0-D에서 Hard Fail (exit 2) — 파이프라인 진입 불가
   - SSOT: governance_rules.json `provider_registry.unknown_provider_action: "hard_fail"`
4. `~/.gauntlet/config.json`의 `providers` 배열에 `"<name>"` 추가
5. `GAUNTLET_<NAME>_KEY` 환경변수 또는 Keychain 등록

**ref-pipeline.md 수정 불필요** — config.providers[]에서 동적으로 dispatch되므로 Step 3/5/7 코드 변경 없음.
**SKILL.md 수정 불필요** — Step 0-D가 governance_rules.json을 SSOT로 검증한다.
