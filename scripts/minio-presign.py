#!/usr/bin/env python3
"""
AWS v4 presigned GET URL generator — pure stdlib, zero network calls.
Signs for the Tailscale HTTPS endpoint so URLs work from Ken's Windows machine.
"""
import sys, os, hmac, hashlib, datetime, subprocess, urllib.parse, warnings
warnings.filterwarnings("ignore")

# CHG-MINIO-RESTORE 2026-07-14: new OC2A Tailscale hostname replaces old OC1 endpoint.
ENDPOINT = "ainchorsoc2as-mac-mini-1.tailfc3ed1.ts.net"
REGION = "us-east-1"
SERVICE = "s3"

# Resolve secrets dir from script location (env override: MINIO_SECRETS_DIR).
_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_DEFAULT_SECRETS_DIR = os.path.normpath(os.path.join(_SCRIPT_DIR, os.pardir, "infra", "minio", "secrets"))
SECRETS_DIR = os.environ.get("MINIO_SECRETS_DIR", _DEFAULT_SECRETS_DIR)
_KEYCHAIN_SERVICE = "ainchors-minio"
_KEYCHAIN_ACCOUNT = "ainchors-minio"

def get_creds():
    user_path = os.path.join(SECRETS_DIR, "minio_user.txt")
    pw_path   = os.path.join(SECRETS_DIR, "minio_password.txt")
    with open(user_path) as f:
        user = f.read().strip()
    pw = ""
    try:
        r = subprocess.run(
            ["security", "find-generic-password",
             "-s", _KEYCHAIN_SERVICE, "-a", _KEYCHAIN_ACCOUNT, "-w"],
            capture_output=True, text=True, timeout=5,
        )
        if r.returncode == 0:
            pw = r.stdout.strip()
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pw = ""
    if not pw and os.path.exists(pw_path):
        with open(pw_path) as f:
            pw = f.read().strip()
    return user, pw

def sign(key, msg):
    return hmac.new(key, msg.encode(), hashlib.sha256).digest()

def get_signing_key(secret_key, date_stamp):
    k_date    = sign(("AWS4" + secret_key).encode(), date_stamp)
    k_region  = sign(k_date, REGION)
    k_service = sign(k_region, SERVICE)
    k_signing = sign(k_service, "aws4_request")
    return k_signing

def presign(bucket, key, expires=86400):
    access_key, secret_key = get_creds()
    now = datetime.datetime.utcnow()
    datestamp  = now.strftime("%Y%m%d")
    amzdate    = now.strftime("%Y%m%dT%H%M%SZ")

    host = ENDPOINT
    canonical_uri = f"/{bucket}/{key}"
    credential_scope = f"{datestamp}/{REGION}/{SERVICE}/aws4_request"
    credential = f"{access_key}/{credential_scope}"

    query = {
        "X-Amz-Algorithm":     "AWS4-HMAC-SHA256",
        "X-Amz-Credential":    credential,
        "X-Amz-Date":          amzdate,
        "X-Amz-Expires":       str(expires),
        "X-Amz-SignedHeaders": "host",
    }
    canonical_qs = "&".join(f"{urllib.parse.quote(k,safe='')}={urllib.parse.quote(v,safe='')}"
                            for k, v in sorted(query.items()))

    canonical_headers = f"host:{host}\n"
    payload_hash = "UNSIGNED-PAYLOAD"

    canonical_request = "\n".join([
        "GET", canonical_uri, canonical_qs,
        canonical_headers, "host", payload_hash
    ])

    string_to_sign = "\n".join([
        "AWS4-HMAC-SHA256", amzdate, credential_scope,
        hashlib.sha256(canonical_request.encode()).hexdigest()
    ])

    signing_key = get_signing_key(secret_key, datestamp)
    signature = hmac.new(signing_key, string_to_sign.encode(), hashlib.sha256).hexdigest()

    url = (f"https://{host}{canonical_uri}?{canonical_qs}"
           f"&X-Amz-Signature={signature}")
    return url

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: minio-presign.py <bucket> <key> [expires_seconds]", file=sys.stderr)
        sys.exit(1)
    bucket  = sys.argv[1]
    key     = sys.argv[2]
    expires = int(sys.argv[3]) if len(sys.argv) > 3 else 86400
    print(presign(bucket, key, expires))
