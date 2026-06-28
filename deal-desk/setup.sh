#!/bin/bash
# Deal Desk Setup Script — Superior Real Estate
# Run this ONCE from your Mac to create Tally forms and configure Make.com
# Usage: bash livrables/deal-desk/setup.sh
#
# Reads credentials from .env at the workspace root (never committed to git)

set -e

# Load .env from workspace root
WORKSPACE_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [ -f "$WORKSPACE_ROOT/.env" ]; then
  export $(grep -v '^#' "$WORKSPACE_ROOT/.env" | grep '=' | xargs)
fi

# Verify required vars are set
if [ -z "$TALLY_API_KEY" ] || [ -z "$MAKE_API_KEY" ] || [ -z "$GITHUB_TOKEN" ]; then
  echo "Error: missing credentials in .env — need TALLY_API_KEY, MAKE_API_KEY, GITHUB_TOKEN"
  exit 1
fi

TALLY_KEY="$TALLY_API_KEY"
MAKE_TOKEN="$MAKE_API_KEY"
MAKE_API="https://eu2.make.com/api/v2"
MAKE_SCENARIO_DEALS=9453116
MAKE_SCENARIO_INVESTORS=9453117
MAKE_HOOK_DEALS=4227033
MAKE_HOOK_INVESTORS=4227035
NOTION_DEALS_DB="493ed762-a956-4b66-8705-a765e19fec45"
NOTION_INVESTORS_DB="b72bbc1d-ec16-4f92-accb-815c692b5a59"

GREEN='\033[0;32m'
GOLD='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo -e "${GOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GOLD}  SUPERIOR REAL ESTATE — Deal Desk Setup${NC}"
echo -e "${GOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ── STEP 1: Create Tally Forms ─────────────────────────────────────
echo -e "${GOLD}[1/3] Creating Tally forms...${NC}"

DEALS_FORM=$(python3 - <<'PYEOF'
import json, uuid

def u():
    return str(uuid.uuid4())

def form_title(text):
    return [{"uuid":u(),"type":"FORM_TITLE","groupUuid":u(),"groupType":"TEXT","payload":{"button":{"label":"שלח"},"title":text,"safeHTMLSchema":[[text]]}}]

def q(label):
    return [{"uuid":u(),"type":"TITLE","groupUuid":u(),"groupType":"QUESTION","payload":{"safeHTMLSchema":[[label]]}}]

def text_input(placeholder="", required=False):
    return [{"uuid":u(),"type":"INPUT_TEXT","groupUuid":u(),"groupType":"INPUT_TEXT","payload":{"isRequired":required,"placeholder":placeholder}}]

def email_input():
    return [{"uuid":u(),"type":"INPUT_EMAIL","groupUuid":u(),"groupType":"INPUT_EMAIL","payload":{"isRequired":True,"placeholder":""}}]

def textarea_input(placeholder="", required=False):
    return [{"uuid":u(),"type":"TEXTAREA","groupUuid":u(),"groupType":"TEXTAREA","payload":{"isRequired":required,"placeholder":placeholder}}]

def choices(opts, required=True):
    gu = u()
    return [{"uuid":u(),"type":"MULTIPLE_CHOICE_OPTION","groupUuid":gu,"groupType":"MULTIPLE_CHOICE","payload":{"index":i,"isRequired":required,"isFirst":i==0,"isLast":i==len(opts)-1,"text":o}} for i,o in enumerate(opts)]

blocks = []
blocks += form_title("יש לי נכס / עסקה — Deal Desk")
blocks += q("שם (אופציונלי)") + text_input("שם מלא")
blocks += q("אימייל ליצירת קשר") + email_input()
blocks += q("WhatsApp (אופציונלי)") + text_input("+972...")
blocks += q("סוג הנכס") + choices(["קרקע","מסחרי מניב","מגורים","מלונאות","אחר"])
blocks += q("שוק") + choices(["ישראל","קפריסין","פריז","ארה\"ב","אחר"])
blocks += q("מחיר מבוקש (טווח)") + text_input("לדוג': $2M–$5M", required=True)
blocks += q("שלב הפרויקט") + choices(["קרקע גולמית","היתרים","בנייה","מוכן","מניב"])
blocks += q("תיאור קצר (3-5 שורות)") + textarea_input("תאר את הנכס...", required=True)
blocks += q("האם יש NDA?") + choices(["כן","לא","פתוח לדיון"])
blocks += q("טיימליין לסגירה") + text_input("לדוג': 3 חודשים")

payload = {"name":"Deal Desk — יש לי נכס / עסקה","status":"PUBLISHED","blocks":blocks,"settings":{"language":"he","styles":{"theme":"CUSTOM","color":{"background":"#060608","text":"#F0EBE0","accent":"#C9A96E","buttonBackground":"#C9A96E","buttonText":"#060608"},"font":{"provider":"Google","family":"Jost"}}}}
print(json.dumps(payload))
PYEOF
)

