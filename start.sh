#!/bin/bash
set -e

echo "════════════════════════════════════════"
echo "  🐧 Linux Server + Playit.gg"
echo "  🔑 Jelszó: 2003"
echo "════════════════════════════════════════"

# ── Jelszavak ──
echo 'root:2003' | chpasswd
echo 'admin:2003' | chpasswd
echo "[OK] Jelszó: 2003"

# ── Indításkori cleanup ──
apt-get clean 2>/dev/null || true
journalctl --vacuum-size=50M 2>/dev/null || true
find /tmp -type f -mtime +1 -delete 2>/dev/null || true

# ── Keep-Alive script (5 percenként) ──
cat > /usr/local/bin/keep-alive.sh << 'KEEPALIVE'
#!/bin/bash
RENDER_URL="${RENDER_EXTERNAL_URL:-}"
while true; do
    sleep 300
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[KEEP-ALIVE] Ping: $TIMESTAMP"
    if [ -n "$RENDER_URL" ]; then
        curl -s -o /dev/null "$RENDER_URL" 2>/dev/null || true
    fi
    curl -s -o /dev/null "http://127.0.0.1:6969" 2>/dev/null || true
done
KEEPALIVE
chmod +x /usr/local/bin/keep-alive.sh

# ── SFTP frissítő (Fix Playit.gg eléréshez) ──
cat > /usr/local/bin/update-sftp.sh << 'SCRIPT'
#!/bin/bash
while sleep 10; do
    cat > /var/www/html/sftp.txt << EOF
AKTÍV (Playit.gg Tunnel)

A fix címedet a playit.gg oldalon találod 
a regisztrált Tunnel alatt!

Példa: ssh root@valami.ply.gg -p 12345
Jelszó: 2003

✅ Keep-Alive AKTÍV
Frissítve: $(date '+%H:%M:%S')
EOF
done
SCRIPT
chmod +x /usr/local/bin/update-sftp.sh

# ── Auto cleanup (naponta 3 órakor) ──
cat > /usr/local/bin/auto-cleanup.sh << 'AUTOCLEAN'
#!/bin/bash
while true; do
    if [ "$(date +%H)" -eq "03" ]; then
        /usr/local/bin/cleanup.sh >> /var/log/cleanup.log 2>&1
        sleep 3600
    fi
    sleep 300
done
AUTOCLEAN
chmod +x /usr/local/bin/auto-cleanup.sh

echo "[INFO] Supervisord indítása..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
