FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PORT=6969

# ── Alapcsomagok ──
RUN apt-get update && apt-get install -y \
    dropbear \
    openssh-sftp-server \
    nginx \
    neofetch \
    curl \
    wget \
    nano \
    vim \
    git \
    htop \
    sudo \
    supervisor \
    net-tools \
    python3 \
    python3-pip \
    nodejs \
    npm \
    unzip \
    zip \
    tmux \
    screen \
    jq \
    ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── ttyd (web terminál) ──
RUN curl -fsSL https://github.com/tsl0922/ttyd/releases/download/1.7.4/ttyd.x86_64 \
    -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd

# ── Cloudflared (Cloudflare Tunnel) ──
RUN curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
    -o /usr/local/bin/cloudflared && chmod +x /usr/local/bin/cloudflared

# ── Dropbear SSH kulcsok ──
RUN rm -f /etc/dropbear/dropbear_rsa_host_key \
          /etc/dropbear/dropbear_ecdsa_host_key \
          /etc/dropbear/dropbear_ed25519_host_key && \
    mkdir -p /etc/dropbear && \
    dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key && \
    dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key && \
    dropbearkey -t ed25519 -f /etc/dropbear/dropbear_ed25519_host_key

# ── Felhasználók (jelszó: 2003) ──
RUN echo 'root:2003' | chpasswd && \
    useradd -m -s /bin/bash admin && \
    echo 'admin:2003' | chpasswd && \
    usermod -aG sudo admin && \
    echo 'admin ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# ── Shell beállítás ──
RUN cat > /root/.bashrc << 'BASHRC'
export PS1='\[\033[01;32m\]\u@linux-server\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
alias ls='ls --color=auto'
alias ll='ls -lah'
alias cls='clear'
alias neo='neofetch'
alias info='clear && neofetch && echo "" && cat /var/www/html/info.txt'
alias cleanup='bash /usr/local/bin/cleanup.sh'
alias mem='free -h && df -h /'

if [ -t 1 ] && [ ! -f /tmp/.neofetch_shown ]; then
    touch /tmp/.neofetch_shown
    clear
    neofetch 2>/dev/null
    echo ""
    echo "════════════════════════════════════════════════"
    echo "  ✅ SSH: ssh.szaby.cloudflareaccess.com"
    echo "  🔑 Jelszó: 2003"
    echo "  📡 Info: info"
    echo "  🧹 Cleanup: cleanup"
    echo "  📊 Memória: mem"
    echo "════════════════════════════════════════════════"
    echo ""
fi
BASHRC

RUN cp /root/.bashrc /home/admin/.bashrc && \
    chown admin:admin /home/admin/.bashrc

# ── Cleanup script ──
RUN cat > /usr/local/bin/cleanup.sh << 'CLEANUP'
#!/bin/bash
echo "════════════════════════════════════════"
echo "  🧹 MEMÓRIA TISZTÍTÁS"
echo "════════════════════════════════════════"

echo "📊 ELŐTTE:"
free -h | grep Mem
df -h / | grep -v Filesystem

echo ""
echo "🧹 Tisztítás folyamatban..."

apt-get clean 2>/dev/null || true
apt-get autoclean 2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true
journalctl --vacuum-size=50M 2>/dev/null || true
journalctl --vacuum-time=2d 2>/dev/null || true
find /tmp -type f -mtime +1 -delete 2>/dev/null || true
find /var/tmp -type f -mtime +1 -delete 2>/dev/null || true
find /root -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
find /home -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
pip3 cache purge 2>/dev/null || true
npm cache clean --force 2>/dev/null || true
find /var/log -type f -name "*.log.*" -delete 2>/dev/null || true
find /var/log -type f -name "*.gz" -delete 2>/dev/null || true
find /var/log -type f -size +50M -exec truncate -s 10M {} \; 2>/dev/null || true
truncate -s 0 /var/log/supervisord.log 2>/dev/null || true

echo ""
echo "✅ KÉSZ!"
echo ""
echo "📊 UTÁNA:"
free -h | grep Mem
df -h / | grep -v Filesystem
echo ""
echo "════════════════════════════════════════"
CLEANUP

RUN chmod +x /usr/local/bin/cleanup.sh

# ── Munkamappák ──
RUN mkdir -p /var/www/html /root/projects /home/admin/projects && \
    chown -R admin:admin /home/admin