DEALS_RESPONSE=$(curl -s -X POST "https://api.tally.so/forms" \
  -H "Authorization: Bearer $TALLY_KEY" \
  -H "Content-Type: application/json" \
  -d "$DEALS_FORM")

DEALS_ID=$(echo "$DEALS_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id','ERROR'))" 2>/dev/null)
DEALS_URL="https://tally.so/r/$DEALS_ID"

if [ "$DEALS_ID" = "ERROR" ] || [ -z "$DEALS_ID" ]; then
  echo -e "${RED}  ✗ Deals form creation failed${NC}"
  echo "  Response: $DEALS_RESPONSE"
else
  echo -e "${GREEN}  ✓ Deals form created: $DEALS_URL${NC}"
fi

INVESTORS_FORM=$(python3 - <<'PYEOF'
import json, uuid

def u():
    return str(uuid.uuid4())

def form_title(text):
    return [{"uuid":u(),"type":"FORM_TITLE","groupUuid":u(),"groupType":"TEXT","payload":{"button":{"label":"שלח"},"title":text,"safeHTMLSchema":[[text]]}}]

def q(label):
    return [{"uuid":u(),"type":"TITLE","groupUuid":u(),"groupType":"QUESTION","payload":{"safeHTMLSchema":[[label]]}}]

def text_input(placeholder="", required=False):
    return [{"uuid":u(),"type":"INPUT_TEXT","groupUuid":u(),"groupType":"INPUT_TEXT","payload":{"isRequired":required,"placeholder":placeholder}}]

def email_input():
    return [{"uuid":u(),"type":"INPUT_EMAIL","groupUuid":u(),"groupType":"INPUT_EMAIL","payload":{"isRequired":True,"placeholder":""}}]

def textarea_input(placeholder="", required=False):
    return [{"uuid":u(),"type":"TEXTAREA","groupUuid":u(),"groupType":"TEXTAREA","payload":{"isRequired":required,"placeholder":placeholder}}]

def number_input(placeholder="", required=True):
    return [{"uuid":u(),"type":"INPUT_NUMBER","groupUuid":u(),"groupType":"INPUT_NUMBER","payload":{"isRequired":required,"placeholder":placeholder}}]

def choices(opts, required=True):
    gu = u()
    return [{"uuid":u(),"type":"MULTIPLE_CHOICE_OPTION","groupUuid":gu,"groupType":"MULTIPLE_CHOICE","payload":{"index":i,"isRequired":required,"isFirst":i==0,"isLast":i==len(opts)-1,"text":o}} for i,o in enumerate(opts)]

blocks = []
blocks += form_title("אני מחפש להשקיע — Deal Desk")
blocks += q("שם (אופציונלי)") + text_input("שם מלא")
blocks += q("אימייל ליצירת קשר") + email_input()
blocks += q("WhatsApp (אופציונלי)") + text_input("+972...")
blocks += q("סוג נכס מבוקש (ניתן לבחור מספר)") + choices(["קרקע","מסחרי מניב","מגורים","מלונאות"])
blocks += q("שוקי יעד (ניתן לבחור מספר)") + choices(["ישראל","קפריסין","פריז","ארה\"ב"])
blocks += q("תקציב מינימום ($)") + number_input("100,000")
blocks += q("תקציב מקסימום ($)") + number_input("10,000,000")
blocks += q("תשואה מצופה (yield / IRR)") + text_input("לדוג': 8% שנתי")
blocks += q("אופק השקעה") + choices(["קצר (1-2 שנים)","בינוני (3-5 שנים)","ארוך (5+ שנים)"])
blocks += q("מינוף") + choices(["כן","לא","תלוי בעסקה"])
blocks += q("הערות נוספות") + textarea_input("כל מידע נוסף...")

payload = {"name":"Deal Desk — אני מחפש להשקיע","status":"PUBLISHED","blocks":blocks,"settings":{"language":"he","styles":{"theme":"CUSTOM","color":{"background":"#060608","text":"#F0EBE0","accent":"#C9A96E","buttonBackground":"#C9A96E","buttonText":"#060608"},"font":{"provider":"Google","family":"Jost"}}}}
print(json.dumps(payload))
PYEOF
)

