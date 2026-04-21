<!--
  동기화 정책: README.ko.md는 README.md(영문)를 원본으로 한다.
  README.md 수정 시 이 파일도 함께 수정해야 한다.
  PR 체크리스트: README.md를 수정했다면 아래를 확인하세요.
    - [ ] README.ko.md에도 동일 내용이 반영되었습니까?
-->

# gauntlet

> 한국어 | [English](README.md)
> **정본: README.md (영문). 이 파일(README.ko.md)은 번역본으로 내용이 최신 버전과 다를 수 있습니다.**

> **스킬명 "gauntlet"의 유래** — "run the gauntlet(수난의 행렬을 통과하다)"에서 왔습니다. 비판자들이 줄지어 서 있는 길을 통과해야 하는 시련. gauntlet은 당신의 설계에 바로 그 시련을 겪게 합니다.

**Solo AI flatters. gauntlet challenges.**

![gauntlet demo](assets/demo.gif)

**AI가 당신의 설계에 동의하는 대신 공격하게 만들어라.**

AI에게 코드 검토를 맡기면, 문제를 찾기보다 동의할 이유를 찾습니다. gauntlet은 이 패턴을 뒤집습니다:

- 2~3개 모델에 각각 물어보기 → 병렬 의견, 누적 없음
- **gauntlet** → 각 AI의 비판이 다음 AI의 공격 대상이 됨

탭 전환이 아닙니다. 병렬 쿼리도 아닙니다. **누적되는 순차 비판입니다.**

**Stage 1** — 무료. Python 3만 있으면 됩니다. API 키 불필요. 지금 바로 시작하세요.  
**Stage 2** — Gemini / OpenAI / Claude API로 교차 검증 (Verified Output).

> ⚠️ **Stage 1 한계**: Stage 1은 모든 검토 단계에서 동일한 Claude 모델을 사용하며, 비판 렌즈만 바뀝니다. 모든 렌즈가 동일한 학습 편향을 공유합니다. 이것이 Stage 1 결과물이 **Advisory** 레이블을 달고 있는 근본 이유입니다 — 독립 감사가 아닌 구조화된 자기 검토 보조 도구로 활용하세요.  
> 실질적 결과가 따르는 보안·아키텍처 결정에는 외부 제공자를 사용하는 Stage 2를 권장합니다.  
> **결과는 자동 확정되지 않습니다 — 항상 사용자의 명시적 수락이 필요합니다.**

---

## 이런 분들을 위해

Claude Code를 쓰면서 AI 검토가 지나치게 순응적이라고 느낀 개발자를 위한 스킬입니다:

- AI에게 "이상 없어 보입니다"를 받고 머지했다가 나중에 버그를 발견한 경험이 있는 분
- 탭을 전환해 여러 모델에 물어보지만 답변이 서로 이어지지 않는다고 느끼는 분
- 팀에 설계를 발표하기 전에 먼저 반론을 챙겨두고 싶은 분
- 보안·아키텍처 변경에서 하나의 관점 이상이 필요한 분

---

## 왜 gauntlet인가?

| 접근 방식 | 문제 |
|----------|------|
| Claude에 한 번 물어보기 | AI가 당신의 프레이밍에 동의 |
| 탭 전환해 3개 모델에 물어보기 | 병렬 의견 — 비판이 누적되지 않음 |
| PR 리뷰 봇 | 2025년 개선됨 (Copilot Code Review GA, CodeRabbit 다회 코멘트 지원), 하지만 대부분 단일 벤더이며 모델 간 순차 교차 비판 없음 |
| **gauntlet** | 각 AI가 이전 비판을 이어받아 검토. 같은 관점을 반복할 가능성을 줄임. |

**2026년 현재**: AI 코딩 도구가 개발 속도를 높이고 있지만, 빠르게 틀린 것은 느리게 맞는 것보다 나쁩니다. AI 동조성과 AI 생성 코드가 확산되면서, 적대적 검토 인프라가 빠진 레이어가 되고 있습니다. gauntlet이 그 레이어입니다.

