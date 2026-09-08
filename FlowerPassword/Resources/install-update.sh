#!/bin/sh
# Runs outside the bundle being replaced. Keep staging on any failure so a
# surviving previous.app is available for manual recovery.
set -eu
old_pid=$1
app=$2
staging=$3
new_app=$4
executable=$5
backup="$staging/previous.app"
ready="$staging/ready"

while /bin/kill -0 "$old_pid" 2>/dev/null; do /bin/sleep 0.1; done
/bin/mv "$app" "$backup"
if ! /bin/mv "$new_app" "$app"; then
    /bin/mv "$backup" "$app"
    /usr/bin/open "$app"
    exit 1
fi
"$app/Contents/MacOS/$executable" --update-ready "$ready" &
new_pid=$!
# ponytail: startup acknowledgement only; post-start crashes need a richer health protocol.
for attempt in $(/usr/bin/seq 1 100); do
    if [ -f "$ready" ] && /bin/kill -0 "$new_pid" 2>/dev/null; then
        /bin/rm -rf "$staging"
        exit 0
    fi
    /bin/kill -0 "$new_pid" 2>/dev/null || break
    /bin/sleep 0.1
done
/bin/kill "$new_pid" 2>/dev/null || true
wait "$new_pid" 2>/dev/null || true
/bin/mv "$app" "$staging/failed.app"
/bin/mv "$backup" "$app"
/usr/bin/open "$app"
