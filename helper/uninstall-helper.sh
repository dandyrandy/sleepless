#!/bin/sh
# Removes the Sleepless root helper and sudoers rule, restoring normal sleep.
# Must run as root: sudo ./uninstall-helper.sh
set -eu

/usr/bin/pmset -a disablesleep 0 || true
rm -f /etc/sudoers.d/sleepless /usr/local/libexec/sleepless-helper
echo "Sleepless helper uninstalled; normal sleep restored."
