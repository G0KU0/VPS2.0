#!/bin/bash
set -e

echo "════════════════════════════════════════"
echo "  🐧 Linux Server + Playit.gg"
echo "  🔑 Jelszó: 2003"
echo "════════════════════════════════════════"

echo 'root:2003' | chpasswd
echo 'admin:2003' | chpasswd

# Eredeti Keep-Alive script
cat > /usr/local/bin/keep-alive.sh << 'KEEPALIVE'
#!/bin/bash
while true; do
    sleep 300
    curl -s -o /dev/null "http://127.0.0.1:6969" 2>/dev/null || true
done
KEEPALIVE
chmod +x /usr/local/bin/keep-alive.sh

# SFTP frissítő (Módosítva Playit-hez)
cat > /usr/local/bin/update-sftp.sh << 'SCRIPT'
#!/bin/bash
while sleep 10; do
    cat > /var/www/html/sftp.txt << EOF
AKTÍV (Playit.gg)

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

# Eredeti Auto cleanup
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

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
