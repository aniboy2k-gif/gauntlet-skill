# ref-ops.md — gauntlet 운영 서브커맨드 (--gc, --resume)
#
# 이 파일은 SKILL.md 라우터가 --gc / --resume 감지 시 Read 툴로 로드한다.

<!-- English Overview (for non-Korean contributors)
  File: ref-ops.md
  Role: Handles operational subcommands --gc and --resume.
  --gc: Garbage-collect old sessions under ~/.gauntlet/sessions/ by TTL/max_runs;
    rotate audit.log. Supports --dry-run flag (lists deletions without executing).
    Prompts for confirmation before irreversible deletion.
  --resume: Locate a session by ID, check pipeline_version compatibility,
    atomically re-acquire session.lock (O_CREAT|O_EXCL), then hand off to ref-pipeline.md.
  Lock acquisition uses atomic open to prevent TOCTOU race conditions.
-->

## 실행 컨텍스트
> 이 파일은 운영 서브커맨드 전용입니다.

| 변수명 | 의미 | 설정 위치 |
|--------|------|----------|
| GAUNTLET_SKILL_DIR | 스킬 디렉토리 경로 | SKILL.md 상수 |

---

## --gc 서브커맨드

`/gauntlet --gc` 호출 시 실행한다. `GC_DRY_RUN=true` 이면 삭제/이동 없이 대상 목록만 출력한다.

```bash
python3 << 'PYEOF'
import os, json, shutil, sys, time

dry_run = os.environ.get("GC_DRY_RUN", "false").lower() == "true"
base = os.path.expanduser("~/.gauntlet/sessions")
config_path = os.path.expanduser("~/.gauntlet/config.json")

config = {}
if os.path.exists(config_path):
    try:
        with open(config_path) as f:
            config = json.load(f)
    except (OSError, json.JSONDecodeError):
        pass

max_runs = config.get("gc", {}).get("max_runs", 50)
ttl_days = config.get("gc", {}).get("ttl_days", 30)
now = time.time()

# 체인 참조 보호 목록
protected = set()
if os.path.exists(base):
    for proj in os.listdir(base):
        proj_path = os.path.join(base, proj)
        if not os.path.isdir(proj_path): continue
        for sess in os.listdir(proj_path):
            chain_file = os.path.join(proj_path, sess, "session-chain.json")
            if not os.path.exists(chain_file): continue
            try:
                with open(chain_file) as f:
                    c = json.load(f)
                for ref in ["superseded_by_session_id", "forked_from_session_id"]:
                    if c.get(ref): protected.add(c[ref])
            except: pass

would_delete = []
would_archive = []

if os.path.exists(base):
    for proj in os.listdir(base):
        proj_path = os.path.join(base, proj)
        if not os.path.isdir(proj_path): continue
        sessions = []
        for sess in os.listdir(proj_path):
            sess_path = os.path.join(proj_path, sess)
            sess_file = os.path.join(sess_path, "session.json")
            if not os.path.exists(sess_file): continue
            sessions.append((os.path.getmtime(sess_file), sess, sess_path))
        sessions.sort(reverse=True)

        for i, (mtime, sess_id, sess_path) in enumerate(sessions):
            if sess_id in protected: continue
            age_days = (now - mtime) / 86400
            if age_days > ttl_days:
                would_delete.append((sess_id, f"{age_days:.0f}d old"))
                if not dry_run:
                    shutil.rmtree(sess_path, ignore_errors=True)
            elif i >= max_runs:
                would_archive.append((sess_id, f"rank {i+1}"))
                if not dry_run:
                    archive_dir = os.path.join(base, proj, "runs_archive")
                    os.makedirs(archive_dir, exist_ok=True)
                    shutil.move(sess_path, os.path.join(archive_dir, sess_id))

if dry_run:
    print(f"🔍 DRY-RUN: 실제 삭제/이동 없음. 아래는 실행 시 처리될 대상입니다.")
    print(f"\n삭제 대상 ({len(would_delete)}개, TTL {ttl_days}일 초과):")
    for s, reason in would_delete:
        print(f"  - {s}  ({reason})")
    print(f"\n아카이브 대상 ({len(would_archive)}개, max_runs {max_runs} 초과):")
    for s, reason in would_archive:
        print(f"  - {s}  ({reason})")
    print(f"\n실제 GC 실행: /gauntlet --gc")
    sys.exit(0)

# 실제 삭제 모드: 확인 프롬프트
if would_delete or would_archive:
    print(f"⚠ 삭제: {len(would_delete)}개, 아카이브: {len(would_archive)}개")
    print("계속하려면 'yes'를 입력하세요 (취소: 그 외 입력):")
    try:
        ans = input().strip().lower()
    except (EOFError, KeyboardInterrupt):
        ans = ""
    if ans != "yes":
        print("GC 취소됨.")
        sys.exit(0)

# audit.log 로테이션 (1MB 초과 시 .1 백업 후 새 파일 생성, 최대 3개 보관)
audit_log = os.path.expanduser("~/.gauntlet/audit.log")
AUDIT_LOG_MAX_BYTES = 1 * 1024 * 1024  # 1MB
AUDIT_LOG_KEEP = 3
if os.path.exists(audit_log) and os.path.getsize(audit_log) > AUDIT_LOG_MAX_BYTES:
    for i in range(AUDIT_LOG_KEEP - 1, 0, -1):
        src = f"{audit_log}.{i}"
        dst = f"{audit_log}.{i+1}"
        if os.path.exists(src):
            if os.path.exists(dst):
                os.remove(dst)
            os.rename(src, dst)
    os.rename(audit_log, f"{audit_log}.1")
    print(f"  audit.log 로테이션 완료 (1MB 초과)")

print(f"✅ GC 완료: {len(would_delete)}개 삭제 (TTL 초과), {len(would_archive)}개 아카이브 (count 초과)")
PYEOF
```

