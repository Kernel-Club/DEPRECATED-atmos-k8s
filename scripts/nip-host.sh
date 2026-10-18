#!/usr/bin/env bash
# Prints <prefix>.<load-balancer-ip>.nip.io for the Gateway, or nothing if the
# load balancer has no address yet.
#
# usage: scripts/nip-host.sh <namespace> <gateway-name> <prefix>
set -euo pipefail

namespace=$1
gateway=$2
prefix=$3

address=$(kubectl get gateway "$gateway" -n "$namespace" \
  -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || true)
[[ -n "$address" ]] || exit 0

if [[ "$address" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  ip=$address
else
  # An ALB has a DNS name that points to several IPs; any of them works.
  ip=$(getent ahostsv4 "$address" 2>/dev/null | awk 'NR==1 {print $1}' || true)
  [[ -n "$ip" ]] || ip=$(dig +short "$address" 2>/dev/null | grep -E '^[0-9.]+$' | head -1 || true)
fi
[[ -n "$ip" ]] || exit 0

echo "${prefix}.${ip}.nip.io"
