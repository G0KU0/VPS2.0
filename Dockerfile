FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PORT=6969
ENV BORE_PORT=48251

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

# ── Bore tunnel ──
RUN curl -fsSL \
    https://github.com/ekzhang/bore/releases/download/v0.5.1/bore-v0.5.1-x86_64-unknown-linux-musl.tar.gz \
    | tar xz -C /usr/local/bin/ && chmod +x /usr/local/bin/bore || true

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
export PS1='\[\033[01;32m\]\u@Szaby\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
alias ls='ls --color=auto'
alias ll='ls -lah'
alias cls='clear'
alias neo='neofetch'
alias info='clear && neofetch && echo "" && cat /var/www/html/sftp.txt'
alias cleanup='bash /usr/local/bin/cleanup.sh'
alias mem='free -h && echo "" && df -h /'

if [ -t 1 ] && [ ! -f /tmp/.neofetch_shown ]; then
    touch /tmp/.neofetch_shown
    clear
    neofetch 2>/dev/null
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  ✅ Szerver fut! (Keep-Alive aktív)"
    echo "  🔑 Jelszó: 2003"
    echo "  📂 Weboldal: /var/www/html/"
    echo "  📡 SFTP info: cat /var/www/html/sftp.txt"
    echo "  🖥️  Neofetch újra: neo"
    echo "  🧹 Memória tisztítás: cleanup"
    echo "  📊 Memória állapot: mem"
    echo "═══════════════════════════════════════════════"
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

echo "  [1/7] Apt cache..."
apt-get clean 2>/dev/null || true
apt-get autoclean 2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true

echo "  [2/7] Systemd journal..."
journalctl --vacuum-size=50M 2>/dev/null || true
journalctl --vacuum-time=2d 2>/dev/null || true

echo "  [3/7] Tmp fájlok..."
find /tmp -type f -mtime +1 -delete 2>/dev/null || true
find /var/tmp -type f -mtime +1 -delete 2>/dev/null || true

echo "  [4/7] Python cache..."
find /root -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
find /home -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
pip3 cache purge 2>/dev/null || true

echo "  [5/7] NPM cache..."
npm cache clean --force 2>/dev/null || true

echo "  [6/7] Régi logok..."
find /var/log -type f -name "*.log.*" -delete 2>/dev/null || true
find /var/log -type f -name "*.gz" -delete 2>/dev/null || true
find /var/log -type f -size +50M -exec truncate -s 10M {} \; 2>/dev/null || true

echo "  [7/7] Supervisor logok..."
truncate -s 0 /var/log/supervisord.log 2>/dev/null || true
truncate -s 0 /var/log/bore.log 2>/dev/null || true
truncate -s 0 /var/log/keepalive.log 2>/dev/null || true

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
        .btn-red{background:#da3633}
        .btn-red:hover{background:#f85149}
        .status{text-align:center;padding:15px;border-radius:8px;font-size:1.2em;
            font-weight:bold;margin-bottom:15px}
        .active{background:#0d2818;border:1px solid #238636;color:#7ee787}
        .loading{background:#1c1e26;border:1px solid #ffa657;color:#ffa657}
        .keepalive{background:#0d2818;border:1px solid #238636;padding:15px;border-radius:8px;text-align:center;margin-bottom:15px}
        .keepalive h3{color:#7ee787;margin-bottom:5px}
        .keepalive p{color:#8b949e;font-size:13px}
        .info{color:#8b949e;font-size:13px;margin-top:8px}
        @media(max-width:768px){.row{grid-template-columns:1fr}}
    </style>
</head>
<body>
<div class="wrap">
    <h1>🐧 Linux Server</h1>

    <div class="keepalive">
        <h3>⚡ Keep-Alive AKTÍV</h3>
        <p>Szerver 24/7 fut • Adatok megmaradnak • Automatikus memória tisztítás</p>
    </div>

    <div class="status" id="status"><span class="loading">🔄 Betöltés...</span></div>

    <div class="row">
        <div class="card">
            <h2>🔐 SSH Csatlakozás</h2>
            <pre id="ssh-info">Betöltés...</pre>
        </div>
        <div class="card">
            <h2>📂 FileZilla (SFTP)</h2>
            <pre id="sftp-info">Betöltés...</pre>
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
info              # Neofetch + SFTP info
mem               # Memória állapot
cleanup           # Memória tisztítás
htop              # Folyamatok
cd /var/www/html  # Weboldal mappa
nano index.html   # Szerkesztés
ll                # Fájlok listázása

# Keep-Alive log:
tail -f /var/log/keepalive.log

# Cleanup log:
tail -f /var/log/cleanup.log</pre>
        </div>
    </div>
</div>

<script>
function load(){
    fetch('/sftp.txt').then(r=>r.text()).then(t=>{
        if(t.includes('AKTIV')){
            document.getElementById('status').innerHTML='<span class="active">✅ Szerver aktív!</span>';
            var lines=t.split('\n');
            var host='',port='';
            lines.forEach(l=>{
                if(l.includes('Host:'))host=l.split('Host:')[1].trim();
                if(l.includes('Port:')&&!l.includes('Protocol'))port=l.split('Port:')[1].trim();
            });
            if(host&&port){
                document.getElementById('ssh-info').textContent=
                    'SSH parancs:\n  ssh root@'+host+' -p '+port+'\n\nJelszó: 2003\n\nPuTTY:\n  Host: '+host+'\n  Port: '+port+'\n  User: root\n  Pass: 2003';
                document.getElementById('sftp-info').textContent=
                    'Protocol: SFTP\nHost: '+host+'\nPort: '+port+'\nUser: root\nPass: 2003\n\nMappa: /var/www/html/';
            }
        } else {
            document.getElementById('status').innerHTML='<span class="loading">⏳ Tunnel indítása...</span>';
            document.getElementById('ssh-info').textContent=t;
            document.getElementById('sftp-info').textContent=t;
        }
    }).catch(()=>{});
}
load();setInterval(load,3000);
</script>
</body>
</html>
HTML

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

    location /sftp.txt {
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