내장된 강점:
- 🔍 **다각도 관점** — 순차 비판이 단일 패스 검토에서 놓칠 수 있는 이슈를 드러냄
- 🔒 **인간 통제** — HIL 게이트가 자동 최종화를 차단; 항상 사용자의 승인이 필요
- 🔌 **확장 가능** — `providers/{name}.json` + `providers/{name}.sh` 추가로 커스텀 provider 등록 가능. 파이프라인 dispatch는 manifest-driven (`governance_rules.json` 등록 필수)
- 📋 **감사 추적** — 세션 이력이 `~/.gauntlet/sessions/`에 저장됨 (추적·거버넌스 지원)
- 💸 **무료로 시작** — Stage 1은 API 키 없이, 외부 서비스 없이 시작 가능

---

## 언제 쓰는가

- 팀 코드 리뷰 전에 스스로 먼저 반론을 챙겨두고 싶을 때
- 아키텍처 결정 전에 "내가 놓친 게 있을까" 확인이 필요할 때
- 보안 코드 변경 후 빠른 취약점 점검이 필요할 때
- AI 한 모델의 의견만으로 편향이 걱정될 때

## 언제 쓰지 말아야 하는가

- 자동 배포 게이트 (Advisory / Verified 레이블이 붙어도 사람 검토를 대체하지 않습니다)
- 단순 질의 (바로 Claude에 물어보는 게 더 빠릅니다)
- 사람 코드 리뷰 대체재로 사용하는 경우 — gauntlet 통과가 코드 안전을 보증하지 않습니다
- 보안 감사 대체재로 사용하는 경우 — CRITICAL 발견 항목은 조사의 시작점이며 완전한 취약점 목록이 아닙니다

---

## 설치

```bash
# 1. 스킬 파일을 Claude Code 스킬 디렉터리에 복사
cp -r gauntlet/ ~/.claude/skills/gauntlet/

# 2. provider 스크립트 실행 권한 부여 (Stage 2 필수)
chmod +x ~/.claude/skills/gauntlet/providers/*.sh

# 3. (권장) 데이터 디렉터리를 워크스페이스로 심링크
#    스킬 디렉터리 외부에 세션 데이터를 보관 — 백업·버전 관리가 용이합니다.
#    $WORKSPACE를 실제 워크스페이스 경로로 교체하세요.
ln -s "$WORKSPACE/gauntlet-data" ~/.gauntlet
```

> **주의**: `~/.gauntlet/`이 이미 실제 디렉터리로 존재하면 심링크 생성이 조용히 실패합니다.
> `ls -la ~/.gauntlet`으로 확인 후, 실제 디렉터리라면 먼저 이동하세요:
> `mv ~/.gauntlet "$WORKSPACE/gauntlet-data" && ln -s "$WORKSPACE/gauntlet-data" ~/.gauntlet`

### 사전 확인

```bash
python3 --version   # 전 단계 필수. 없으면 Step 1에서 즉시 실패합니다.
curl --version      # Stage 2만 필요.
```

---

## 빠른 시작

### 1. 바로 써보기 (설정 불필요)

```bash
/gauntlet 이 인증 시스템 설계에 문제가 있는가?
/gauntlet --role security 이 JWT 구현에서 취약점을 찾아라
/gauntlet --tier 1 이 아키텍처 설계 전체를 검토해 달라
```

### 2. 외부 AI 교차 검증이 필요하다면 (선택 사항)

```bash
/gauntlet --setup    # API 키 설정 마법사 — 한 번만 실행
/gauntlet --stage 2 이 설계서를 외부 AI로 교차 검증해 달라
```

### 3. 결과 해석

```
Advisory Output  → Stage 1 (Claude 내부 검토 — 같은 모델, 다른 각도)
Verified Output  → Stage 2 (외부 AI 포함)

CRITICAL / HIGH / MEDIUM / LOW 로 이슈 분류
종합 판정: "승인 가능 여부 + 미해결 CRITICAL 수"

합의 태그:
  [강한 합의]       2개 이상 AI가 독립 근거로 같은 이슈 발굴
  [단일 AI: Gemini] 1개 AI만 발굴 — 외부 검증 권장

등급별 권장 다음 단계:
  CRITICAL → 즉시 중단. 머지 또는 배포 전에 조사하고 해결하세요.
  HIGH     → 팀 리뷰 전에 처리하세요. 미루는 경우 사유를 문서화하세요.
  MEDIUM   → 검토 후 우선순위 판단. 티켓을 남기고 미루는 것도 가능합니다.
  LOW      → 다음 리팩터 패스에서 고려하세요. 미루기 안전합니다.

* 최종 단계에서 사용자 수락 게이트(HIL)가 동작합니다.
  사용자가 명시적으로 수락하기 전까지 결과는 Draft 상태입니다.
  수락 방법: "확정해주세요" 또는 "이대로 Finalized 처리"
  주의: "좋네요" 또는 "네" 단독은 수락으로 인정되지 않습니다.
```

