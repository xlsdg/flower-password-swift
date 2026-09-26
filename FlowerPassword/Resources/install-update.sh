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

restore() {
    /usr/bin/pkill -f "$app/Contents/MacOS/$executable" 2>/dev/null || true
    /bin/mv "$app" "$staging/failed.app"
    /bin/mv "$backup" "$app"
    /usr/bin/open "$app"
    exit 1
}

while /bin/kill -0 "$old_pid" 2>/dev/null; do /bin/sleep 0.1; done
/bin/mv "$app" "$backup"
if ! /bin/mv "$new_app" "$app"; then
    /bin/mv "$backup" "$app"
    /usr/bin/open "$app"
    exit 1
fi
# LaunchServices, not a direct exec: a child of this script would inherit the
# old app as its TCC responsible process, and that bundle is deleted below.
/usr/bin/open -n "$app" --args --update-ready "$ready" || restore
# ponytail: startup acknowledgement only; post-start crashes need a richer health protocol.
for attempt in $(/usr/bin/seq 1 100); do
    if [ -f "$ready" ]; then
        /bin/rm -rf "$staging"
        exit 0
    fi
    /bin/sleep 0.1
done
restore