INVESTORS_RESPONSE=$(curl -s -X POST "https://api.tally.so/forms" \
  -H "Authorization: Bearer $TALLY_KEY" \
  -H "Content-Type: application/json" \
  -d "$INVESTORS_FORM")

INV_ID=$(echo "$INVESTORS_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id','ERROR'))" 2>/dev/null)
INV_URL="https://tally.so/r/$INV_ID"

if [ "$INV_ID" = "ERROR" ] || [ -z "$INV_ID" ]; then
  echo -e "${RED}  ✗ Investors form creation failed${NC}"
  echo "  Response: $INVESTORS_RESPONSE"
else
  echo -e "${GREEN}  ✓ Investors form created: $INV_URL${NC}"
fi

# ── STEP 2: Update Make.com Blueprints ───────────────────────────
echo ""
echo -e "${GOLD}[2/3] Updating Make.com scenarios...${NC}"

update_make_scenario() {
  local SCENARIO_ID=$1
  local HOOK_ID=$2
  local FORM_URL=$3
  local LABEL=$4
  local EMAIL_SUBJECT=$5
  local EMAIL_BODY=$6

  local BLUEPRINT=$(python3 - "$SCENARIO_ID" "$HOOK_ID" "$EMAIL_SUBJECT" "$EMAIL_BODY" <<'PYEOF'
import json, sys
scenario_id, hook_id, subject, body = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
bp = {
    "name": f"Deal Desk — {subject}",
    "flow": [
        {"id":1,"module":"gateway:CustomWebHook","version":1,"parameters":{"hook":int(hook_id),"maxResults":1},"mapper":{},"metadata":{"designer":{"x":-250,"y":0}}},
        {"id":2,"module":"google-email:ActionSendEmail","version":1,"parameters":{"__IMTCONN__":0},"mapper":{"to":"elie.priou7@gmail.com","subject":subject,"content":body,"contentType":"html"},"metadata":{"designer":{"x":50,"y":0}}}
    ],
    "metadata":{"instant":True,"version":1}
}
print(json.dumps(bp))
PYEOF
  )

  local BODY=$(python3 -c "
import json
bp = '$BLUEPRINT'
body = json.dumps({'blueprint': bp, 'scheduling': json.dumps({'type':'indefinitely','interval':900})})
print(body)
" 2>/dev/null) || true

  # Use a temp file to avoid escaping issues
  python3 - "$SCENARIO_ID" "$HOOK_ID" "$EMAIL_SUBJECT" "$EMAIL_BODY" > /tmp/make_body.json <<'PYEOF'
import json, sys
scenario_id, hook_id, subject, body_text = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
bp = {
    "name": f"Deal Desk — {subject}",
    "flow": [
        {"id":1,"module":"gateway:CustomWebHook","version":1,"parameters":{"hook":int(hook_id),"maxResults":1},"mapper":{},"metadata":{"designer":{"x":-250,"y":0}}},
        {"id":2,"module":"google-email:ActionSendEmail","version":1,"parameters":{"__IMTCONN__":0},"mapper":{"to":"elie.priou7@gmail.com","subject":subject,"content":body_text,"contentType":"html"},"metadata":{"designer":{"x":50,"y":0}}}
    ],
    "metadata":{"instant":True,"version":1}
}
payload = {"blueprint": json.dumps(bp), "scheduling": json.dumps({"type":"indefinitely","interval":900})}
print(json.dumps(payload))
PYEOF

  local RESULT=$(curl -s -X PATCH "$MAKE_API/scenarios/$SCENARIO_ID" \
    -H "Authorization: Token $MAKE_TOKEN" \
    -H "Content-Type: application/json" \
    -d @/tmp/make_body.json)

  if echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if 'scenario' in d else 1)" 2>/dev/null; then
    echo -e "${GREEN}  ✓ Scenario $SCENARIO_ID updated ($LABEL)${NC}"
  else
    echo -e "${RED}  ✗ Scenario $SCENARIO_ID failed${NC}"
    echo "  $RESULT" | head -c 200
  fi
}

