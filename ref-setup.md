# ref-setup.md — gauntlet --setup 서브커맨드
#
# 이 파일은 SKILL.md 라우터가 --setup 감지 시 Read 툴로 로드한다.

<!-- English Overview (for non-Korean contributors)
  File: ref-setup.md
  Role: Handles the --setup subcommand — interactive wizard to create/update
    ~/.gauntlet/config.json (providers, key_storage, aggregation_mode, budget).
  Triggered by: /gauntlet --setup
  Writes: ~/.gauntlet/config.json
  Does NOT touch session files; no DA pipeline is run during setup.
-->

## 실행 컨텍스트
> 이 파일은 --setup 전용입니다. 아래 변수 중 DA_SESSION_DIR 등은 이 흐름에서 설정되지 않습니다.

| 변수명 | 의미 | 설정 위치 |
|--------|------|----------|
| GAUNTLET_SKILL_DIR | 스킬 디렉토리 경로 | SKILL.md 상수 |

---

## --setup 서브커맨드

`/gauntlet --setup` 호출 시 아래 절차를 순서대로 진행한다.

**1단계: 디렉토리 초기화 및 기존 설정 감지**

심링크 상태 확인 (MEMORY.md 설치 경로 정책):
```bash
if [ -d "$HOME/.gauntlet" ] && [ ! -L "$HOME/.gauntlet" ]; then
  echo "⚠ ~/.gauntlet/이 실제 디렉터리입니다 (심링크 아님)."
  echo "  \$WORKSPACE 심링크를 권장합니다:"
  echo "  ln -s \"\$WORKSPACE/gauntlet-data\" ~/.gauntlet"
  echo "  심링크 없이 계속 진행하려면 'continue' 입력:"
fi
```

```bash
mkdir -p "$HOME/.gauntlet/sessions"
touch "$HOME/.gauntlet/audit.log"
echo "✅ ~/.gauntlet/ 초기화 완료"
```

기존 설정 여부를 감지한다:
```bash
python3 << 'PYEOF'
import os, json, subprocess

config_path = os.path.expanduser('~/.gauntlet/config.json')
has_config = os.path.exists(config_path)

keychain_services = ['gauntlet-gemini', 'gauntlet-openai', 'gauntlet-claude']
has_keychain = any(
    subprocess.run(['security', 'find-generic-password', '-s', svc, '-w'],
                   capture_output=True).returncode == 0
    for svc in keychain_services
)

if has_config or has_keychain:
    parts = []
    if has_config: parts.append('config.json')
    if has_keychain: parts.append('Keychain 항목')
    print(f"기존 설정 발견: {', '.join(parts)}")
    print("Y. 전체 재설정 (기존 설정 덮어쓰기)")
    print("N. 제공자만 추가 (기존 config.json 보존)")
else:
    print("NO_EXISTING_CONFIG")
PYEOF
```

- 결과가 `NO_EXISTING_CONFIG` → 그냥 계속 진행
- `기존 설정 발견` 출력 시 사용자 입력 대기:
  - `Y` → 기존 config.json 삭제 후 처음부터 진행. Keychain 재등록 시 `-U` 플래그 사용
  - `N` → 7단계(config.json 저장)로 이동. 기존 설정 보존.

**2단계: API 제공자 선택**

사용자에게 묻는다:
```
어떤 API 제공자를 설정하시겠습니까? (공백 구분 복수 선택)
1. Gemini (Google AI Studio)
2. OpenAI (GPT-4o)
3. Claude API (Anthropic)
Stage 1만 사용: 'none' 입력
선택 (예: 1 2 또는 none):
```

'none' 입력 시 Stage 1 전용으로 설정하고 **3~6단계를 건너뛰어 7단계(config.json 저장)로 이동**한다.

선택한 제공자가 **Claude API(3번)만** 인 경우 아래 경고를 추가 출력한다:
```
⚠ 동일 AI 계열 경고
선택하신 제공자(Claude API)는 gauntlet 작성 AI와 동일한 Anthropic 계열입니다.
독립적 교차 검증 효과가 크게 저하됩니다.
권장: Gemini(1) 또는 OpenAI(2) 중 최소 1개를 함께 선택하세요.
이대로 진행하려면 'Y', 제공자를 다시 선택하려면 'N':
```

3번(Claude API) 선택 시 아래 경고를 **반드시 출력**한다:
```
⚠ ANTHROPIC_API_KEY 충돌 주의 (중요)
gauntlet의 Claude API는 GAUNTLET_CLAUDE_KEY 환경변수를 사용합니다.
절대 ANTHROPIC_API_KEY를 사용하지 마십시오.
올바른 설정: export GAUNTLET_CLAUDE_KEY="sk-ant-..."
```

**3단계: API 키 저장 방식 선택** (제공자를 1개 이상 선택한 경우)

현재 환경에 설정된 GAUNTLET_* 키 여부를 먼저 확인하여 출력한다:
```bash
python3 -c "
import os
env_status = {k: ('✓ 설정됨' if v else '✗ 미설정') for k, v in os.environ.items() if k.startswith('GAUNTLET_')}
if env_status:
    print('현재 설정된 GAUNTLET_* 환경변수:')
    for k, s in env_status.items():
        print(f'  {k}: {s}')
else:
    print('현재 설정된 GAUNTLET_* 환경변수 없음')
if 'ANTHROPIC_API_KEY' in os.environ:
    print()
    print('⚠ ANTHROPIC_API_KEY 감지! → 더 안전한 방식: Keychain(B) 또는 파일(C) 저장 권장')
"
```