#### 출력 예시 (Stage 1, Tier 2, security 역할)

```
📊 Tier: 2 | Stage 1 (Advisory) | 역할: security
이유: JWT 구현 — 보안 민감

[1/5단계] 세션 초기화...
[2/5단계] 초안 분석...
[3/5단계] DA 검토 (공격 표면 렌즈)...
  → CRITICAL: JWT 시크릿 환경변수 저장 — 순환 정책 없음
  → HIGH: 리프레시 경로에서 토큰 만료 검증 누락
[4/5단계] 반영...
[5/5단계] 종합

Advisory Output
──────────────
CRITICAL (1): 시크릿 관리 — 순환 경로 미정의
HIGH    (1): /auth/refresh 만료 체크 누락
MEDIUM  (0): —
LOW     (2): 로깅 공백, 토큰 엔드포인트 속도 제한 없음

판정: 머지 전 검토 필요. 미해결 CRITICAL 1개.
[단일 AI: Claude] — 독립 검증을 위해 Stage 2 권장.

* HIL 게이트 활성. "확정해주세요"를 입력해 최종화하세요.
```

---

## 작동 방식

### Devil's Advocate(DA)란?

원래 가톨릭 시성 절차에서 유래했습니다. 결정을 내리기 전에 의도적으로 반대 입장을 맡아 논거를 강화하는 역할입니다. gauntlet은 이 방법론을 AI 파이프라인으로 구현했습니다. 각 검토자는 동의하지 않고 비판하도록 설계됩니다. **순차적** — 병렬이 아닙니다: 각 AI는 이전 AI의 비판을 입력으로 받아 비판이 누적되고 초기화되지 않습니다.

### 실행 흐름

**Stage 1, Tier 2 예시** (사용자에게 표시되는 5단계):

```
/gauntlet [주제]
    ↓ [1] Claude — 초안 분석
    ↓ [2] Claude — DA #1 (보수적 렌즈: 최악 시나리오, 모든 가정 의문 제기)
    ↓ [3] Claude — 반영 #1 (DA 결과를 반영해 초안 갱신)
    ↓ [4] Claude — 종합
    ↓ [5] HIL 게이트 — 사용자의 명시적 확인 대기
```

**Stage 1, Tier 1** (7단계): 종합 전에 DA 라운드와 반영이 한 번 더 추가됩니다.  
**Stage 2**: Claude 서브에이전트 대신 외부 provider 체인 사용 (Gemini → OpenAI → Claude API).

> 참고: 사용자에게 표시되는 단계 수는 내부 초기화 단계를 제외한 수입니다. `ref-pipeline.md`에서는 세션 설정·락 관리·정리를 포함한 Step 1~10을 정의합니다. "5단계"는 사용자가 보는 검토 라운드 수입니다.

> **독립성 주의 (Stage 1)**: 모든 검토 단계에서 동일한 Claude 모델을 사용합니다. 순차 비판은 각 단계의 *프레이밍*을 바꿀 뿐, 모델 자체는 동일합니다. 단일 패스 검토에서 놓칠 수 있는 이슈를 드러내는 데 도움이 되지만, 모델 공유 편향을 제거하지는 않습니다. 모델 독립성이 중요한 결정에는 외부 제공자를 사용하는 Stage 2를 사용하세요.

### 실행 모드(Stage) — 설정 여부에 따라 결정

| | Stage 1 | Stage 2 |
|---|---|---|
| 설정 | 불필요 | `/gauntlet --setup` |
| 방식 | Claude 서브에이전트, 복수 렌즈 순차 실행 | 구성 가능한 1~3 provider 체인 (Tier 1: P1→P2→P3, Tier 2: P1→P2) |
| 독립성 | 같은 모델, 다른 관점 (편향 공유 가능성) | 다른 벤더 모델 — Stage 1보다 독립성 높음. 단, 오케스트레이터 레이어(Claude)가 각 프롬프트를 구성하므로 참고용으로 활용하고 최종 판단으로 삼지 마세요. |
| 비용 | 무료 | API 사용량 기반 |
| 출력 레이블 | Advisory Output | Verified Output |