DEAL_SUBJECT="🏢 Deal Desk — עסקה חדשה: {{1.asset_type}} / {{1.market}}"
DEAL_BODY="<div style='font-family:sans-serif;background:#060608;color:#F0EBE0;padding:32px;max-width:600px'><h2 style='color:#C9A96E;font-family:Georgia,serif;font-weight:400;font-style:italic'>עסקה חדשה נכנסה</h2><table style='width:100%;border-collapse:collapse;margin:24px 0'><tr style='border-bottom:1px solid #1A1A20'><td style='padding:12px 0;color:#5C574F;font-size:11px;letter-spacing:.2em;text-transform:uppercase'>סוג</td><td style='padding:12px 0;color:#F0EBE0'>{{1.asset_type}}</td></tr><tr style='border-bottom:1px solid #1A1A20'><td style='padding:12px 0;color:#5C574F;font-size:11px;letter-spacing:.2em;text-transform:uppercase'>שוק</td><td style='padding:12px 0;color:#F0EBE0'>{{1.market}}</td></tr><tr style='border-bottom:1px solid #1A1A20'><td style='padding:12px 0;color:#5C574F;font-size:11px;letter-spacing:.2em;text-transform:uppercase'>שלב</td><td style='padding:12px 0;color:#F0EBE0'>{{1.stage}}</td></tr><tr style='border-bottom:1px solid #1A1A20'><td style='padding:12px 0;color:#5C574F;font-size:11px;letter-spacing:.2em;text-transform:uppercase'>מחיר</td><td style='padding:12px 0;color:#C9A96E'>{{1.price_range}}</td></tr><tr style='border-bottom:1px solid #1A1A20'><td style='padding:12px 0;color:#5C574F;font-size:11px;letter-spacing:.2em;text-transform:uppercase'>NDA</td><td style='padding:12px 0;color:#F0EBE0'>{{1.nda}}</td></tr><tr style='border-bottom:1px solid #1A1A20'><td style='padding:12px 0;color:#5C574F;font-size:11px;letter-spacing:.2em;text-transform:uppercase'>קשר</td><td style='padding:12px 0;color:#C9A96E'>{{1.email}} | {{1.whatsapp}}</td></tr></table><p style='color:#9C9488;font-size:13px;line-height:1.8'>{{1.description}}</p><a href='https://www.notion.so/$NOTION_DEALS_DB' style='display:inline-block;margin-top:24px;padding:12px 24px;border:1px solid rgba(201,169,110,.5);color:#C9A96E;text-decoration:none;font-size:10px;letter-spacing:.2em;text-transform:uppercase'>פתח ב-Notion →</a><hr style='border:none;border-top:1px solid #1A1A20;margin:32px 0'><p style='color:#5C574F;font-size:10px'>Superior Real Estate · Deal Desk · Beyond the Deal.</p></div>"

