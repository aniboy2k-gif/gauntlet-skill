#!/usr/bin/env bash
# gauntlet provider: Google Gemini
# stdin:  review target text (UTF-8)
# stdout: CRITICAL/HIGH/MEDIUM/LOW classified result
# exit:   0=success  1=VALIDATION_FAILED  2=PROVIDER_ERROR  3=CONTRACT_BROKEN
set -euo pipefail

GEMINI_KEY="${GAUNTLET_GEMINI_KEY:-}"
MODEL="${GAUNTLET_GEMINI_MODEL:-gemini-2.0-flash}"

if [ -z "$GEMINI_KEY" ]; then
  echo "AUTH: GAUNTLET_GEMINI_KEY not set" >&2
  exit 2
fi

PROMPT=$(cat)

PAYLOAD=$(python3 -c "
import json, sys
prompt = sys.stdin.read()
print(json.dumps({'contents': [{'parts': [{'text': prompt}]}]}))
" <<< "$PROMPT")

_AUTH_FILE=$(mktemp)
echo "x-goog-api-key: ${GEMINI_KEY}" > "$_AUTH_FILE"
trap "rm -f '$_AUTH_FILE'" EXIT

RESPONSE=$(curl -s -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent" \
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
    code = err.get('code', 0)
    msg = err.get('message', '')
    if code in (401, 403) or 'API_KEY' in msg.upper():
        return 'AUTH'
    if code == 429 or 'RATE' in msg.upper() or 'QUOTA' in msg.upper():
        return 'RATE_LIMIT'
    if err:
        return 'NETWORK'
    return None

def extract_response_text(d):
    try:
        return d['candidates'][0]['content']['parts'][0]['text']
    except (KeyError, IndexError, TypeError) as e:
        sys.stderr.write(f'CONTRACT: unexpected Gemini response shape — {e}\n')
        sys.exit(3)

d = parse_raw_json(sys.stdin.read())
err_type = classify_provider_error(d)
if err_type:
    sys.stderr.write(f'{err_type}: Gemini API error\n')
    sys.exit(2)
print(extract_response_text(d))
" <<< "$RESPONSE"