---

## --resume 서브커맨드

`/gauntlet --resume [session_id]` 호출 시:

```bash
RESUME_ID="$RESUME_SESSION_ID"

# project_id + 세션 경로 탐색
SESS_INFO=$(python3 -c "
import os, json
base = os.path.expanduser('~/.gauntlet/sessions')
for proj in (os.listdir(base) if os.path.exists(base) else []):
    proj_path = os.path.join(base, proj)
    if not os.path.isdir(proj_path): continue
    for sess in os.listdir(proj_path):
        sess_file = os.path.join(proj_path, sess, 'session.json')
        if not os.path.exists(sess_file): continue
        try:
            with open(sess_file) as f:
                d = json.load(f)
            if d.get('session_id') == '$RESUME_ID':
                step_key = d.get('current_step_key', '')
                step_num = d.get('current_step', 0)
                pv = d.get('pipeline_version', '1.0')
                print(f\"{d['project_id']} {os.path.join(proj_path, sess)} {step_num} {d['status']} {step_key} {pv}\")
                raise SystemExit(0)
        except SystemExit: raise
        except: pass
print('NOT_FOUND')
")

if [ "$SESS_INFO" = "NOT_FOUND" ]; then
  echo "⚠ 세션 '$RESUME_ID'를 찾을 수 없습니다."
  exit 1
fi

PROJECT_ID=$(echo "$SESS_INFO" | awk '{print $1}')
DA_SESSION_DIR=$(echo "$SESS_INFO" | awk '{print $2}')
CURRENT_STEP=$(echo "$SESS_INFO" | awk '{print $3}')
SESS_STATUS=$(echo "$SESS_INFO" | awk '{print $4}')
CURRENT_STEP_KEY=$(echo "$SESS_INFO" | awk '{print $5}')
SESS_PIPELINE_VER=$(echo "$SESS_INFO" | awk '{print $6}')
CURRENT_PIPELINE_VER="1.0"
```

**pipeline_version 호환성 검사 (semver 기반)**:

```bash
python3 << PYEOF
sess_ver = "$SESS_PIPELINE_VER"
curr_ver = "$CURRENT_PIPELINE_VER"

def parse_semver(v):
    parts = v.split('.')
    return tuple(int(x) if x.isdigit() else 0 for x in parts[:2])

sv_major, sv_minor = parse_semver(sess_ver)
cv_major, cv_minor = parse_semver(curr_ver)

if sv_major != cv_major:
    print(f"INCOMPATIBLE: 세션 pipeline v{sess_ver} ↔ 현재 v{curr_ver}")
    print(f"MAJOR 버전 불일치: step_key 의미가 변경되었을 수 있습니다.")
    print(f"안전한 재시작을 위해 새 세션을 시작하거나 /gauntlet --resume --force {RESUME_SESSION_ID}로 강제 진행하세요.")
    exit(1)
elif sv_minor < cv_minor:
    print(f"⚠ MINOR 버전 차이: 세션 v{sess_ver} → 현재 v{curr_ver}")
    print(f"신규 step_key가 추가되었을 수 있습니다. 진행 가능하지만 일부 단계가 다를 수 있습니다.")
    print("계속하려면 'Y' 입력:")
else:
    print("OK")
PYEOF
```

```bash
# session.lock 원자적 재획득 (O_CREAT|O_EXCL — TOCTOU 방지)
LOCK_RESULT=$(python3 << 'PYEOF'
import json, os, datetime, sys

session_dir = os.environ.get("DA_SESSION_DIR", "")
resume_id = os.environ.get("RESUME_ID", "")
lock_path = os.path.join(session_dir, "session.lock")

# 1단계: 기존 lock이 있으면 PID 확인 (stale lock 제거 판단용)
if os.path.exists(lock_path):
    try:
        with open(lock_path) as f:
            d = json.load(f)
        old_pid = d.get("pid", 0)
        try:
            os.kill(old_pid, 0)
            # 프로세스 살아있음 → 실제로 사용 중
            print(f"LOCKED:{old_pid}")
            sys.exit(0)
        except (ProcessLookupError, OSError):
            # Stale lock — 제거 후 계속
            os.remove(lock_path)
    except (OSError, json.JSONDecodeError):
        try: os.remove(lock_path)
        except OSError: pass

# 2단계: O_CREAT|O_EXCL 원자적 생성 (경쟁 조건 차단)
try:
    fd = os.open(lock_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    lock = {
        "pid": os.getpid(),
        "started_at": datetime.datetime.utcnow().isoformat() + "Z",
        "session_id": resume_id,
    }
    os.write(fd, json.dumps(lock).encode())
    os.close(fd)
    print("OK")
except FileExistsError:
    print("LOCKED:unknown")
PYEOF
)

if echo "$LOCK_RESULT" | grep -q "^LOCKED:"; then
  LOCK_PID=$(echo "$LOCK_RESULT" | cut -d: -f2)
  echo "⚠ 세션이 이미 실행 중입니다 (PID: $LOCK_PID)"
  exit 1
fi

echo "세션 '$RESUME_ID' (step_key: $CURRENT_STEP_KEY, status: $SESS_STATUS) 재시작"
```

session.json에서 `current_step_key`를 읽어 해당 단계부터 ref-pipeline.md 파이프라인을 재실행한다.
- **step_key가 정본**: resume 위치 결정은 `current_step_key` 기준
- `current_step`(숫자)은 폴백 참고용 (step_key 미존재 구버전 호환)