INV_SUBJECT="👤 Deal Desk — משקיע חדש: {{1.budget_min}}–{{1.budget_max}} / {{1.markets}}"
INV_BODY="<div style='font-family:sans-serif;background:#060608;color:#F0EBE0;padding:32px;max-width:600px'><h2 style='color:#6FC47A;font-family:Georgia,serif;font-weight:400;font-style:italic'>משקיע חדש נרשם</h2><table style='width:100%;border-collapse:collapse;margin:24px 0'><tr style='border-bottom:1px solid #1A1A20'><td style='padding:12px 0;color:#5C574F;font-size:11px;letter-spacing:.2em;text-transform:uppercase'>שם</td><td style='padding:12px 0;color:#F0EBE0'>{{1.name}}</td></tr><tr style='border-bottom:1px solid #1A1A20'><td style='padding:12px 0;color:#5C574F;font-size:11px;letter-spacing:.2em;text-transform:uppercase'>שווקים</td><td style='padding:12px 0;color:#F0EBE0'>{{1.markets}}</td></tr><tr style='border-bottom:1px solid #1A1A20'><td style='padding:12px 0;color:#5C574F;font-size:11px;letter-spacing:.2em;text-transform:uppercase'>תקציב</td><td style='padding:12px 0;color:#6FC47A'>{{1.budget_min}} – {{1.budget_max}}</td></tr><tr style='border-bottom:1px solid #1A1A20'><td style='padding:12px 0;color:#5C574F;font-size:11px;letter-spacing:.2em;text-transform:uppercase'>נכסים</td><td style='padding:12px 0;color:#F0EBE0'>{{1.asset_types}}</td></tr><tr style='border-bottom:1px solid #1A1A20'><td style='padding:12px 0;color:#5C574F;font-size:11px;letter-spacing:.2em;text-transform:uppercase'>תשואה</td><td style='padding:12px 0;color:#F0EBE0'>{{1.expected_yield}}</td></tr><tr style='border-bottom:1px solid #1A1A20'><td style='padding:12px 0;color:#5C574F;font-size:11px;letter-spacing:.2em;text-transform:uppercase'>קשר</td><td style='padding:12px 0;color:#6FC47A'>{{1.email}} | {{1.whatsapp}}</td></tr></table><a href='https://www.notion.so/$NOTION_INVESTORS_DB' style='display:inline-block;margin-top:24px;padding:12px 24px;border:1px solid rgba(111,196,122,.4);color:#6FC47A;text-decoration:none;font-size:10px;letter-spacing:.2em;text-transform:uppercase'>פתח ב-Notion →</a><hr style='border:none;border-top:1px solid #1A1A20;margin:32px 0'><p style='color:#5C574F;font-size:10px'>Superior Real Estate · Deal Desk · Beyond the Deal.</p></div>"

# Update scenario for deals
python3 - "$MAKE_SCENARIO_DEALS" "$MAKE_HOOK_DEALS" > /tmp/make_body.json <<PYEOF2
import json, sys
sid, hid = int(sys.argv[1]), int(sys.argv[2])
bp = {"name":"Deal Desk — Deals → Gmail","flow":[{"id":1,"module":"gateway:CustomWebHook","version":1,"parameters":{"hook":hid,"maxResults":1},"mapper":{},"metadata":{"designer":{"x":-250,"y":0}}},{"id":2,"module":"google-email:ActionSendEmail","version":1,"parameters":{"__IMTCONN__":0},"mapper":{"to":"elie.priou7@gmail.com","subject":"🏢 Deal Desk — עסקה חדשה: {{1.asset_type}} / {{1.market}}","content":"<div style='font-family:sans-serif;background:#060608;color:#F0EBE0;padding:32px;max-width:600px'><h2 style='color:#C9A96E'>עסקה חדשה</h2><p><b>סוג:</b> {{1.asset_type}}</p><p><b>שוק:</b> {{1.market}}</p><p><b>מחיר:</b> {{1.price_range}}</p><p><b>קשר:</b> {{1.email}}</p><p>{{1.description}}</p><a href='https://www.notion.so/493ed762a9564b668705a765e19fec45'>פתח ב-Notion</a></div>","contentType":"html"},"metadata":{"designer":{"x":50,"y":0}}}],"metadata":{"instant":True,"version":1}}
print(json.dumps({"blueprint":json.dumps(bp),"scheduling":json.dumps({"type":"indefinitely","interval":900})}))
PYEOF2

RESULT1=$(curl -s -X PATCH "$MAKE_API/scenarios/$MAKE_SCENARIO_DEALS" \
  -H "Authorization: Token $MAKE_TOKEN" \
  -H "Content-Type: application/json" \
  -d @/tmp/make_body.json)

if echo "$RESULT1" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if 'scenario' in d else 1)" 2>/dev/null; then
  echo -e "${GREEN}  ✓ Deals scenario ($MAKE_SCENARIO_DEALS) updated${NC}"
else
  echo -e "${RED}  ✗ Deals scenario failed — may need manual config in Make.com UI${NC}"
fi

