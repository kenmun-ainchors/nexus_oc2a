#!/bin/zsh
# cron-agent-preflight.sh — Validate cron model is resolvable before assigning agentId
# Usage: zsh scripts/cron-agent-preflight.sh <cronId> <agentId>
# Exit:  0=PASS (model resolvable), 1=WARN (provider not configured), 2=FAIL (model not in allowlist)
# Part of CHG-0152 followup: prevent CI cycle failures from unresolvable models

set -u

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <cronId> <agentId>"
  echo "  Validates that the cron's model is resolvable for the target agentId before assignment."
  exit 2
fi

CRON_ID="$1"
AGENT_ID="$2"
OC_JSON="/Users/ainchorsoc2a/.openclaw/openclaw.json"

# Pull live cron list
CRON_STATE=$(openclaw cron list --json 2>/dev/null || echo '{"jobs":[]}')

# Pull agents config
AGENTS_CONFIG=$(openclaw config get agents 2>/dev/null || echo '{}')

CRON_STATE="$CRON_STATE" AGENTS_CONFIG="$AGENTS_CONFIG" python3 - "$CRON_ID" "$AGENT_ID" "$OC_JSON" << 'PYEOF'
import sys, json, re, os

cron_id   = sys.argv[1]
agent_id  = sys.argv[2]
oc_json   = sys.argv[3]

cron_state_raw = os.environ.get('CRON_STATE', '{"jobs":[]}')
agents_raw     = os.environ.get('AGENTS_CONFIG', '{}')

# --- Load cron state ---
try:
    cron_data = json.loads(cron_state_raw)
except Exception as e:
    print(f"❌ FAIL: Could not parse cron list: {e}")
    sys.exit(2)

# --- Find target cron ---
target_cron = None
for job in cron_data.get('jobs', []):
    if job.get('id') == cron_id or job.get('id', '').startswith(cron_id):
        target_cron = job
        break

if not target_cron:
    print(f"❌ FAIL: Cron '{cron_id}' not found in live cron list.")
    sys.exit(2)

cron_name = target_cron.get('name', cron_id)
payload = target_cron.get('payload', {})
model = payload.get('model', '')

if not model:
    print(f"⚠️  WARN: Cron '{cron_name}' has no model set in payload — will use agent/session default.")
    print(f"   Agent: {agent_id}")
    print(f"   Action: Safe to assign, but verify agent default model is configured.")
    sys.exit(1)

print(f"Cron:   {cron_name}")
print(f"Model:  {model}")
print(f"Agent:  {agent_id}")
print()

# --- Load agents allowlist ---
try:
    agents_config = json.loads(agents_raw)
except Exception as e:
    print(f"❌ FAIL: Could not parse agents config: {e}")
    sys.exit(2)

allowed_models = agents_config.get('defaults', {}).get('models', {})
if not allowed_models:
    print(f"❌ FAIL: agents.defaults.models is empty — cannot validate.")
    sys.exit(2)

# --- Check model in allowlist ---
if model not in allowed_models:
    print(f"❌ FAIL: model '{model}' is NOT in agents.defaults.models allowlist.")
    print(f"   Allowed: {', '.join(list(allowed_models.keys())[:6])}{'...' if len(allowed_models) > 6 else ''}")
    print(f"   Action:  Change cron model to an allowlisted model before assigning agentId.")
    sys.exit(2)

print(f"✅ Model '{model}' is in allowlist.")

# --- Load openclaw.json to check provider ---
try:
    with open(oc_json) as f:
        oc_data = json.load(f)
except Exception as e:
    print(f"❌ FAIL: Could not read openclaw.json at {oc_json}: {e}")
    sys.exit(2)

providers = oc_data.get('models', {}).get('providers', {})

# --- Determine provider from model string ---
# Model format: "provider/model-name" or "provider/model-name:tag"
model_parts = model.split('/', 1)
if len(model_parts) < 2:
    print(f"✅ PASS: model '{model}' uses default provider routing — safe to assign agentId '{agent_id}'.")
    sys.exit(0)

provider_name = model_parts[0]  # e.g. "anthropic", "ollama"
model_tag = model_parts[1]      # e.g. "deepseek-v4-pro:cloud", "claude-sonnet-4-6"
is_cloud_tag = model_tag.endswith(':cloud')

# Also check auth.profiles for non-ollama providers (e.g. anthropic configured via auth)
auth_profiles = oc_data.get('auth', {}).get('profiles', {})
all_auth_providers = set()
for profile_data in auth_profiles.values():
    if isinstance(profile_data, dict):
        all_auth_providers.update(profile_data.keys())
    elif isinstance(profile_data, list):
        for entry in profile_data:
            if isinstance(entry, dict) and 'provider' in entry:
                all_auth_providers.add(entry['provider'])
            elif isinstance(entry, str):
                all_auth_providers.add(entry)

# Check if provider exists in models.providers OR auth.profiles
provider_in_providers = provider_name in providers
provider_in_auth = provider_name in all_auth_providers or provider_name in str(auth_profiles).lower()

if provider_name == 'ollama':
    # Ollama must be in models.providers (local or cloud)
    if not provider_in_providers:
        print(f"❌ FAIL: Provider 'ollama' is not configured in openclaw.json models.providers.")
        sys.exit(2)
    provider_config = providers[provider_name]
    # --- Special check for ollama/:cloud models ---
    # :cloud means we need a non-localhost Ollama baseUrl
    if is_cloud_tag:
        # Cloud models work via local Ollama when it is signed in to Ollama Pro.
        # Check: is this cloud model registered in models.providers.ollama.models?
        # If yes → PASS (local Ollama proxies the cloud request).
        # If no  → WARN (model not registered; will fail at runtime with allowlist rejection).
        registered_model_ids = {m.get('id', '') for m in provider_config.get('models', [])}
        if model_tag in registered_model_ids:
            base_url = provider_config.get('baseUrl', '')
            print(f"✅ Cloud model '{model_tag}' is registered in ollama provider models.")
            print(f"   Ollama host: {base_url} (cloud routing via signed-in Ollama Pro)")
        else:
            print(f"⚠️  WARN: cloud model '{model_tag}' is NOT registered in models.providers.ollama.models.")
            print(f"   It is in agents.defaults.models allowlist but not in provider model catalog.")
            print(f"   OpenClaw cannot route to it — will fail with allowlist rejection at runtime.")
            print(f"   Action: Add model definition to models.providers.ollama.models in openclaw.json")
            print(f"   Then re-run this preflight.")
            print()
            print(f"⚠️  WARN: NOT safe to assign agentId '{agent_id}' until model is registered in provider.")
            sys.exit(1)
else:
    # Non-ollama (e.g. anthropic): check auth.profiles or models.providers
    if not provider_in_providers and not provider_in_auth:
        print(f"❌ FAIL: Provider '{provider_name}' is not configured in openclaw.json (checked models.providers and auth.profiles).")
        print(f"   Action:  Add provider config or API key for '{provider_name}', or change cron model.")
        sys.exit(2)
    print(f"✅ Provider '{provider_name}' is configured (auth/providers).")

# --- All checks passed ---
print(f"✅ PASS: model '{model}' is resolvable — safe to assign agentId '{agent_id}' to cron '{cron_name}'.")
sys.exit(0)
PYEOF
EXIT_CODE=$?
exit $EXIT_CODE