### 검토 깊이(Tier) — 위험도·영향도에 따라 자동 판정

| Tier | 판정 기준 (예시) | 단계 |
|------|--------------|------|
| Tier 1 | 보안 관련, 아키텍처 변경, 광범위한 영향 | 7단계 검토 (초안 → DA 2회 + 반영 2회 → 종합 → HIL) |
| Tier 2 | 단일 기능, 문서 검토 | 5단계 검토 (초안 → DA 1회 + 반영 1회 → 종합 → HIL) |
| Tier 3 | 오탈자, 포맷 수정 | Claude 단독 검토 (DA 생략) |

**Tier 자동 판정 예시:**

| 입력 | 판정 Tier | 이유 |
|------|----------|------|
| `JWT 구현 검토` | Tier 1 | 보안 민감 |
| `이 API 응답 구조 검토` | Tier 2 | 단일 기능 범위 |
| `README 오탈자 수정` | Tier 3 | 포맷 전용 |
| `5개 파일에 걸친 인증 미들웨어 리팩터링` | Tier 1 | 광범위한 영향 |

`--tier 1`로 강제 지정도 가능합니다. Tier 3는 검토 영향이 실질적으로 없는 변경에만 해당합니다.

---

## 역할(--role)

검토 주제에 맞는 비판 렌즈를 주입합니다. 미지정 시 TOPIC을 분석해 자동 선택됩니다.

렌즈는 각 검토 단계마다 주입되는 특화된 비판 관점입니다.

| 키 | 사용 시기 |
|----|---------|
| `default` | 설계·구현 전반 |
| `security` | 인증, 세션, 입력 처리, 취약점 |
| `architecture` | 새 아키텍처, 계층 구조, 인터페이스 설계 |
| `log-debug` | 에러 로그, 장애 원인 추적 |
| `writing` | 가이드, 기술 문서, README |

---

## Stage 2 설정

> **먼저 읽기**: gauntlet은 시스템 전역 API 키가 아닌 전용 `GAUNTLET_*` 변수를 사용합니다. 이유는 두 가지입니다: (1) 기존 Claude Max/Pro 요금제에서 의도치 않은 API 종량제 과금 전환 방지, (2) 다른 도구와 구분해 gauntlet API 비용을 별도 추적 가능. 기존 `ANTHROPIC_API_KEY`를 그대로 `GAUNTLET_CLAUDE_KEY`에 복사하지 마세요 — 별도 결제 계정을 사용하려는 경우에만 해당됩니다.

| 제공자 | 사용할 변수 | 쓰지 말 것 |
|-------|-----------|---------|
| Claude API | `GAUNTLET_CLAUDE_KEY` | `ANTHROPIC_API_KEY` |
| Gemini | `GAUNTLET_GEMINI_KEY` | `GOOGLE_API_KEY` |
| OpenAI | `GAUNTLET_OPENAI_KEY` | `OPENAI_API_KEY` |

### 설정 마법사

`/gauntlet --setup` 실행 후 안내를 따르면 됩니다:

1. **제공자 선택** — `gemini`, `openai`, `claude` 중 복수 선택 가능 (v1.0 지원 제공자)
2. **API 키 저장 방식** — 환경변수 / macOS Keychain / 암호화 파일
3. **집계 모드** — 복수 AI 결과를 합산하는 방식:
   - `consensus`: 2개 이상 AI가 공통으로 발견한 이슈만 표시 (노이즈 감소, 엣지 케이스 누락 가능)
   - `union`: 어느 AI든 발견한 이슈를 모두 포함 (커버리지 높음, 검토 항목 증가)
   - `weighted`: AI 신뢰도 점수로 이슈를 가중 처리 (균형, 기본 권장)
4. **예산 상한** — 세션당 API 비용 상한 설정 (기본 $1.00; **현재는 설정값 저장 기능만 동작 — 실시간 집계·차단은 v1.1 예정. API 제공자 대시보드에서 직접 모니터링하세요.**)
5. **연결 테스트** — 설정한 키로 실제 연결 확인

### 신규 provider 추가

