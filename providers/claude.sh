#!/usr/bin/env bash
# gauntlet provider: Anthropic Claude API
# stdin:  review target text (UTF-8)
# stdout: CRITICAL/HIGH/MEDIUM/LOW classified result
# exit:   0=success  1=VALIDATION_FAILED  2=PROVIDER_ERROR  3=CONTRACT_BROKEN
#
# ⚠ GAUNTLET_CLAUDE_KEY only — do NOT use ANTHROPIC_API_KEY (prevents unintended Max plan charges)
set -euo pipefail

CLAUDE_KEY="${GAUNTLET_CLAUDE_KEY:-}"
MODEL="${GAUNTLET_CLAUDE_MODEL:-claude-sonnet-4-6}"

if [ -z "$CLAUDE_KEY" ]; then
  echo "AUTH: GAUNTLET_CLAUDE_KEY not set" >&2
  exit 2
fi

PROMPT=$(cat)

PAYLOAD=$(python3 -c "
import json, sys
prompt = sys.stdin.read()
model = '$MODEL'
print(json.dumps({
    'model': model,
    'max_tokens': 2048,
    'messages': [{'role': 'user', 'content': prompt}]
}))
" <<< "$PROMPT")

_AUTH_FILE=$(mktemp)
echo "x-api-key: ${CLAUDE_KEY}" > "$_AUTH_FILE"
trap "rm -f '$_AUTH_FILE'" EXIT

RESPONSE=$(curl -s -X POST "https://api.anthropic.com/v1/messages" \
  -H @"$_AUTH_FILE" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

python3 -c "
import json, sys

def parse_raw_json(raw):
    try:
        return json.loads(raw)
    except Exception as e:
        sys.stderr.write(f'NETWORK: JSON parse failed — {e}\n')
        sys.exit(2)

def classify_provider_error(d):
    if d.get('type') == 'error':
        err_type = d.get('error', {}).get('type', '')
        if err_type == 'authentication_error':
            return 'AUTH'
        if err_type == 'rate_limit_error':
            return 'RATE_LIMIT'
        return 'NETWORK'
    return None

def extract_response_text(d):
    try:
        return d['content'][0]['text']
    except (KeyError, IndexError, TypeError) as e:
        sys.stderr.write(f'CONTRACT: unexpected Claude API response shape — {e}\n')
        sys.exit(3)

d = parse_raw_json(sys.stdin.read())
err_type = classify_provider_error(d)
if err_type:
    sys.stderr.write(f'{err_type}: Claude API error\n')
    sys.exit(2)
print(extract_response_text(d))
" <<< "$RESPONSE"
