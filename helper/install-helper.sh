#!/bin/sh
# Installs the Sleepless root helper and a sudoers rule scoped to it.
# Must run as root: sudo ./install-helper.sh <username>
set -eu

USERNAME="${1:?usage: install-helper.sh <username>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HELPER_DEST=/usr/local/libexec/sleepless-helper
SUDOERS_DEST=/etc/sudoers.d/sleepless

# The username is interpolated into sudoers — insist it is a real, sane account name.
/usr/bin/id "$USERNAME" >/dev/null
case "$USERNAME" in
    *[!A-Za-z0-9._-]*) echo "refusing suspicious username: $USERNAME" >&2; exit 1 ;;
esac

# Helper must be root-owned and not user-writable, or the NOPASSWD rule would be
# a privilege escalation.
/usr/bin/install -d -o root -g wheel -m 755 /usr/local/libexec
/usr/bin/install -o root -g wheel -m 755 "$SCRIPT_DIR/sleepless-helper" "$HELPER_DEST"

SUDOERS_TMP="$(mktemp)"
trap 'rm -f "$SUDOERS_TMP"' EXIT
printf '%s ALL=(root) NOPASSWD: %s on, %s off\n' "$USERNAME" "$HELPER_DEST" "$HELPER_DEST" > "$SUDOERS_TMP"
/usr/sbin/visudo -c -f "$SUDOERS_TMP"
/usr/bin/install -o root -g wheel -m 440 "$SUDOERS_TMP" "$SUDOERS_DEST"

echo "Installed $HELPER_DEST and $SUDOERS_DEST for user $USERNAME"
