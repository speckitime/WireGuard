# WireGuard Admin Panel - Schnellstart-Anleitung

## Installation (Ein-Befehl-Setup)

```bash
wget -qO- https://raw.githubusercontent.com/speckitime/WireGuard/main/install.sh | sudo bash
```

Oder mit Git:

```bash
git clone https://github.com/speckitime/WireGuard.git
cd WireGuard
sudo ./install.sh
```

## Was wird installiert?

Das Installations-Skript führt automatisch folgende Schritte aus:

1. ✅ System-Update
2. ✅ WireGuard Installation
3. ✅ MongoDB Installation
4. ✅ Python 3.11 Installation
5. ✅ Node.js & Yarn Installation
6. ✅ Projekt-Setup
7. ✅ Backend-Konfiguration
8. ✅ Frontend-Build
9. ✅ Nginx & Supervisor Konfiguration
10. ✅ Firewall-Setup (optional)
11. ✅ SSL/HTTPS mit Let's Encrypt (optional)

## Nach der Installation

1. **Panel öffnen**: Navigieren Sie zu `http://IHRE-SERVER-IP`

2. **Admin-Account erstellen**: Registrieren Sie sich beim ersten Besuch

3. **Server initialisieren**: Klicken Sie auf "Server initialisieren"

4. **Server starten**: Klicken Sie auf "Server starten"

5. **Clients hinzufügen**: Erstellen Sie VPN-Profile für Ihre Geräte

## Wichtige Befehle

### Service-Verwaltung
```bash
# Backend-Status prüfen
sudo supervisorctl status wireguard-backend

# Backend neu starten
sudo supervisorctl restart wireguard-backend

# Nginx neu starten
sudo systemctl restart nginx
```

### Logs anzeigen
```bash
# Backend-Logs
sudo tail -f /var/log/wireguard-backend.log
sudo tail -f /var/log/wireguard-backend-error.log

# Nginx-Logs
sudo tail -f /var/log/nginx/error.log
```

### Konfiguration bearbeiten
```bash
# Backend-Konfiguration
sudo nano /opt/wireguard-admin/backend/.env

# Frontend-Konfiguration
sudo nano /opt/wireguard-admin/frontend/.env

# Nach Änderungen Services neu starten
sudo supervisorctl restart wireguard-backend
```

## Standard-Ports

- **Frontend (Web-UI)**: Port 80 (HTTP) / 443 (HTTPS)
- **Backend API**: Port 8001
- **WireGuard VPN**: Port 51820 (UDP)

## Firewall-Regeln

Falls Sie die Firewall manuell konfigurieren:

```bash
sudo ufw allow 22/tcp      # SSH
sudo ufw allow 80/tcp      # HTTP
sudo ufw allow 443/tcp     # HTTPS
sudo ufw allow 51820/udp   # WireGuard
sudo ufw enable
```

## SSL/HTTPS Setup

HTTPS mit Let's Encrypt einrichten:

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d ihre-domain.de
```

## Remote-SSH-Verwaltung

Um WireGuard auf einem anderen Server zu verwalten:

1. **SSH-Key generieren**:
   ```bash
   ssh-keygen -t rsa -b 4096 -f /root/.ssh/wireguard_admin
   ssh-copy-id -i /root/.ssh/wireguard_admin.pub root@REMOTE-SERVER-IP
   ```

2. **Backend .env anpassen**:
   ```bash
   sudo nano /opt/wireguard-admin/backend/.env
   ```
   
   Ändern Sie:
   ```
   SSH_ENABLED=true
   SSH_HOST=REMOTE-SERVER-IP
   SSH_PORT=22
   SSH_USER=root
   SSH_KEY_PATH=/root/.ssh/wireguard_admin
   ```

3. **Backend neu starten**:
   ```bash
   sudo supervisorctl restart wireguard-backend
   ```

## Troubleshooting

### Backend startet nicht
```bash
# Logs prüfen
sudo tail -n 50 /var/log/wireguard-backend-error.log

# Manuell testen
cd /opt/wireguard-admin/backend
source ../venv/bin/activate
python -m uvicorn server:app --host 0.0.0.0 --port 8001
```

### Frontend zeigt Fehler
```bash
# Nginx-Logs prüfen
sudo tail -n 50 /var/log/nginx/error.log

# Nginx-Konfiguration testen
sudo nginx -t

# Nginx neu starten
sudo systemctl restart nginx
```

### WireGuard-Befehle funktionieren nicht
```bash
# Sudo-Rechte testen
sudo -u www-data sudo wg show

# WireGuard Installation prüfen
which wg
which wg-quick
```

### MongoDB läuft nicht
```bash
# MongoDB-Status prüfen
sudo systemctl status mongod

# MongoDB starten
sudo systemctl start mongod
sudo systemctl enable mongod
```

## Deinstallation

```bash
# Services stoppen
sudo supervisorctl stop wireguard-backend
sudo systemctl stop nginx

# Konfigurationsdateien entfernen
sudo rm /etc/supervisor/conf.d/wireguard-backend.conf
sudo rm /etc/nginx/sites-enabled/wireguard-admin
sudo rm /etc/nginx/sites-available/wireguard-admin
sudo rm /etc/sudoers.d/wireguard-admin

# Installationsverzeichnis entfernen
sudo rm -rf /opt/wireguard-admin

# Services neu laden
sudo supervisorctl reread
sudo supervisorctl update
sudo systemctl restart nginx
```

## Backup erstellen

```bash
# MongoDB Backup
mongodump --db wireguard_admin --out /backup/mongodb-$(date +%Y%m%d)

# WireGuard Konfiguration
sudo cp -r /etc/wireguard /backup/wireguard-$(date +%Y%m%d)

# Umgebungsvariablen
sudo cp /opt/wireguard-admin/backend/.env /backup/backend-env-$(date +%Y%m%d)
```

## Support & Dokumentation

- 📚 **Vollständige Dokumentation**: Siehe [README.md](README.md)
- 🐛 **Probleme melden**: [GitHub Issues](https://github.com/speckitime/WireGuard/issues)
- 📝 **API-Dokumentation**: `http://IHRE-SERVER-IP:8001/docs`

## Lizenz

MIT License - Siehe LICENSE Datei für Details
