# ref-common.md — gauntlet 공통 유틸리티
#
# 참조 방향 (단방향): SKILL.md → 이 파일, ref-*.md → 이 파일
# ⚠ 이 파일 → ref-*.md 참조 절대 금지 (순환 방지)
# ⚠ 성장 임계선: 200줄 초과 시 카테고리별 분리 (ref-common-session / ref-common-budget / ref-common-format)

<!-- English Overview (for non-Korean contributors)
  File: ref-common.md
  Role: Shared utility functions referenced by SKILL.md and all ref-*.md files.
  Reference direction is strictly one-way: consumers → this file only.
    This file must never import or reference other ref-*.md files (circular prevention).
  Contents: session ID generation, SKIP_COUNT helpers, output formatting utilities,
    budget read helpers, and any cross-cutting logic reused by multiple ref files.
  Growth threshold: split into ref-common-session / ref-common-budget / ref-common-format
    if this file exceeds 200 lines.
-->

---

## 공통: session.json step 업데이트 (atomic write + immutable spread)

각 Step 완료 시 아래 패턴을 사용한다. STEP_NUM과 STEP_KEY를 실제 값으로 치환한다.

```bash
python3 << 'PYEOF'
import json, os

sess_path = os.path.join(os.environ.get('DA_SESSION_DIR', ''), 'session.json')
step_num = STEP_NUM    # 치환: 정수 (로그용 파생값)
step_key = "STEP_KEY"  # 치환: 문자열 (resume 정본)

try:
    with open(sess_path) as f:
        current = json.load(f)
    updated = {**current, 'current_step': step_num, 'current_step_key': step_key}
    tmp = sess_path + '.tmp'
    with open(tmp, 'w') as f:
        json.dump(updated, f, ensure_ascii=False, indent=2)
    os.replace(tmp, sess_path)  # atomic write (크래시 시 session.json 보호)
except (OSError, json.JSONDecodeError) as e:
    import sys
    sys.stderr.write(f'SESSION_UPDATE_FAILED: {e}\n')
PYEOF
```

**step_key 정의 (pipeline_version: 1.0):**

| step_key | step_num | 의미 |
|----------|----------|------|
| "initialized" | 0 | Step 1 완료 (세션 초기화) |
| "draft-done" | 1 | Step 2 완료 (Claude 초안) |
| "da-round-1-done" | 2 | Step 3 완료 (DA 1라운드) |
| "reflect-1-done" | 3 | Step 4 완료 (반영 1) |
| "da-round-2-done" | 4 | Step 5 완료 (DA 2라운드) |
| "reflect-2-done" | 5 | Step 6 완료 (반영 2) |
| "da-round-3-done" | 6 | Step 7 완료 (DA 3라운드) |
| "synthesis-done" | 7 | Step 8 완료 (최종 종합) |
| "result-generated" | 8 | Step 9 완료 (result.json 생성) |
| "finalized" | 9 | Step 10 HIL 승인 완료 |
| "blocked_missing_ref" | -1 | ref 파일 Read 실패로 중단 (session.json 없을 수 있음) |
| "insufficient_coverage" | -2 | SKIP_COUNT 임계 초과 |

---

## 공통: Budget Guard (Step 3/5/7 실행 전 호출)

```bash
BUDGET_CHECK=$(python3 << 'PYEOF'
import json, os

config_path = os.path.expanduser('~/.gauntlet/config.json')
session_path = os.path.join(os.environ.get('DA_SESSION_DIR', ''), 'result.json')

config = {}
if os.path.exists(config_path):
    try:
        with open(config_path) as f:
            config = json.load(f)
    except (OSError, json.JSONDecodeError):
        pass

per_session = config.get('budget', {}).get('per_session_usd', 1.00)
accumulated = 0.0
if os.path.exists(session_path):
    try:
        with open(session_path) as f:
            accumulated = json.load(f).get('accumulated_cost_usd', 0.0)
    except (OSError, json.JSONDecodeError):
        pass

if per_session > 0 and accumulated >= per_session:
    print('BUDGET_EXCEEDED')
else:
    print('OK')
PYEOF
)

if [ "$BUDGET_CHECK" = "BUDGET_EXCEEDED" ]; then
  echo "⚠ 예산 한도 도달 (한도: \$per_session_usd)"
  echo "계속 진행하시겠습니까? (Y/N):"
  # N 응답 시 세션 중단, audit.log에 quota_block 기록
fi
```

---

## 공통: 실패 메시지 포맷

```
SKIPPED 표시: "⚠ [N/M] {단계명} SKIPPED — {이유}"
ref 없음 표시: "🚨 ref 파일 없음: {파일명}\n경로: {경로}\n다음 액션: {권장 조치}"
```
