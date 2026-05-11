#!/usr/bin/env python3
"""
AWS v4 presigned GET URL generator — pure stdlib, zero network calls.
Signs for the Tailscale HTTPS endpoint so URLs work from Ken's Windows machine.
"""
import sys, hmac, hashlib, datetime, subprocess, urllib.parse, warnings
warnings.filterwarnings("ignore")

ENDPOINT = "ainchorss-mac-mini.tail5e2567.ts.net"
REGION = "us-east-1"
SERVICE = "s3"

def get_creds():
    with open("/Users/ainchorsangiefpl/.openclaw/workspace/infra/minio/secrets/minio_user.txt") as f:
        user = f.read().strip()
    r = subprocess.run(["security","find-generic-password","-s","ainchors-minio","-w"],
                       capture_output=True, text=True)
    if r.returncode == 0:
        pw = r.stdout.strip()
    else:
        with open("/Users/ainchorsangiefpl/.openclaw/workspace/infra/minio/secrets/minio_password.txt") as f:
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
