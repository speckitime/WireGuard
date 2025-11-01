# WireGuard Admin Panel

Eine moderne Web-Administrationsoberfläche für WireGuard VPN-Server.

## Features

- 🔐 Sichere JWT-Authentifizierung
- 🖥️ WireGuard Server Management (Start/Stop/Restart)
- 👥 Client-Profil-Verwaltung
- 📊 Echtzeit-Statistiken (aktive Verbindungen, Traffic)
- 📱 QR-Code-Generierung für mobile Clients
- 💾 Download von .conf Dateien
- 🔄 Automatische Updates alle 5 Sekunden
- 🌐 Lokale und Remote-SSH-Verwaltung

## Systemanforderungen

- Ubuntu 20.04 LTS oder neuer
- Python 3.11+
- Node.js 18+ und Yarn
- MongoDB
- WireGuard
- Sudo-Berechtigungen

## Schnellinstallation (Empfohlen)

Die einfachste Methode zur Installation:

```bash
# Repository klonen
git clone https://github.com/speckitime/WireGuard.git
cd WireGuard

# Installationsskript ausführen
sudo chmod +x install.sh
sudo ./install.sh
```

### Bei Problemen nach der Installation

Falls Probleme auftreten, verwenden Sie das Hilfs-Tool:

```bash
# Interaktives Hilfs-Tool starten
sudo ./helpscript.sh
```

**Das Hilfs-Tool bietet:**
- ✅ Vollständige Diagnose aller Services
- ✅ Backend-Reparatur
- ✅ HTTPS-Konfiguration prüfen/reparieren
- ✅ Frontend-URL korrigieren
- ✅ Logs anzeigen
- ✅ Services neu starten
- ✅ Cleanup für Neuinstallation

### Bei fehlgeschlagener Installation

Falls eine vorherige Installation fehlgeschlagen ist:

```bash
# Cleanup ausführen
sudo ./cleanup.sh

# Dann Neuinstallation
sudo ./install.sh
```

Das Skript führt Sie durch die Installation und fragt nach wichtigen Konfigurationsparametern:
- Server IP-Adresse / Domain
- WireGuard Port (Standard: 51820)
- Installationsverzeichnis
- Firewall-Setup
- **SSL/HTTPS-Setup mit Let's Encrypt (optional)**

Nach der Installation ist das Panel sofort unter `http://IHRE-SERVER-IP` verfügbar!

> 📘 **HTTPS einrichten**: Siehe [HTTPS_SETUP.md](HTTPS_SETUP.md) für detaillierte SSL-Anweisungen

---

## Manuelle Installation auf Ubuntu Server

Falls Sie die Installation manuell durchführen möchten:

### 1. System-Pakete installieren

```bash
# System aktualisieren
sudo apt update && sudo apt upgrade -y

# WireGuard installieren
sudo apt install -y wireguard wireguard-tools

# MongoDB installieren
curl -fsSL https://pgp.mongodb.com/server-7.0.asc | sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo apt update
sudo apt install -y mongodb-org
sudo systemctl start mongod
sudo systemctl enable mongod

# Python 3.11 und pip installieren (falls nicht vorhanden)
sudo apt install -y python3.11 python3.11-venv python3-pip

# Node.js und Yarn installieren
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
npm install -g yarn

# Supervisor installieren (für Prozessverwaltung)
sudo apt install -y supervisor
```

### 2. IP-Forwarding aktivieren

```bash
# IP-Forwarding dauerhaft aktivieren
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### 3. Projekt klonen und einrichten

```bash
# Projekt klonen (oder hochladen)
git clone <repository-url> /opt/wireguard-admin
cd /opt/wireguard-admin

# Python Virtual Environment erstellen
python3.11 -m venv venv
source venv/bin/activate

# Backend-Abhängigkeiten installieren
cd backend
pip install -r requirements.txt
cd ..

# Frontend-Abhängigkeiten installieren
cd frontend
yarn install
cd ..
```

### 4. Umgebungsvariablen konfigurieren

#### Backend (.env)

```bash
cd /opt/wireguard-admin/backend
cat > .env << 'EOF'
MONGO_URL="mongodb://localhost:27017"
DB_NAME="wireguard_admin"
CORS_ORIGINS="*"
JWT_SECRET="CHANGE-THIS-TO-A-SECURE-RANDOM-STRING"

