#!/usr/bin/env bash
# gauntlet provider: OpenAI GPT
# stdin:  review target text (UTF-8)
# stdout: CRITICAL/HIGH/MEDIUM/LOW classified result
# exit:   0=success  1=VALIDATION_FAILED  2=PROVIDER_ERROR  3=CONTRACT_BROKEN
set -euo pipefail

OPENAI_KEY="${GAUNTLET_OPENAI_KEY:-}"
MODEL="${GAUNTLET_OPENAI_MODEL:-gpt-4o}"

if [ -z "$OPENAI_KEY" ]; then
  echo "AUTH: GAUNTLET_OPENAI_KEY not set" >&2
  exit 2
fi

PROMPT=$(cat)

PAYLOAD=$(python3 -c "
import json, sys
prompt = sys.stdin.read()
model = '$MODEL'
print(json.dumps({'model': model, 'messages': [{'role': 'user', 'content': prompt}]}))
" <<< "$PROMPT")

_AUTH_FILE=$(mktemp)
echo "Authorization: Bearer ${OPENAI_KEY}" > "$_AUTH_FILE"
trap "rm -f '$_AUTH_FILE'" EXIT

RESPONSE=$(curl -s -X POST "https://api.openai.com/v1/chat/completions" \
  -H @"$_AUTH_FILE" \
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
    err = d.get('error', {})
    etype = err.get('type', '')
    code = err.get('code', '')
    if etype == 'invalid_request_error' and code == 'invalid_api_key':
        return 'AUTH'
    if etype == 'requests' or 'rate_limit' in str(code).lower():
        return 'RATE_LIMIT'
    if err:
        return 'NETWORK'
    return None

def extract_response_text(d):
    try:
        return d['choices'][0]['message']['content']
    except (KeyError, IndexError, TypeError) as e:
        sys.stderr.write(f'CONTRACT: unexpected OpenAI response shape — {e}\n')
        sys.exit(3)

d = parse_raw_json(sys.stdin.read())
err_type = classify_provider_error(d)
if err_type:
    sys.stderr.write(f'{err_type}: OpenAI API error\n')
    sys.exit(2)
print(extract_response_text(d))
" <<< "$RESPONSE"
