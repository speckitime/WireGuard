# Installations-Hinweise

## Wichtige Änderungen im install.sh (v2.0)

### ✅ Behobene Probleme

1. **GPG-Fehler behoben**
   - Alle benötigten Tools (gnupg, curl, wget, git) werden im ersten Schritt installiert

2. **Ubuntu 24.04 (Noble) Unterstützung**
   - MongoDB-Installation funktioniert jetzt auch auf Ubuntu 24.04
   - Verwendet automatisch das jammy-Repository für noble

3. **SSL-Frage erscheint jetzt**
   - SSL/HTTPS und Firewall-Konfiguration werden am Anfang abgefragt
   - Keine Unterbrechung während der Installation mehr

### 📋 Installations-Reihenfolge

```
1. Konfigurationsfragen (alle am Anfang):
   - Server IP
   - Domain
   - Ports
   - SSL/HTTPS (y/n)
   - Firewall (y/n)

2. Installation:
   - System-Update
   - WireGuard
   - MongoDB
   - Python 3.11
   - Node.js/Yarn
   - Supervisor/Nginx
   - Projekt klonen
   - Backend setup
   - Frontend build
   - Services konfigurieren
   - Firewall (falls gewählt)
   - SSL (falls gewählt)
```

### 🔐 SSL/HTTPS Setup

**Während der Installation:**
- Bei "SSL/HTTPS mit Let's Encrypt einrichten?" → **y** eingeben
- E-Mail-Adresse für Let's Encrypt angeben
- Certbot richtet automatisch alles ein

**Voraussetzungen für SSL:**
1. Domain muss auf Server-IP zeigen
2. Port 80 muss offen sein
3. Domain darf nicht von anderer Website verwendet werden

**DNS-Test vor Installation:**
```bash
nslookup vpn-dus.leonboldt.de
# Sollte 43.251.160.244 zurückgeben
```

### 🐛 Troubleshooting

**Problem: MongoDB startet nicht**
```bash
# MongoDB manuell starten
sudo systemctl start mongod
sudo systemctl status mongod
```

**Problem: Certbot schlägt fehl**
```bash
# DNS überprüfen
dig vpn-dus.leonboldt.de +short

# Port 80 freigeben
sudo ufw allow 80/tcp

# Manuell versuchen
sudo certbot --nginx -d vpn-dus.leonboldt.de
```

**Problem: Frontend zeigt Fehler**
```bash
# Nginx-Logs prüfen
sudo tail -f /var/log/nginx/error.log

# Backend-Status prüfen
sudo supervisorctl status wireguard-backend

# Backend-Logs prüfen
sudo tail -f /var/log/wireguard-backend-error.log
```

### 📊 Unterstützte Ubuntu-Versionen

✅ Ubuntu 20.04 LTS (Focal)
✅ Ubuntu 22.04 LTS (Jammy)
✅ Ubuntu 24.04 LTS (Noble)

### 🚀 Nach der Installation

1. Panel aufrufen: `http://vpn-dus.leonboldt.de` (oder HTTPS falls konfiguriert)
2. Account erstellen (erste Registrierung)
3. Server initialisieren
4. Server starten
5. Clients hinzufügen

### 📝 Wichtige Dateien

```
/opt/wireguard-admin/               - Installation
/opt/wireguard-admin/backend/.env   - Backend-Konfiguration
/opt/wireguard-admin/frontend/.env  - Frontend-Konfiguration
/etc/wireguard/wg0.conf            - WireGuard Server-Config
/etc/nginx/sites-available/wireguard-admin  - Nginx-Config
/etc/supervisor/conf.d/wireguard-backend.conf  - Supervisor-Config
/var/log/wireguard-backend.log     - Backend-Logs
/var/log/nginx/error.log           - Nginx-Logs
```

### 🔄 Services verwalten

```bash
# Backend
sudo supervisorctl status wireguard-backend
sudo supervisorctl restart wireguard-backend
sudo supervisorctl stop wireguard-backend
sudo supervisorctl start wireguard-backend

# Nginx
sudo systemctl status nginx
sudo systemctl restart nginx

# MongoDB
sudo systemctl status mongod
sudo systemctl restart mongod

# WireGuard
sudo wg show
sudo wg-quick up wg0
sudo wg-quick down wg0
```

### 🛡️ Firewall-Ports

```
22/tcp   - SSH
80/tcp   - HTTP (für Let's Encrypt & HTTP-Zugriff)
443/tcp  - HTTPS (für sicheren Zugriff)
51820/udp - WireGuard VPN
8001/tcp - Backend API (nur intern, nicht öffentlich)
```

### 📧 SSL-Zertifikat erneuern

```bash
# Automatische Erneuerung ist aktiviert
sudo systemctl status certbot.timer

# Manuell erneuern
sudo certbot renew

# Test-Erneuerung (ohne tatsächlich zu erneuern)
sudo certbot renew --dry-run
```

### ⚡ Performance-Tipps

1. **MongoDB Optimierung**
   ```bash
   # MongoDB-Speicher begrenzen (optional)
   sudo nano /etc/mongod.conf
   # Fügen Sie hinzu:
   # storage:
   #   wiredTiger:
   #     engineConfig:
   #       cacheSizeGB: 1
   ```

2. **Nginx Caching** (optional)
   - Kann in `/etc/nginx/sites-available/wireguard-admin` konfiguriert werden

3. **Logs rotieren**
   ```bash
   # Logs automatisch rotieren
   sudo nano /etc/logrotate.d/wireguard-admin
   ```

### 🔒 Sicherheits-Checkliste

- [ ] SSL/HTTPS aktiviert
- [ ] Firewall konfiguriert
- [ ] Starke Admin-Passwörter verwendet
- [ ] SSH-Key-Authentifizierung aktiviert
- [ ] Automatische Updates konfiguriert
- [ ] Backups eingerichtet
- [ ] Fail2ban installiert (optional)

### 📞 Support

- GitHub Issues: https://github.com/speckitime/WireGuard/issues
- Dokumentation: README.md, QUICKSTART.md, HTTPS_SETUP.md