# Optional: SSH Remote-Verwaltung
# SSH_ENABLED=false
# SSH_HOST="43.251.160.244"
# SSH_PORT=22
# SSH_USER="root"
# SSH_KEY_PATH="/root/.ssh/id_rsa"
EOF
```

#### Frontend (.env)

```bash
cd /opt/wireguard-admin/frontend
cat > .env << 'EOF'
REACT_APP_BACKEND_URL=http://YOUR_SERVER_IP:8001
EOF
```

**Wichtig**: Ersetzen Sie `YOUR_SERVER_IP` mit Ihrer Server-IP oder Domain!

### 5. Sudo-Berechtigungen für WireGuard einrichten

Das Panel benötigt sudo-Rechte für WireGuard-Befehle:

```bash
# Sudoers-Datei erstellen
sudo visudo -f /etc/sudoers.d/wireguard-admin
```

Fügen Sie folgende Zeilen hinzu (ersetzen Sie `www-data` mit Ihrem Benutzer):

```
# WireGuard Admin Panel Berechtigungen
www-data ALL=(ALL) NOPASSWD: /usr/bin/wg
www-data ALL=(ALL) NOPASSWD: /usr/bin/wg-quick
www-data ALL=(ALL) NOPASSWD: /bin/cp /tmp/wg0.conf /etc/wireguard/wg0.conf
www-data ALL=(ALL) NOPASSWD: /bin/cp /tmp/peer.conf /etc/wireguard/*
www-data ALL=(ALL) NOPASSWD: /bin/chmod 600 /etc/wireguard/*
www-data ALL=(ALL) NOPASSWD: /bin/bash -c cat /tmp/peer.conf >> /etc/wireguard/wg0.conf
```

Dateirechte setzen:

```bash
sudo chmod 440 /etc/sudoers.d/wireguard-admin
```

### 6. Frontend Build erstellen

```bash
cd /opt/wireguard-admin/frontend
yarn build
```

### 7. Supervisor konfigurieren

#### Backend-Service

```bash
sudo nano /etc/supervisor/conf.d/wireguard-backend.conf
```

Inhalt:

```ini
[program:wireguard-backend]
command=/opt/wireguard-admin/venv/bin/uvicorn server:app --host 0.0.0.0 --port 8001
directory=/opt/wireguard-admin/backend
autostart=true
autorestart=true
user=www-data
stdout_logfile=/var/log/wireguard-backend.log
stderr_logfile=/var/log/wireguard-backend-error.log
environment=PATH="/opt/wireguard-admin/venv/bin"
```

#### Frontend-Service (mit nginx)

Installieren Sie nginx:

```bash
sudo apt install -y nginx
```

Nginx-Konfiguration:

```bash
sudo nano /etc/nginx/sites-available/wireguard-admin
```

Inhalt:

```nginx
server {
    listen 80;
    server_name YOUR_DOMAIN_OR_IP;

    # Frontend
    root /opt/wireguard-admin/frontend/build;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Backend API Proxy
    location /api {
        proxy_pass http://localhost:8001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

Aktivieren:

```bash
sudo ln -s /etc/nginx/sites-available/wireguard-admin /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### 8. Services starten

```bash
# Supervisor neu laden
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start wireguard-backend

# Status prüfen
sudo supervisorctl status
```

### 9. Firewall konfigurieren (optional)

```bash
# UFW Firewall
sudo ufw allow 80/tcp      # HTTP für Admin-Panel
sudo ufw allow 443/tcp     # HTTPS (falls SSL konfiguriert)
sudo ufw allow 51820/udp   # WireGuard VPN
sudo ufw allow 22/tcp      # SSH
sudo ufw enable
```

## Erste Schritte

### 1. Panel aufrufen

Öffnen Sie `http://YOUR_SERVER_IP` in Ihrem Browser.

### 2. Konto erstellen

Beim ersten Aufruf können Sie sich registrieren.

### 3. Server initialisieren

Klicken Sie auf "Server initialisieren", um die WireGuard-Serverkonfiguration zu erstellen.

### 4. Server starten

Starten Sie den WireGuard-Server mit dem "Server starten" Button.

### 5. Clients hinzufügen

Erstellen Sie Client-Profile und laden Sie .conf-Dateien herunter oder scannen Sie QR-Codes.

## Server-Konfiguration

Die Standard-Konfiguration verwendet:

- **Netzwerk**: 10.8.0.0/24
- **Server-IP**: 10.8.0.1
- **Port**: 51820 (UDP)
- **DNS**: 1.1.1.1 (Cloudflare)

### Anpassungen

Passen Sie die Konfiguration in `/app/backend/server.py` an:

```python
SERVER_PUBLIC_IP = "43.251.160.244"         # Ihre öffentliche IP
SERVER_DOMAIN = "vpn-dus.leonboldt.de"      # Ihre Domain
SERVER_PORT = 51820                          # WireGuard Port
SERVER_NETWORK = "10.8.0.0/24"              # VPN-Netzwerk
SERVER_IP = "10.8.0.1"                      # Server VPN-IP
```

## SSH Remote-Verwaltung

Um WireGuard auf einem Remote-Server zu verwalten:

### 1. SSH-Key generieren

```bash
ssh-keygen -t rsa -b 4096 -f /root/.ssh/wireguard_admin
ssh-copy-id -i /root/.ssh/wireguard_admin.pub root@43.251.160.244
```

### 2. Backend .env anpassen

```bash
SSH_ENABLED=true
SSH_HOST=43.251.160.244
SSH_PORT=22
SSH_USER=root
SSH_KEY_PATH=/root/.ssh/wireguard_admin
```

### 3. Backend neu starten

```bash
sudo supervisorctl restart wireguard-backend
```

## Troubleshooting

### WireGuard-Befehle funktionieren nicht

```bash
# Sudo-Rechte testen
sudo -u www-data sudo wg show

# Logs prüfen
sudo tail -f /var/log/wireguard-backend-error.log
```

### Backend startet nicht

```bash
# Logs prüfen
sudo tail -f /var/log/supervisor/wireguard-backend-stderr*

# Python-Module testen
source /opt/wireguard-admin/venv/bin/activate
python -c "import fastapi, motor, qrcode; print('OK')"
```

### Frontend zeigt keine Daten

```bash
# Backend-Verbindung testen
curl http://localhost:8001/api/

# CORS-Probleme: .env überprüfen
cat /opt/wireguard-admin/backend/.env
```

### MongoDB-Verbindung fehlgeschlagen

```bash
# MongoDB-Status prüfen
sudo systemctl status mongod

# MongoDB starten
sudo systemctl start mongod
```

## Sicherheitshinweise

1. **JWT Secret ändern**: Setzen Sie ein starkes, zufälliges JWT_SECRET in der .env
2. **HTTPS verwenden**: Konfigurieren Sie SSL/TLS mit Let's Encrypt:
   ```bash
   sudo apt install -y certbot python3-certbot-nginx
   sudo certbot --nginx -d your-domain.com
   ```
3. **Firewall aktivieren**: Nur notwendige Ports öffnen
4. **Regelmäßige Updates**: System und Pakete aktuell halten
5. **Starke Passwörter**: Verwenden Sie sichere Passwörter für Admin-Konten
6. **Backup**: Regelmäßige Backups der MongoDB-Datenbank erstellen

## Backup & Restore

### Backup erstellen

```bash
# MongoDB Backup
mongodump --db wireguard_admin --out /backup/mongodb/$(date +%Y%m%d)

# WireGuard Konfiguration
sudo cp -r /etc/wireguard /backup/wireguard/$(date +%Y%m%d)
```

### Restore

```bash
# MongoDB Restore
mongorestore --db wireguard_admin /backup/mongodb/20250131/wireguard_admin

# WireGuard Konfiguration
sudo cp -r /backup/wireguard/20250131/* /etc/wireguard/
```

## API-Dokumentation

Die API-Dokumentation ist verfügbar unter:
- Swagger UI: `http://YOUR_SERVER_IP:8001/docs`
- ReDoc: `http://YOUR_SERVER_IP:8001/redoc`

## Support

Bei Fragen oder Problemen erstellen Sie bitte ein Issue im Repository.

## Lizenz

MIT License
