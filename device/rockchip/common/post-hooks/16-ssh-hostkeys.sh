#!/bin/bash -e

source "${RK_POST_HELPER:-$(dirname "$(realpath "$0")")/post-helper}"

[ "$POST_OS" = ubuntu ] || exit 0

message "Installing SSH host key first-boot service..."

install -d "$TARGET_DIR/usr/lib/systemd/system" \
	"$TARGET_DIR/etc/systemd/system/lyra-ssh-hostkeys.service.d" \
	"$TARGET_DIR/etc/systemd/system/ssh.service.d" \
	"$TARGET_DIR/etc/systemd/system/ssh.socket.d" \
	"$TARGET_DIR/etc/systemd/system/multi-user.target.wants" \
	"$TARGET_DIR/etc/systemd/system/sockets.target.wants"

cat > "$TARGET_DIR/usr/lib/systemd/system/lyra-ssh-hostkeys.service" <<'EOF'
[Unit]
Description=Generate SSH host keys
DefaultDependencies=no
After=local-fs.target
Before=ssh.service ssh.socket

[Service]
Type=oneshot
ExecStart=/bin/sh -c '[ -e /etc/ssh/ssh_host_ed25519_key ] || /usr/bin/ssh-keygen -A'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
WantedBy=sockets.target
EOF

cat > "$TARGET_DIR/etc/systemd/system/ssh.service.d/10-lyra-hostkeys.conf" <<'EOF'
[Unit]
Wants=lyra-ssh-hostkeys.service
After=lyra-ssh-hostkeys.service
EOF

cat > "$TARGET_DIR/etc/systemd/system/ssh.socket.d/10-lyra-hostkeys.conf" <<'EOF'
[Unit]
Wants=lyra-ssh-hostkeys.service
After=lyra-ssh-hostkeys.service
EOF

rm -f "$TARGET_DIR/etc/ssh/sshd_not_to_be_run"

ln -rsf "$TARGET_DIR/usr/lib/systemd/system/lyra-ssh-hostkeys.service" \
	"$TARGET_DIR/etc/systemd/system/multi-user.target.wants/lyra-ssh-hostkeys.service"
ln -rsf "$TARGET_DIR/usr/lib/systemd/system/lyra-ssh-hostkeys.service" \
	"$TARGET_DIR/etc/systemd/system/sockets.target.wants/lyra-ssh-hostkeys.service"
ln -rsf "$TARGET_DIR/usr/lib/systemd/system/ssh.service" \
	"$TARGET_DIR/etc/systemd/system/multi-user.target.wants/ssh.service"
ln -rsf "$TARGET_DIR/usr/lib/systemd/system/ssh.socket" \
	"$TARGET_DIR/etc/systemd/system/sockets.target.wants/ssh.socket"
