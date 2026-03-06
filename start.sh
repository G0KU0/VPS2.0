#!/bin/bash
set -e

echo "════════════════════════════════════════"
echo "  🐧 Linux Server + Cloudflare Tunnel"
echo "  🔑 Jelszó: 2003"
echo "════════════════════════════════════════"

# ── Jelszavak ──
echo 'root:2003' | chpasswd
echo 'admin:2003' | chpasswd
echo "[OK] Jelszó: 2003"

# ── Indításkori cleanup ──
echo "[INFO] Indításkori memória tisztítás..."
apt-get clean 2>/dev/null || true
journalctl --vacuum-size=50M 2>/dev/null || true
find /tmp -type f -mtime +1 -delete 2>/dev/null || true
pip3 cache purge 2>/dev/null || true
echo "[OK] Cleanup kész"

# ── Keep-Alive script ──
cat > /usr/local/bin/keep-alive.sh << 'KEEPALIVE'
#!/bin/bash
RENDER_URL="${RENDER_EXTERNAL_URL:-}"
echo "[KEEP-ALIVE] Indítás..."
while true; do
    sleep 300
    echo "[KEEP-ALIVE] Ping: $(date '+%H:%M:%S')"
    if [ -n "$RENDER_URL" ]; then
        curl -s -o /dev/null "$RENDER_URL" 2>/dev/null || true
    fi
    curl -s -o /dev/null "http://127.0.0.1:6969" 2>/dev/null || true
done
KEEPALIVE

chmod +x /usr/local/bin/keep-alive.sh

# ── Auto cleanup (naponta 3 órakor) ──
cat > /usr/local/bin/auto-cleanup.sh << 'AUTOCLEAN'
#!/bin/bash
while true; do
    CURRENT_HOUR=$(date +%H)
    if [ "$CURRENT_HOUR" -eq 3 ]; then
        echo "[AUTO-CLEANUP] $(date) - Cleanup indítása..."
        /usr/local/bin/cleanup.sh >> /var/log/cleanup.log 2>&1
        echo "[AUTO-CLEANUP] Kész!"
        sleep 3600
    fi
    sleep 300
done
AUTOCLEAN

chmod +x /usr/local/bin/auto-cleanup.sh

echo "[INFO] Supervisord indítása..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
