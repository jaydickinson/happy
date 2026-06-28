#!/bin/bash
#
# Happy VPS Setup Script
#
# Solves: Claude Code refuses --dangerously-skip-permissions when running as root.
# Solution: Creates a dedicated happy-user with a shared group so both root and
#           happy-user can read/write project files. A wrapper script makes 'happy'
#           just work transparently.
#
# Usage: sudo bash setup-vps.sh

set -euo pipefail

PROJECTS_DIR="/root/projects"
HAPPY_USER="happy-user"
SHARED_GROUP="projects"

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: Run as root."
    exit 1
fi

# 1. Create shared group
if getent group "$SHARED_GROUP" &>/dev/null; then
    echo "[ok] Group '$SHARED_GROUP' already exists"
else
    groupadd "$SHARED_GROUP"
    echo "[ok] Created group '$SHARED_GROUP'"
fi

# 2. Create user
if id "$HAPPY_USER" &>/dev/null; then
    echo "[ok] User '$HAPPY_USER' already exists"
else
    useradd -m -s /bin/bash "$HAPPY_USER"
    echo "[ok] Created user '$HAPPY_USER'"
fi

# 3. Add both users to the group
usermod -aG "$SHARED_GROUP" root
usermod -aG "$SHARED_GROUP" "$HAPPY_USER"
echo "[ok] Added root and $HAPPY_USER to '$SHARED_GROUP' group"

# 4. Install happy
sudo -u "$HAPPY_USER" npm install -g happy
echo "[ok] happy installed"

# 5. Find the real binary
REAL_HAPPY=$(sudo -u "$HAPPY_USER" bash -c 'which happy')
echo "[ok] Found happy at: $REAL_HAPPY"

# 6. Set group ownership + sticky group bit on projects
chgrp -R "$SHARED_GROUP" "$PROJECTS_DIR"
chmod -R g+rwX "$PROJECTS_DIR"
find "$PROJECTS_DIR" -type d -exec chmod g+s {} +
echo "[ok] Set shared group permissions on $PROJECTS_DIR"

# 7. Create wrapper
cat > /usr/local/bin/happy << EOF
#!/bin/bash
exec sudo -u $HAPPY_USER $REAL_HAPPY "\$@"
EOF
chmod +x /usr/local/bin/happy
echo "[ok] Created wrapper at /usr/local/bin/happy"

# 8. Systemd service
cat > /etc/systemd/system/happy-daemon.service << EOF
[Unit]
Description=Happy Daemon
After=network.target

[Service]
Type=simple
User=$HAPPY_USER
ExecStart=$REAL_HAPPY daemon start-sync
Restart=on-failure
RestartSec=5
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now happy-daemon
echo "[ok] Daemon running and enabled on boot"

echo ""
echo "=== Done ==="
echo "Just type 'happy' - it works now."
echo "Both root and $HAPPY_USER can read/write $PROJECTS_DIR"
