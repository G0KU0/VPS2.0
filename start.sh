#!/bin/bash
set -e

echo "════════════════════════════════════════"
echo "  🐧 Linux Server + Keep Alive"
echo "  🔑 Jelszó: 2003"
echo "════════════════════════════════════════"

# ── Jelszavak ──
echo 'root:2003' | chpasswd
echo 'admin:2003' | chpasswd
echo "[OK] Jelszó: 2003"

# ── SFTP info ──
cat > /var/www/html/sftp.txt << 'EOF'
Tunnel indítása...
Várj 15 másodpercet!
Jelszó: 2003
EOF

# ── Keep-Alive script (5 percenként pingeli önmagát) ──
cat > /usr/local/bin/keep-alive.sh << 'KEEPALIVE'
#!/bin/bash

RENDER_URL="${RENDER_EXTERNAL_URL:-}"

echo "[KEEP-ALIVE] Indítás..."
echo "[KEEP-ALIVE] URL: $RENDER_URL"

while true; do
    sleep 300  # 5 perc
    
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[KEEP-ALIVE] Ping: $TIMESTAMP"
    
    # Külső URL pingelése (ha van)
    if [ -n "$RENDER_URL" ]; then
        curl -s -o /dev/null -w "External: %{http_code}\n" "$RENDER_URL" 2>/dev/null || true
    fi
    
    # Belső port pingelése
    curl -s -o /dev/null "http://127.0.0.1:6969" 2>/dev/null || true
    
    echo "[KEEP-ALIVE] OK"
done
KEEPALIVE

chmod +x /usr/local/bin/keep-alive.sh

# ── SFTP frissítő ──
cat > /usr/local/bin/update-sftp.sh << 'SCRIPT'
#!/bin/bash
while sleep 5; do
    if [ -f /var/log/bore.log ]; then
        ADDR=$(grep -oE 'bore\.pub:[0-9]+' /var/log/bore.log 2>/dev/null | tail -1)
        if [ -n "$ADDR" ]; then
            HOST=$(echo "$ADDR" | cut -d: -f1)
            PORT=$(echo "$ADDR" | cut -d: -f2)
            cat > /var/www/html/sftp.txt << EOF
AKTIV

SSH: ssh root@${HOST} -p ${PORT}
Jelszó: 2003

FileZilla (SFTP):
  Protocol: SFTP
  Host: ${HOST}
  Port: ${PORT}
  User: root
  Pass: 2003

✅ Keep-Alive AKTÍV
   Szerver 24/7 fut!
   Adatok megmaradnak!

Frissítve: $(date '+%H:%M:%S')
EOF
        fi
    fi
done
SCRIPT

chmod +x /usr/local/bin/update-sftp.sh

echo "[INFO] Supervisord indítása..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
