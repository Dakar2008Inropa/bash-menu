#!/bin/bash
# Egen grep: læs stdin (pipe), farv søgeord, tæl forekomster.
# Brug: cat fil.txt | ./tools/mygrep.sh søgeord
set -euo pipefail
word=${1:-}
if [[ -z $word ]]; then
    echo "Brug: $0 <søgeord>   (typisk via pipe)" >&2
    exit 1
fi
RED=$'\e[31m'
R=$'\e[0m'
count=0
while IFS= read -r line || [[ -n $line ]]; do
    if grep -qi -- "$word" <<<"$line"; then
        # shellcheck disable=SC2001
        echo "$line" | sed -E "s/(${word})/${RED}\1${R}/Ig"
        n=$(grep -oi -- "$word" <<<"$line" | wc -l)
        count=$((count + n))
    fi
done
echo "---"
echo "Total: $count"