```
API 키 저장 방식:
A. 환경변수 (GAUNTLET_GEMINI_KEY, GAUNTLET_OPENAI_KEY, GAUNTLET_CLAUDE_KEY)
   ⚠ gauntlet 전용 변수명만 사용 — ANTHROPIC_API_KEY/OPENAI_API_KEY 혼용 금지
B. Keychain (macOS 키체인 저장) — 권장
C. 파일 (~/.gauntlet/.keys 로컬 설정 파일, chmod 600) ⚠ 보안 주의
선택 (A/B/C):
```

선택 A이면:
---
📌 **환경변수 설정 절차**

`~/.zshrc`에 아래 내용을 추가하세요:
```bash
export GAUNTLET_GEMINI_KEY="여기에_Gemini_API_키"
export GAUNTLET_OPENAI_KEY="여기에_OpenAI_API_키"
export GAUNTLET_CLAUDE_KEY="여기에_Claude_API_키"
```
설정 후 `source ~/.zshrc` 실행. 완료 시 '1' 입력:

---

선택 B이면:
---
📌 **macOS Keychain 등록 절차**

**키 등록:**
```
security add-generic-password -s "gauntlet-gemini" -a "$USER" -w "GEMINI_API_KEY"
security add-generic-password -s "gauntlet-openai" -a "$USER" -w "OPENAI_API_KEY"
security add-generic-password -s "gauntlet-claude" -a "$USER" -w "CLAUDE_API_KEY"
```

**등록 확인:**
```
security find-generic-password -s "gauntlet-gemini" -w
```
⚠ 터미널에서 직접 실행하세요. 완료 시 '1' 입력:

---

선택 C이면:
```bash
python3 -c "
import json, os
keys = {}
# (사용자 입력 키 수집)
with open(os.path.expanduser('~/.gauntlet/.keys'), 'w') as f:
    json.dump(keys, f)
os.chmod(os.path.expanduser('~/.gauntlet/.keys'), 0o600)
"
```

**Full Access Key 처리**: 제공자별로 아래 질문을 출력한다:
```
이 키가 Scoped Key(제한된 권한 키)입니까?
  Y (Scoped/Restricted Key) / N (Full Access Key) / 모름:
```
N 또는 모름 선택 시:
```
⚠ Full Access Key는 탈취 시 요금 폭탄 위험이 있습니다.
계속하려면 "ACCEPT RISK"를 입력하십시오:
```
`ACCEPT RISK` 입력 없으면 해당 제공자의 키 등록을 건너뜁니다.

**4단계: 지출 한도 확인** (Stage 2 설정 시)

```
⚠ API 키 탈취 시 무제한 과금 위험이 있습니다.

필수 설정 (지금 바로):
  • Gemini:  Google AI Studio → Billing → Budget Alerts
  • OpenAI:  platform.openai.com → Settings → Limits → Monthly budget
  • Claude:  console.anthropic.com → Plans & Billing → Spend limits

각 플랫폼의 월별 지출 한도를 설정하셨습니까? (Y/N):
```
N 응답 시 설정 중단.

**5단계: 집계 알고리즘 선택**
```
Stage 2 결과 집계 방식:

A. consensus (권장) — 2개 이상 AI가 CRITICAL로 지적한 항목만 CRITICAL 확정
   적합: 일반적인 코드 검토, 문서 검증

B. union — 어느 AI든 CRITICAL이면 CRITICAL 채택
   적합: 보안 검증, 배포 전 최종 점검

C. weighted — AI별 가중치 × 심각도 점수 합산
   적합: AI별 신뢰도 데이터가 있는 숙련 사용자

선택 (A/B/C, 기본값 A):
```

**6단계: 예산 설정**

```
per-session 한도 USD (세션 1회당 상한선, 기본: 1.00):
per-role 한도 USD (역할별 상한선, 기본: 0.30):
```

**7단계: config.json 저장** (Write 툴로 `$HOME/.gauntlet/config.json` 생성).

audit.log에 `key_register` 이벤트 기록.

**providers/*.sh 실행 권한 검증** (Stage 2 설정 시 필수):
```bash
SKILL_DIR="${HOME}/.claude/skills/gauntlet"
MISSING_EXEC=""
for sh_file in "$SKILL_DIR/providers/"*.sh; do
  [ -f "$sh_file" ] || continue
  [ -x "$sh_file" ] || MISSING_EXEC="$MISSING_EXEC $sh_file"
done

if [ -n "$MISSING_EXEC" ]; then
  echo "⚠ 실행 권한 없는 provider 파일 감지:"
  for f in $MISSING_EXEC; do echo "  $f"; done
  echo "  자동 수정 중..."
  chmod +x "$SKILL_DIR/providers/"*.sh
  echo "  ✅ chmod +x 완료"
else
  echo "  ✅ providers/*.sh 실행 권한 정상"
fi
```

```
✅ gauntlet 설정 완료
Stage 1: 항상 사용 가능 (Advisory Output)
Stage 2: {설정된 제공자 목록} (Verified Output)
/gauntlet [내용] 으로 시작하세요.
```
