#!/usr/bin/env bash
set -euo pipefail

# Usage: ./certbot_client_cleanup.sh <pattern>
# Example: ./certbot_client_cleanup.sh montreuil

PATTERN="${1:-}"
if [[ -z "$PATTERN" ]]; then
  echo "Usage: $0 <pattern>"
  exit 1
fi

if ! command -v certbot >/dev/null 2>&1; then
  echo "Error: certbot not found in PATH"
  exit 1
fi

NGINX_DIRS=(/etc/nginx/conf.d/prod /etc/nginx/conf.d/internal /etc/nginx/conf.d/re7)

echo "Searching certbot certificates matching pattern: '$PATTERN'"
echo

# 1) Find matching cert names from certbot inventory
mapfile -t MATCHING < <(
  certbot certificates 2>/dev/null | awk -v pat="$PATTERN" '
    function ord(c) { return index("\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x0C\x0D\x0E\x0F\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1A\x1B\x1C\x1D\x1E\x1F !\"#$%&'\''()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\x7F", c)-1 }
    function lc(s,   out,i,ch) {
      out=s
      for (i=1; i<=length(out); i++) {
        ch=substr(out,i,1)
        if (ch>="A" && ch<="Z") out = substr(out,1,i-1) sprintf("%c", ord(ch)+32) substr(out,i+1)
      }
      return out
    }
    function flush() {
      if (cname != "" && (block_lc ~ pat_lc)) {
        printf "%s\t%s\t%s\t%s\n", cname, domains, expiry, certpath
      }
      cname=""; domains=""; expiry=""; certpath=""; block_lc=""
    }
    BEGIN { pat_lc = lc(pat) }
    /^  Certificate Name: / {
      flush()
      cname = $0; sub(/^  Certificate Name: /, "", cname)
      block_lc = lc(cname)
      next
    }
    /^    Domains: / {
      domains = $0; sub(/^    Domains: /, "", domains)
      block_lc = block_lc " " lc(domains)
      next
    }
    /^    Expiry Date: / {
      expiry = $0; sub(/^    Expiry Date: /, "", expiry)
      block_lc = block_lc " " lc(expiry)
      next
    }
    /^    Certificate Path: / {
      certpath = $0; sub(/^    Certificate Path: /, "", certpath)
      block_lc = block_lc " " lc(certpath)
      next
    }
    END { flush() }
  '
)

if [[ ${#MATCHING[@]} -eq 0 ]]; then
  echo "No matching certificates found for pattern '$PATTERN'."
  exit 0
fi

echo "Candidate certbot lineages:"
echo "---------------------------------------------------------"
printf "%-35s %-60s %-35s\n" "CERT-NAME" "DOMAINS" "EXPIRY"
echo "---------------------------------------------------------"

CERT_NAMES=()
for rec in "${MATCHING[@]}"; do
  IFS=$'\t' read -r cname domains expiry certpath <<<"$rec"
  CERT_NAMES+=("$cname")
  printf "%-35s %-60s %-35s\n" "$cname" "$(printf "%s" "$domains" | cut -c1-60)" "$(printf "%s" "$expiry" | cut -c1-35)"
done
echo "---------------------------------------------------------"
echo

# 2) Nginx usage check (only your directories)
echo "NGINX usage check (searching only in):"
printf " - %s\n" "${NGINX_DIRS[@]}"
echo

USED_ANY=0
for cname in "${CERT_NAMES[@]}"; do
  live_dir="/etc/letsencrypt/live/${cname}"
  fullchain="${live_dir}/fullchain.pem"
  privkey="${live_dir}/privkey.pem"

  echo "---- $cname ----"
  echo "Looking for:"
  echo "  $fullchain"
  echo "  $privkey"
  echo

  used=0

  for d in "${NGINX_DIRS[@]}"; do
    [[ -d "$d" ]] || continue

    # Show exact files + lines where referenced
    if grep -R --line-number --fixed-strings "$fullchain" "$d" 2>/dev/null; then
      used=1
    fi
    if grep -R --line-number --fixed-strings "$privkey" "$d" 2>/dev/null; then
      used=1
    fi
  done

  if [[ "$used" -eq 1 ]]; then
    echo
    echo "STATUS: USED by nginx (found reference(s) above)."
    USED_ANY=1
  else
    echo "STATUS: NOT FOUND in scanned nginx conf dirs."
  fi
  echo
done

# 3) Optional: quick nginx syntax test (doesn't guarantee usage, but confirms current config is valid)
echo "Nginx config syntax test:"
if nginx -t; then
  echo "nginx -t: OK"
else
  echo "nginx -t: FAILED (fix this before deleting anything)."
fi
echo

# 4) Decision prompt
if [[ "$USED_ANY" -eq 1 ]]; then
  echo "At least one matching certificate is still referenced by nginx."
  echo "Recommendation: do NOT delete until you've updated/removed those vhosts (paths shown above)."
else
  echo "No references found in nginx for these certs (within the scanned directories)."
  echo "It should be safe to delete from certbot perspective."
fi
echo

read -r -p "Type 'DELETE' to delete ${#CERT_NAMES[@]} certificate(s), or anything else to abort: " CONFIRM
if [[ "$CONFIRM" != "DELETE" ]]; then
  echo "Aborted."
  exit 0
fi

echo
for cname in "${CERT_NAMES[@]}"; do
  echo " -> certbot delete --cert-name $cname"
  certbot delete --cert-name "$cname"
done

echo
echo "Done. Final check recommended:"
echo "  nginx -t && systemctl reload nginx"