`providers/` 디렉토리에 `{name}.json`(매니페스트)과 `{name}.sh`(API 호출 스크립트)를 추가하고, `governance_rules.json` → `provider_registry.known_providers[]`에 `"<name>"`을 등록하면 됩니다. 파이프라인이 동적으로 dispatch하므로 `SKILL.md`나 `ref-pipeline.md` 수정이 불필요합니다. 전체 5단계 절차는 `ref-provider-guide.md`를 참고하세요.

---

## ChatGPT 연동 플러그인(codex-plugin-cc)과의 차이

OpenAI의 **codex-plugin-cc**는 Claude Code에서 ChatGPT를 도구로 호출하는 MCP 플러그인입니다. Claude가 필요할 때 ChatGPT에 질문하고 결과를 가져오는 단방향 구조입니다.

gauntlet은 목적이 다릅니다.

| | codex-plugin-cc | gauntlet |
|---|---|---|
| 구조 | Claude → ChatGPT 단방향 호출 | 복수 AI 순차 교차 비판 |
| 목적 | ChatGPT 능력 활용 | 구조화된 적대적 검토 — 오케스트레이터(Claude)가 모든 프롬프트를 구성하므로 결과는 참고용으로 활용 |
| AI 역할 | ChatGPT가 Claude의 도구 | 각 AI가 직전 AI의 비판을 이어받아 검토 — 같은 판단 오류를 반복할 가능성을 줄임 |
| 설정 | OpenAI API 키 1개 필요 | Stage 1은 설정 불필요 |

두 스킬은 서로 대체 관계가 아닙니다. gauntlet Stage 2에 OpenAI를 포함시키면 자연스러운 조합이 됩니다.

---

## 세션 관리

```bash
/gauntlet --gc                     # 오래된 세션 정리 (기본: 30일 TTL, 최대 50개)
/gauntlet --resume [session_id]    # 중단된 세션 재개
```

---

## 요구사항

### 지원 환경

| 환경 | 지원 여부 |
|------|---------|
| Claude Code CLI (`claude`) | ✅ |
| VSCode Claude Code 확장 | ✅ |
| JetBrains Claude Code 확장 | ✅ |
| Claude 데스크톱 앱 (claude.ai 앱) | ❌ |

> Claude 데스크톱 앱은 Claude Code가 아닙니다. `/gauntlet` 슬래시 커맨드와 Bash 툴을 지원하지 않아 동작하지 않습니다.

### 의존성

- **Python 3** — 전 단계 필수. 세션 초기화, session.json 관리, result.json 생성 등에 사용합니다. 없으면 Step 1에서 즉시 실패합니다.
  - macOS Monterey 이상: 기본 설치됨
  - Linux: `python3 --version`으로 확인. 없으면 `sudo apt install python3` 등으로 설치
  - Windows: 미검증 환경 (WSL 권장)
- Stage 2만: `curl` + API 키 (Gemini / OpenAI / Claude API 중 하나 이상)

---

## 알려진 제한

- **Stage 1 편향**: Stage 1은 모든 검토 단계에서 동일한 Claude 모델을 사용하며, 비판 렌즈만 바뀝니다. 모든 렌즈가 동일한 학습 편향을 공유합니다. 이것이 Stage 1 결과물이 Advisory 레이블을 달고 있는 근본 이유입니다. 실질적 결과가 따르는 보안·아키텍처 결정에는 Stage 2를 사용하세요.
- **예산 상한**: ⚠️ API 비용 상한은 현재 설정값 저장 기능만 합니다 — 요청을 차단하거나 실제 지출 한도를 집행하지 않습니다. 실시간 집행은 v1.1 예정입니다 (예정 방식: 제공자 토큰 카운트 API를 통한 사전 비용 추산 + 세션당 하드 캡 조기 종료). 그 전까지는 API 제공자 대시보드에서 직접 모니터링하세요. Tier 1 Stage 2는 세션당 최대 3회 제공자 호출이 발생하니, 배치 실행 전 사용량 페이지를 확인하세요.
- **Degraded Mode**: 특정 provider가 실패하면(API quota 초과, 연결 오류) 해당 provider는 SKIPPED 처리되고 부분 결과만 표시됩니다. Tier 1에서 2개 이상 provider가 SKIPPED되면 자동 최종화 불가 (**INSUFFICIENT COVERAGE**) — 재시도하거나 수동 검토로 전환하세요.
- **CDP**: Chrome DevTools Protocol 연동은 지원하지 않으며 향후 계획도 없습니다. (gauntlet은 직접 API 호출과 Claude 서브에이전트를 사용하며, 브라우저 자동화에 의존하지 않습니다.)
- **출력 범위**: 결과물은 참고용입니다. 전문가 검토, 법적·보안 감사를 대체하지 않습니다.