# ── Weboldal ──
RUN cat > /var/www/html/index.html << 'HTML'
<!DOCTYPE html>
<html lang="hu">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🐧 Linux Server</title>
    <style>
        *{margin:0;padding:0;box-sizing:border-box}
        body{background:#0d1117;color:#c9d1d9;font-family:-apple-system,sans-serif;padding:20px}
        .wrap{max-width:1100px;margin:0 auto}
        h1{color:#58a6ff;text-align:center;font-size:2.5em;margin-bottom:25px}
        .hero{background:#0d2818;border:1px solid #238636;padding:20px;border-radius:10px;text-align:center;margin-bottom:20px}
        .hero h2{color:#7ee787;margin-bottom:10px}
        .hero p{color:#8b949e;font-size:14px}
        .ssh-box{background:#161b22;border:1px solid #30363d;border-radius:10px;padding:20px;margin-bottom:20px}
        .ssh-box h3{color:#58a6ff;margin-bottom:15px}
        .ssh-code{background:#0d1117;padding:15px;border-radius:6px;font-family:'Courier New',monospace;color:#7ee787;margin-bottom:10px}
        .row{display:grid;grid-template-columns:1fr 1fr;gap:15px;margin-bottom:15px}
        .card{background:#161b22;border:1px solid #30363d;border-radius:10px;padding:20px}
        .card h2{color:#7ee787;margin-bottom:12px;font-size:1.2em}
        .full{grid-column:1/-1}
        pre{background:#0d1117;padding:15px;border-radius:6px;color:#7ee787;
            font-family:'Courier New',monospace;font-size:13px;line-height:1.6;
            white-space:pre-wrap;overflow-x:auto}
        .btn{display:block;text-align:center;padding:14px;background:#238636;
            color:#fff;text-decoration:none;border-radius:8px;font-size:16px;
            font-weight:600;margin-top:10px;transition:background .2s}
        .btn:hover{background:#2ea043}
        .info{color:#8b949e;font-size:13px;margin-top:8px}
        @media(max-width:768px){.row{grid-template-columns:1fr}}
    </style>
</head>
<body>
<div class="wrap">
    <h1>🐧 Linux Server</h1>
    
    <div class="hero">
        <h2>⚡ Cloudflare Tunnel Aktív</h2>
        <p>Fix SSH cím • Sosem változik • Automatikus cleanup</p>
    </div>

    <div class="ssh-box">
        <h3>🔐 SSH Csatlakozás (FIX CÍM!)</h3>
        <div class="ssh-code">ssh root@ssh.szaby.cloudflareaccess.com</div>
        <div class="ssh-code">Jelszó: 2003</div>
        <p class="info">✅ Ez a cím SOSEM változik! Deploy után is ugyanez!</p>
    </div>

    <div class="row">
        <div class="card">
            <h2>📂 FileZilla (SFTP)</h2>
            <pre>Protocol: SFTP
Host: ssh.szaby.cloudflareaccess.com
Port: 22
User: root
Pass: 2003

Mappa: /var/www/html/</pre>
        </div>
        <div class="card">
            <h2>💻 PuTTY</h2>
            <pre>Host: ssh.szaby.cloudflareaccess.com
Port: 22
Connection: SSH
User: root
Pass: 2003</pre>
        </div>
    </div>

    <div class="row">
        <div class="card full">
            <h2>🖥️ Web Terminál</h2>
            <a href="/terminal" class="btn" target="_blank">Terminál megnyitása új ablakban</a>
            <p class="info">Teljes Linux shell - nem kell semmi telepíteni!</p>
        </div>
    </div>

    <div class="row">
        <div class="card full">
            <h2>🖥️ Beágyazott Terminál</h2>
            <div style="background:#000;border-radius:8px;overflow:hidden;height:500px">
                <iframe src="/terminal" style="width:100%;height:100%;border:none"></iframe>
            </div>
        </div>
    </div>

    <div class="row">
        <div class="card full">
            <h2>📚 Hasznos parancsok</h2>
            <pre>neo               # Neofetch (rendszer info)
info              # Neofetch + SSH info
mem               # Memória állapot
cleanup           # Memória tisztítás
htop              # Folyamatok
cd /var/www/html  # Weboldal mappa
nano index.html   # Szerkesztés
ll                # Fájlok listázása

# Cloudflare tunnel státusz:
supervisorctl status cloudflared</pre>
        </div>
    </div>
</div>
</body>
</html>
HTML

# ── Info fájl ──
RUN cat > /var/www/html/info.txt << 'INFO'
════════════════════════════════════════════════
         🐧 SSH SERVER INFORMÁCIÓ
════════════════════════════════════════════════

SSH: ssh root@ssh.szaby.cloudflareaccess.com
Jelszó: 2003

FileZilla (SFTP):
  Host: ssh.szaby.cloudflareaccess.com
  Port: 22
  User: root
  Pass: 2003

✅ Fix cím - SOSEM változik!
✅ Cloudflare Tunnel
✅ Automatikus cleanup

════════════════════════════════════════════════
INFO

# ── Nginx ──
RUN cat > /etc/nginx/sites-available/default << 'NGINX'
server {
    listen 6969 default_server;
    server_name _;
    root /var/www/html;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location /terminal {
        proxy_pass http://127.0.0.1:7681;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_buffering off;
        proxy_cache off;
    }

    location /info.txt {
        default_type text/plain;
        add_header Cache-Control "no-cache";
    }
}
NGINX

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 6969
CMD ["/start.sh"]
