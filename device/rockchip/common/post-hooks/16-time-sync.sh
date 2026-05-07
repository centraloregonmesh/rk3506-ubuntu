#!/bin/bash -e

source "${RK_POST_HELPER:-$(dirname "$(realpath "$0")")/post-helper}"

[ "$POST_OS" = ubuntu ] || exit 0

message "Configuring UTC timezone and systemd-timesyncd..."

install -d "$TARGET_DIR/etc/systemd/timesyncd.conf.d"
install -d "$TARGET_DIR/etc/systemd/system/sysinit.target.wants"
install -d "$TARGET_DIR/var/lib/systemd/timesync"

echo "Etc/UTC" > "$TARGET_DIR/etc/timezone"
ln -snf /usr/share/zoneinfo/Etc/UTC "$TARGET_DIR/etc/localtime"

cat > "$TARGET_DIR/etc/systemd/timesyncd.conf.d/10-lyra.conf" <<'EOF'
[Time]
NTP=ntp.ubuntu.com time.cloudflare.com time.google.com
FallbackNTP=0.ubuntu.pool.ntp.org 1.ubuntu.pool.ntp.org 2.ubuntu.pool.ntp.org 3.ubuntu.pool.ntp.org
EOF

if [ -e "$TARGET_DIR/lib/systemd/system/systemd-timesyncd.service" ]; then
	ln -rsf "$TARGET_DIR/lib/systemd/system/systemd-timesyncd.service" \
		"$TARGET_DIR/etc/systemd/system/sysinit.target.wants/systemd-timesyncd.service"
	ln -rsf "$TARGET_DIR/lib/systemd/system/systemd-timesyncd.service" \
		"$TARGET_DIR/etc/systemd/system/dbus-org.freedesktop.timesync1.service"
elif [ -e "$TARGET_DIR/usr/lib/systemd/system/systemd-timesyncd.service" ]; then
	ln -rsf "$TARGET_DIR/usr/lib/systemd/system/systemd-timesyncd.service" \
		"$TARGET_DIR/etc/systemd/system/sysinit.target.wants/systemd-timesyncd.service"
	ln -rsf "$TARGET_DIR/usr/lib/systemd/system/systemd-timesyncd.service" \
		"$TARGET_DIR/etc/systemd/system/dbus-org.freedesktop.timesync1.service"
else
	warning "systemd-timesyncd service not found; timezone configured only"
fi

# Seed systemd-timesyncd's monotonic clock file with image build time so
# first boot starts near the image date even before network NTP completes.
touch "$TARGET_DIR/var/lib/systemd/timesync/clock"
chmod 0755 "$TARGET_DIR/var/lib/systemd/timesync"
chmod 0644 "$TARGET_DIR/var/lib/systemd/timesync/clock"

TIMESYNC_UID="$(awk -F: '$1 == "systemd-timesync" { print $3 }' "$TARGET_DIR/etc/passwd" 2>/dev/null || true)"
TIMESYNC_GID="$(awk -F: '$1 == "systemd-timesync" { print $3 }' "$TARGET_DIR/etc/group" 2>/dev/null || true)"
if [ "$TIMESYNC_UID" ] && [ "$TIMESYNC_GID" ]; then
	chown "$TIMESYNC_UID:$TIMESYNC_GID" \
		"$TARGET_DIR/var/lib/systemd/timesync" \
		"$TARGET_DIR/var/lib/systemd/timesync/clock"
fi
