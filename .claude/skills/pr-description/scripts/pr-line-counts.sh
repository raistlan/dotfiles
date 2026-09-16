#!/bin/sh
# Break a PR's diff into line counts by function (logic, tests, docs, ...).
#
# Usage: pr-line-counts.sh [base-ref]
# Base defaults to the repo's default branch via origin/HEAD, else main.
#
# Aggregation runs in awk rather than the shell because macOS ships bash 3.2,
# which has no associative arrays.

set -eu

base="${1:-}"
if [ -z "$base" ]; then
  if base_ref=$(git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null); then
    base=$(printf '%s' "$base_ref" | sed 's|^refs/remotes/||')
  else
    base="main"
  fi
fi

git diff --numstat -M "$base"...HEAD | awk -F'\t' '
# Classification is first-match-wins, so ordering here is load-bearing:
# generated output would otherwise read as config, and a migration test would
# read as a test rather than as schema churn.
function classify(p) {
  if (p ~ /(openapi-spec\.json|\/generated\/|\/__generated__\/|\.gen\.|_pb2\.py|\.generated\.)/) return "generated"
  if (p ~ /(^|\/)(pnpm-lock\.yaml|package-lock\.json|yarn\.lock|poetry\.lock|uv\.lock)$/) return "generated"
  if (p ~ /^\.cursor\/rules\//) return "generated"
  if (p ~ /web\/packages\/api\/src\/(models|resources|descriptors)\//) return "generated"
  if (p ~ /(^|\/)service\.datadog\.yaml$/) return "generated"
  if (p ~ /(\/|^)(migrations|alembic|versions|fixtures)\//) return "fixtures"
  if (p ~ /fixture[^\/]*\.(json|ya?ml|sql|csv)$/) return "fixtures"
  if (p ~ /(\/|^)(tests?|unit_tests|__tests__|__mocks__|e2e)\//) return "tests"
  if (p ~ /(^|\/)(test_[^\/]*|[^\/]*_test)\.py$/) return "tests"
  if (p ~ /(^|\/)conftest\.py$/) return "tests"
  if (p ~ /\.(test|spec)\.(t|j)sx?$/) return "tests"
  if (p ~ /\.feature$/) return "tests"
  if (p ~ /\.(md|mdx|rst|txt)$/) return "docs"
  if (p ~ /(\/|^)docs\//) return "docs"
  if (p ~ /^\.rulesync\//) return "docs"
  if (p ~ /\.(ya?ml|toml|ini|cfg|json)$/) return "config"
  if (p ~ /(^|\/)(Dockerfile[^\/]*|Makefile|\.env[^\/]*|[^\/]*ignore)$/) return "config"
  if (p ~ /^\.github\//) return "config"
  return "logic"
}
{
  path = $3
  # Renames arrive as "dir/{old => new}/f" or "old => new"; keep the new path so
  # a moved file is classified by where it landed, not where it came from.
  if (path ~ /\{[^{}]* => [^{}]*\}/) {
    inner = path
    sub(/.*\{[^{}]* => /, "", inner)
    sub(/\}.*/, "", inner)
    sub(/\{[^{}]* => [^{}]*\}/, inner, path)
  } else if (path ~ / => /) {
    sub(/.* => /, "", path)
  }
  # Binary files report "-" for both counts and have no meaningful line count.
  if ($1 == "-") next
  b = classify(path)
  add[b] += $1; del[b] += $2; files[b]++
  tadd += $1; tdel += $2; tfiles++
}
END {
  n = split("logic tests docs config generated fixtures", order, " ")
  total = tadd + tdel
  # Rounding each bucket on its own lets the column sum to 99 or 101 against a
  # Total row that always claims 100%. Apportion by largest remainder instead:
  # floor every share, then hand the spare points to the biggest fractions.
  for (i = 1; i <= n; i++) {
    b = order[i]
    churn = add[b] + del[b]
    if (churn == 0) continue
    idx[++shown] = b
    exact = total > 0 ? churn * 100 / total : 0
    pct[b] = int(exact)
    rem[b] = exact - pct[b]
    floorsum += pct[b]
  }
  leftover = total > 0 ? 100 - floorsum : 0
  while (leftover-- > 0) {
    best = ""; bestrem = -1
    for (i = 1; i <= shown; i++) {
      b = idx[i]
      if (rem[b] > bestrem) { bestrem = rem[b]; best = b }
    }
    if (best == "") break
    pct[best]++; rem[best] = -1
  }
  print "| Function | Files | +Added | -Removed | % of diff |"
  print "| --- | --- | --- | --- | --- |"
  for (i = 1; i <= shown; i++) {
    b = idx[i]
    printf "| %s | %d | +%d | -%d | %d%% |\n", b, files[b], add[b], del[b], pct[b]
  }
  printf "| **Total** | %d | +%d | -%d | 100%% |\n", tfiles, tadd, tdel
}
'
