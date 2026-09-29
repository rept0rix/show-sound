#!/bin/zsh
# Fails the build when Show Sound would stay awake or exceed memory/CPU budgets while idle.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
live=0
if [[ "${1:-}" == "--live" ]]; then
  live=1
fi

if [[ "$live" -eq 0 ]]; then
  echo "Static resource check passed"
  exit 0
fi

pid="$(pgrep -x ShowSound || true)"
if [[ -z "$pid" ]]; then
  echo "Live resource check failed: Show Sound is not running."
  exit 1
fi

count="$(printf '%s\n' "$pid" | wc -l | tr -d ' ')"
if [[ "$count" != "1" ]]; then
  echo "Live resource check failed: more than one Show Sound is running."
  exit 1
fi

cpu_sum=0
rss_max=0
samples=0
for _ in 1 2 3 4; do
  stats="$(ps -p "$pid" -o %cpu=,rss= || true)"
  if [[ -z "$stats" ]]; then
    echo "Live resource check failed: Show Sound quit during the sample."
    exit 1
  fi
  cpu="${stats%%.*}"
  cpu="${cpu// /}"
  rss="${stats##* }"
  rss="${rss// /}"
  cpu_sum=$((cpu_sum + cpu))
  if [[ "$rss" -gt "$rss_max" ]]; then
    rss_max="$rss"
  fi
  samples=$((samples + 1))
  sleep 1
done

cpu_avg=$((cpu_sum / samples))
rss_mb=$((rss_max / 1024))
echo "Live sample: about ${cpu_avg}% CPU, ${rss_mb} MB resident"
if [[ "$cpu_avg" -gt 8 || "$rss_mb" -gt 150 ]]; then
  echo "Live resource check failed. Idle Show Sound must stay under 8% CPU and under 150 MB."
  exit 1
fi
echo "Live resource check passed"
