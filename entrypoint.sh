#!/bin/bash
set -e

# Set root password
echo "root:${OPENCODE_SSH_PASS:-opencode}" | chpasswd

# Auto-restart serve process if registry exists and has a server cmd
SERVE_JSON="/exchange/outbox/opencode/serve-process.json"
if [ -f "$SERVE_JSON" ]; then
  SERVE_CMD=$(node -e "
    try {
      const d = JSON.parse(require('fs').readFileSync('$SERVE_JSON','utf8'));
      if (d.server && d.server.cmd) console.log(d.server.cmd);
    } catch(e) {}
  " 2>/dev/null || true)
  if [ -n "$SERVE_CMD" ]; then
    bash -c "$SERVE_CMD" &
    SERVE_PID=$!
    echo "[start] serve process started (PID $SERVE_PID): $SERVE_CMD"
    node -e "
      const fs = require('fs');
      try {
        const d = JSON.parse(fs.readFileSync('$SERVE_JSON','utf8'));
        d.server.pid = $SERVE_PID;
        d.server.started_at = new Date().toISOString();
        fs.writeFileSync('$SERVE_JSON', JSON.stringify(d, null, 2));
      } catch(e) {}
    " 2>/dev/null || true
  fi
fi

exec /usr/sbin/sshd -D