# Update scenario for investors
python3 - "$MAKE_SCENARIO_INVESTORS" "$MAKE_HOOK_INVESTORS" > /tmp/make_body.json <<PYEOF3
import json, sys
sid, hid = int(sys.argv[1]), int(sys.argv[2])
bp = {"name":"Deal Desk — Investors → Gmail","flow":[{"id":1,"module":"gateway:CustomWebHook","version":1,"parameters":{"hook":hid,"maxResults":1},"mapper":{},"metadata":{"designer":{"x":-250,"y":0}}},{"id":2,"module":"google-email:ActionSendEmail","version":1,"parameters":{"__IMTCONN__":0},"mapper":{"to":"elie.priou7@gmail.com","subject":"👤 Deal Desk — משקיע חדש: {{1.budget_min}}–{{1.budget_max}}","content":"<div style='font-family:sans-serif;background:#060608;color:#F0EBE0;padding:32px;max-width:600px'><h2 style='color:#6FC47A'>משקיע חדש</h2><p><b>שם:</b> {{1.name}}</p><p><b>שווקים:</b> {{1.markets}}</p><p><b>תקציב:</b> {{1.budget_min}}–{{1.budget_max}}</p><p><b>קשר:</b> {{1.email}}</p><a href='https://www.notion.so/b72bbc1dec164f92accb815c692b5a59'>פתח ב-Notion</a></div>","contentType":"html"},"metadata":{"designer":{"x":50,"y":0}}}],"metadata":{"instant":True,"version":1}}
print(json.dumps({"blueprint":json.dumps(bp),"scheduling":json.dumps({"type":"indefinitely","interval":900})}))
PYEOF3

RESULT2=$(curl -s -X PATCH "$MAKE_API/scenarios/$MAKE_SCENARIO_INVESTORS" \
  -H "Authorization: Token $MAKE_TOKEN" \
  -H "Content-Type: application/json" \
  -d @/tmp/make_body.json)

if echo "$RESULT2" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if 'scenario' in d else 1)" 2>/dev/null; then
  echo -e "${GREEN}  ✓ Investors scenario ($MAKE_SCENARIO_INVESTORS) updated${NC}"
else
  echo -e "${RED}  ✗ Investors scenario failed — may need manual config in Make.com UI${NC}"
fi

# ── STEP 3: Connect Tally webhooks → Make.com ────────────────────
echo ""
echo -e "${GOLD}[3/5] Connecting Tally webhooks to Make.com...${NC}"

MAKE_HOOK_DEALS_URL="https://hook.eu2.make.com/mq14tenn2mbzz9unwkbro1y7ofxd7nuy"
MAKE_HOOK_INV_URL="https://hook.eu2.make.com/r6qgp30x7n24lyjcjihouybs21of9e8y"

if [ -n "$DEALS_ID" ] && [ "$DEALS_ID" != "ERROR" ]; then
  WH1=$(curl -s -X POST "https://api.tally.so/webhooks" \
    -H "Authorization: Bearer $TALLY_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"formId\":\"$DEALS_ID\",\"url\":\"$MAKE_HOOK_DEALS_URL\",\"subscriptionType\":\"FORM_RESPONSE\"}")
  if echo "$WH1" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if d.get('id') else 1)" 2>/dev/null; then
    echo -e "${GREEN}  ✓ Deals form webhook → Make.com connected${NC}"
  else
    echo -e "${RED}  ✗ Deals webhook failed (configure manually in Tally → Integrations)${NC}"
  fi
fi

if [ -n "$INV_ID" ] && [ "$INV_ID" != "ERROR" ]; then
  WH2=$(curl -s -X POST "https://api.tally.so/webhooks" \
    -H "Authorization: Bearer $TALLY_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"formId\":\"$INV_ID\",\"url\":\"$MAKE_HOOK_INV_URL\",\"subscriptionType\":\"FORM_RESPONSE\"}")
  if echo "$WH2" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if d.get('id') else 1)" 2>/dev/null; then
    echo -e "${GREEN}  ✓ Investors form webhook → Make.com connected${NC}"
  else
    echo -e "${RED}  ✗ Investors webhook failed (configure manually in Tally → Integrations)${NC}"
  fi
fi

# ── STEP 4: Activate Make.com scenarios ──────────────────────────
echo ""
echo -e "${GOLD}[4/5] Activating Make.com scenarios...${NC}"

for SID in $MAKE_SCENARIO_DEALS $MAKE_SCENARIO_INVESTORS; do
  ACT=$(curl -s -X POST "$MAKE_API/scenarios/$SID/start" \
    -H "Authorization: Token $MAKE_TOKEN")
  if echo "$ACT" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if d.get('scenario',{}).get('isPaused') == False else 1)" 2>/dev/null; then
    echo -e "${GREEN}  ✓ Scenario $SID activated${NC}"
  else
    echo -e "${RED}  ✗ Scenario $SID — activate manually in Make.com UI${NC}"
  fi