---

## 문제 해결

| 증상 | 원인 | 해결책 |
|------|------|--------|
| `AUTH: GAUNTLET_*_KEY not set` | 환경변수 미설정 | 셸에서 키를 export하세요: `export GAUNTLET_GEMINI_KEY=...` |
| `NETWORK: JSON parse failed` | provider가 예상치 못한 응답 반환 | API 키 유효성 확인. 연결 테스트 실행: `/gauntlet --setup` |
| `RATE_LIMIT: ...` | API quota 초과 | 잠시 후 재시도하거나 다른 provider로 전환 |
| `python3: command not found` | Python 3 미설치 | Python 3 설치 (`brew install python3`, macOS) |
| HIL 게이트에서 세션 멈춤 | 명시적 확인 대기 중 | `확정해주세요` 또는 `이대로 Finalized 처리` 입력 |
| Stage 2 미실행 | Stage 2 설정 안 됨 | `/gauntlet --setup` 먼저 실행 |
| `--resume` 실패 | 세션 ID 없거나 만료됨 | `~/.gauntlet/sessions/`에서 사용 가능한 세션 확인. `--gc`로 정리 후 재시도 |

---

## 번역 로드맵

| 문서 | 현재 | 대상 | 일정 |
|------|------|------|------|
| README.md | ✅ 영문 | — | 완료 |
| README.ko.md | ✅ 한국어 | — | 완료 |
| SKILL.md (프론트매터 + 메시지) | ✅ 영문 | — | 완료 |
| providers/*.sh (주석) | ✅ 영문 | — | 완료 |
| providers/*.json (lens_hint) | ✅ 영문 | — | 완료 |
| gauntlet-roles.json (description/use_when/avoid_when) | ✅ EN+KO 로케일 맵 | — | 완료 |
| ref-pipeline.md | 한국어 | 영문 | v2 (중기) |
| ref-setup.md | 한국어 | 영문 | v2 (중기) |
| ref-ops.md | 한국어 | 영문 | v2 (중기) |
| ref-common.md | 한국어 | 영문 | v2 (중기) |
| ref-provider-guide.md | 한국어 | 영문 | v2 (중기) |

---

## 파일 구조 (참고)

```
~/.claude/skills/gauntlet/
├── SKILL.md                  — 실행 지시서 (라우터)
├── ref-pipeline.md           — Step 1~10 메인 파이프라인
├── ref-setup.md              — --setup 마법사 절차
├── ref-ops.md                — --gc / --resume 절차
├── ref-common.md             — session.json 스키마, atomic write 패턴
├── ref-provider-guide.md     — 신규 제공자 추가 가이드
├── gauntlet-roles.json       — 역할 정의 (단일 소스)
├── governance_rules.json     — DA 커버리지 규칙 (임계값, exit 코드 매핑)
├── config.example.json       — ~/.gauntlet/config.json 템플릿
├── project.example.json      — 프로젝트별 .gauntlet.json 템플릿
└── providers/
    ├── gemini.json           — Gemini 연동 매니페스트
    ├── gemini.sh             — Gemini API 호출 스크립트
    ├── openai.json           — OpenAI 연동 매니페스트
    ├── openai.sh             — OpenAI API 호출 스크립트
    ├── claude.json           — Claude API 연동 매니페스트
    └── claude.sh             — Claude API 호출 스크립트

~/.gauntlet/                  — 런타임 (첫 실행 시 자동 생성)
├── config.json               — /gauntlet --setup으로 생성
├── audit.log                 — 운영 감사 로그
└── sessions/{project_id}/{session_id}/
    ├── session.json          — 세션 메타데이터 (불변)
    ├── session.lock          — PID 잠금 (HIL 수락 후 제거)
    ├── result.json           — 최종 결과
    └── r0-draft.txt, r1-*.txt ...
```

신규 제공자를 추가하려면 `ref-provider-guide.md`를 참고하세요. `SKILL.md`를 수정하지 않고도 확장할 수 있습니다.
