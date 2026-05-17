#!/bin/bash
NOTION_KEY=$(cat ~/.config/notion/api_key 2>/dev/null)
API="https://api.notion.com/v1"

update_page() {
  local page_id="$1"
  local date="$2"
  local item_id="$3"
  local out=$(curl -s -X PATCH "${API}/pages/${page_id}" \
    -H "Authorization: Bearer ${NOTION_KEY}" \
    -H "Notion-Version: 2025-09-03" \
    -H "Content-Type: application/json" \
    -d "{\"properties\":{\"Delivered Date\":{\"date\":{\"start\":\"${date}\"}}}}")
  if echo "$out" | grep -q '"object":"error"'; then
    local code=$(echo "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('code','unknown'))")
    echo "FAIL ${item_id}: ${code}"
    echo "{\"id\":\"${item_id}\",\"page\":\"${page_id}\",\"code\":\"${code}\",\"date\":\"${date}\"}"
  else
    echo "OK   ${item_id} -> ${date}"
    echo "{\"id\":\"${item_id}\",\"page\":\"${page_id}\",\"date\":\"${date}\"}"
  fi
  sleep 0.4
}

{
update_page "363c1829-53ff-8195-a51a-e5fa94bbda0d" "2026-05-17" "TKT-0194"
update_page "362c1829-53ff-813e-8a94-ed456d3cde86" "2026-05-17" "CHG-0361"
update_page "362c1829-53ff-81f0-87cc-f8c1f04ebec0" "2026-05-16" "CHG-0359"
update_page "362c1829-53ff-8156-b3bf-f6f911737430" "2026-05-16" "CHG-0356"
update_page "361c1829-53ff-81f8-94b1-eaa654b4922d" "2026-05-14" "CHG-0353"
update_page "361c1829-53ff-8149-b72b-fc1367f058c4" "2026-05-14" "CHG-0352"
update_page "361c1829-53ff-81a9-bd81-f3248029a5be" "2026-05-14" "CHG-0351"
update_page "361c1829-53ff-81d3-af35-f6dc56f28cd9" "2026-05-14" "CHG-0350"
update_page "361c1829-53ff-813a-a7d0-c5b2ec183c30" "2026-05-14" "CHG-0349"
update_page "361c1829-53ff-814c-8826-d73863d182e6" "2026-05-14" "CHG-0348"
update_page "361c1829-53ff-8191-9b85-e47174331293" "2026-05-14" "CHG-0347"
update_page "361c1829-53ff-8144-beed-fe99376f7e21" "2026-05-14" "CHG-0346"
update_page "361c1829-53ff-81d0-a954-f6e097942893" "2026-05-14" "CHG-0345"
update_page "361c1829-53ff-8196-9bd0-dda6895462cc" "2026-05-14" "CHG-0344"
update_page "361c1829-53ff-810b-849b-ff1bdee7d2cf" "2026-05-14" "CHG-0343"
update_page "361c1829-53ff-8109-baf5-e3cc71303d1c" "2026-05-14" "CHG-0342"
update_page "361c1829-53ff-815d-8e95-c667b70f7aa7" "2026-05-14" "CHG-0341"
update_page "361c1829-53ff-81e4-b10a-ca1bb9bf7d41" "2026-05-12" "TKT-0154"
update_page "361c1829-53ff-81e7-aa58-f9684dc5195b" "2026-05-11" "TKT-0146"
update_page "361c1829-53ff-8168-92fb-fc951fe6cf41" "2026-05-11" "TKT-0145"
update_page "361c1829-53ff-8189-9dec-c258e7dc8944" "2026-05-11" "TKT-0144"
update_page "361c1829-53ff-8155-a419-cf3e26c86cb8" "2026-05-10" "TKT-0140"
update_page "361c1829-53ff-8174-934b-d6f923ceddfd" "2026-05-13" "TKT-0135"
update_page "361c1829-53ff-81a5-ad6f-c9e829dd6cac" "2026-05-10" "TKT-0126"
update_page "361c1829-53ff-8164-bbfd-c7a4f65dc164" "2026-05-10" "TKT-0125"
update_page "361c1829-53ff-816d-b4ba-cbca39cea269" "2026-05-11" "TKT-0124"
update_page "361c1829-53ff-81a2-a145-c8949a768f3b" "2026-05-10" "TKT-0123"
update_page "361c1829-53ff-8109-9b36-cf57929de2b6" "2026-05-10" "TKT-0121"
update_page "361c1829-53ff-8116-8598-dd823aa557e7" "2026-05-12" "TKT-0120"
update_page "361c1829-53ff-818d-ba4c-f49eee4f8da9" "2026-05-10" "TKT-0113"
update_page "361c1829-53ff-81d0-b8d6-ed7e7052f114" "2026-05-10" "TKT-0112"
update_page "361c1829-53ff-81ab-8217-e22f5846836d" "2026-05-12" "TKT-0111"
update_page "361c1829-53ff-814c-81e2-dd1792a81094" "2026-05-10" "TKT-0106"
update_page "361c1829-53ff-8118-be5d-c1051234baf6" "2026-05-10" "TKT-0105"
update_page "361c1829-53ff-810e-a09c-e218ce76f910" "2026-05-08" "TKT-0104"
update_page "361c1829-53ff-81ac-a32a-e4fc2dcf6fb5" "2026-05-14" "CHG-0340"
update_page "361c1829-53ff-81ad-9580-f6df9e823ae6" "2026-05-14" "TKT-0185"
update_page "361c1829-53ff-8154-946d-f84e9321602a" "2026-05-14" "CHG-0339"
update_page "361c1829-53ff-816a-983f-ff98888ea4df" "2026-05-13" "CHG-0337"
update_page "361c1829-53ff-8135-8d63-fe8d28fda930" "2026-05-13" "CHG-0336"
update_page "361c1829-53ff-818b-8bb5-ca7547ef3232" "2026-05-13" "CHG-0335"
update_page "361c1829-53ff-81b4-8d92-d72d882e490c" "2026-05-13" "CHG-0334"
update_page "361c1829-53ff-811d-847e-c1e4fa01e1fa" "2026-05-13" "CHG-0333"
update_page "361c1829-53ff-81b0-aff9-d9ca3908f449" "2026-05-13" "CHG-0332"
update_page "361c1829-53ff-810e-b44a-e49712a4d5f1" "2026-05-13" "CHG-0331"
update_page "361c1829-53ff-817d-9c8c-c4ff8b094d9a" "2026-05-13" "CHG-0330"
update_page "361c1829-53ff-8177-ba69-fd0b649ce7b9" "2026-05-13" "CHG-0329"
update_page "360c1829-53ff-81a7-bd84-fb1828d754e0" "2026-05-13" "CHG-0328"
update_page "360c1829-53ff-81f3-ab9b-efe8b211cdf5" "2026-05-13" "CHG-0327"
update_page "360c1829-53ff-81ef-92e7-eccaa2e3380d" "2026-05-13" "CHG-0326"
update_page "360c1829-53ff-81ea-80e6-c94593861c60" "2026-05-13" "CHG-0325"
update_page "360c1829-53ff-8116-b452-e8e385793877" "2026-05-13" "TKT-0177"
update_page "360c1829-53ff-817d-b543-e8f2d33888d7" "2026-05-13" "AUTO-HEAL-MD"
update_page "360c1829-53ff-81e1-a820-d3fbb23ae5cf" "2026-05-13" "AUTO-HEAL-BK"
update_page "360c1829-53ff-8166-8aa1-efc104b3e8b7" "2026-05-13" "CHG-0324"
update_page "360c1829-53ff-8124-b25a-c939a9629220" "2026-05-15" "TKT-0175"
update_page "360c1829-53ff-8177-af35-f715a04fbe38" "2026-05-13" "CHG-0323"
update_page "360c1829-53ff-8135-8215-f152b3e9ab82" "2026-05-13" "CHG-0322"
update_page "360c1829-53ff-815c-8556-d603f5860bbf" "2026-05-13" "AUTO-HEAL-FP"
update_page "360c1829-53ff-81f3-8dd6-c614aa87143a" "2026-05-13" "AUTO-HEAL-BK2"
update_page "360c1829-53ff-8152-abb2-cc7fdeba6b3c" "2026-05-13" "CHG-0321"
update_page "360c1829-53ff-81e6-8209-c7e268e6f403" "2026-05-13" "CHG-0320"
update_page "360c1829-53ff-81ed-8f8a-eb4c4f6e6408" "2026-05-13" "CHG-0306"
update_page "360c1829-53ff-816f-a04c-c4eca21bddfa" "2026-05-13" "AUTO-HEAL-BK3"
update_page "360c1829-53ff-814e-840e-f645a77a139e" "2026-05-14" "CHG-0319"
update_page "360c1829-53ff-81d4-8bc3-f7c68d82c661" "2026-05-14" "CHG-0318"
update_page "360c1829-53ff-810a-a236-e39b67821485" "2026-05-14" "CHG-0317"
update_page "360c1829-53ff-8126-a55d-c5640205fcf7" "2026-05-14" "CHG-0316"
update_page "360c1829-53ff-817b-8308-fcecc1c496b6" "2026-05-14" "CHG-0315"
update_page "360c1829-53ff-816a-b531-e58f65d88481" "2026-05-14" "CHG-0314"
} | tee /tmp/notion_fix_delivered.log

echo ""
echo "=== SUMMARY ==="
ok_count=$(grep -c "^OK" /tmp/notion_fix_delivered.log || true)
fail_count=$(grep -c "^FAIL" /tmp/notion_fix_delivered.log || true)
echo "OK: ${ok_count}"
echo "FAIL: ${fail_count}"