done

# ── STEP 5: Update landing page & publish to GitHub ──────────────
echo ""
echo -e "${GOLD}[5/5] Updating landing page with form URLs...${NC}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LANDING="$SCRIPT_DIR/index.html"
GITHUB_REPO="superiorealestate-byte/superior-real-estate-site"

if [ -f "$LANDING" ]; then
  # Replace mailto placeholders with real Tally URLs if available
  if [ -n "$DEALS_ID" ] && [ "$DEALS_ID" != "ERROR" ]; then
    sed -i '' "s|mailto:elie.priou7@gmail.com?subject=Deal%20Desk%20%E2%80%94%20%D7%99%D7%A9%20%D7%9C%D7%99%20%D7%A0%D7%9B%D7%A1|$DEALS_URL|g" "$LANDING"
    sed -i '' "s|TALLY_DEALS_URL|$DEALS_URL|g" "$LANDING"
  fi
  if [ -n "$INV_ID" ] && [ "$INV_ID" != "ERROR" ]; then
    sed -i '' "s|mailto:elie.priou7@gmail.com?subject=Deal%20Desk%20%E2%80%94%20%D7%90%D7%A0%D7%99%20%D7%9E%D7%97%D7%A4%D7%A9%20%D7%9C%D7%94%D7%A9%D7%A7%D7%99%D7%A2|$INV_URL|g" "$LANDING"
    sed -i '' "s|TALLY_INVESTORS_URL|$INV_URL|g" "$LANDING"
  fi
  echo -e "${GREEN}  ✓ Landing page updated${NC}"

  # Push updated index.html to GitHub via API
  FILE_B64=$(base64 -i "$LANDING" | tr -d '\n')
  FILE_SHA=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$GITHUB_REPO/contents/deal-desk/index.html" | \
    python3 -c "import sys,json; print(json.load(sys.stdin).get('sha',''))" 2>/dev/null)

  if [ -n "$FILE_SHA" ]; then
    PUSH_RESULT=$(curl -s -X PUT \
      "https://api.github.com/repos/$GITHUB_REPO/contents/deal-desk/index.html" \
      -H "Authorization: token $GITHUB_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"message\":\"Deal Desk: update with Tally form URLs\",\"content\":\"$FILE_B64\",\"sha\":\"$FILE_SHA\"}")
    if echo "$PUSH_RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if d.get('commit') else 1)" 2>/dev/null; then
      echo -e "${GREEN}  ✓ GitHub Pages updated — live at:${NC}"
      echo "      https://superiorealestate-byte.github.io/superior-real-estate-site/deal-desk/"
    else
      echo -e "${RED}  ✗ GitHub push failed${NC}"
    fi
  else
    echo -e "${RED}  ✗ Could not get file SHA from GitHub${NC}"
  fi
fi

# ── SUMMARY ──────────────────────────────────────────────────────
echo ""
echo -e "${GOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GOLD}  Setup Complete — Summary${NC}"
echo -e "${GOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Tally Deals form:     ${DEALS_URL:-not created}"
echo "  Tally Investors form: ${INV_URL:-not created}"
echo ""
echo "  Landing page:         https://superiorealestate-byte.github.io/superior-real-estate-site/deal-desk/"
echo "  Notion Deals DB:      https://www.notion.so/$NOTION_DEALS_DB"
echo "  Notion Investors DB:  https://www.notion.so/$NOTION_INVESTORS_DB"
echo ""
echo -e "${GOLD}  Action manuelle requise — Make.com:${NC}"
echo "  1. make.com → Scénario $MAKE_SCENARIO_DEALS → module Gmail → connecter compte"
echo "  2. make.com → Scénario $MAKE_SCENARIO_INVESTORS → module Gmail → connecter compte"
echo ""
echo -e "${GOLD}  Webhooks (actifs):${NC}"
echo "  Deals:     https://hook.eu2.make.com/mq14tenn2mbzz9unwkbro1y7ofxd7nuy"
echo "  Investors: https://hook.eu2.make.com/r6qgp30x7n24lyjcjihouybs21of9e8y"
echo ""
