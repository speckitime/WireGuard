# Ubuntu 24.04 Spezifische Installations-Hinweise

## Unterschiede zu älteren Ubuntu-Versionen

Ubuntu 24.04 LTS (Noble Numbat) hat einige Änderungen, die das Installationsskript automatisch behandelt:

### 1. Python Version

**Ubuntu 24.04 Standard**: Python 3.12
**WireGuard Admin benötigt**: Python 3.11+

**Lösung**: Das Skript erkennt Python 3.12 und verwendet es (voll kompatibel) oder installiert Python 3.11 via PPA falls nötig.

### 2. MongoDB Repository

**Problem**: MongoDB 7.0 unterstützt offiziell noch kein Ubuntu 24.04 (noble)
**Lösung**: Das Skript verwendet automatisch das Ubuntu 22.04 (jammy) Repository, das voll kompatibel ist.

### 3. Manuelle Schritte (falls Skript hängt)

Falls das Installationsskript bei einem Schritt hängt:

#### Bei Python-Installation (Schritt 4):

```bash
# Strg+C zum Abbrechen

# Manuell Python installieren
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt update
sudo apt install -y python3.11 python3.11-venv python3-pip

# Oder Python 3.12 verwenden (bereits vorinstalliert)
sudo apt install -y python3.12-venv python3-pip

# Dann Skript neu starten
sudo ./install.sh
```

#### Bei Node.js-Installation (Schritt 5):

```bash
# Strg+C zum Abbrechen

# Manuell Node.js installieren
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
sudo apt install -y nodejs
sudo npm install -g yarn

# Dann Skript neu starten
sudo ./install.sh
```

### 4. GPG-Schlüssel Warnung

Wenn diese Meldung erscheint:
```
File '/usr/share/keyrings/mongodb-server-7.0.gpg' exists. Overwrite? (y/N)
```

**Antwort**: Drücken Sie `y` und Enter

Das Skript sollte dann automatisch weiterlaufen. Falls nicht, wurde dies in der neuesten Version behoben (verwendet `-o` Flag für automatisches Überschreiben).

### 5. Alternative: Nicht-interaktive Installation

Für vollautomatische Installation ohne Prompts:

```bash
# Alle Antworten vorbereiten
export SERVER_IP="43.251.160.244"
export SERVER_DOMAIN="vpn-dus.leonboldt.de"
export WG_PORT="51820"
export SETUP_SSL="y"
export SSL_EMAIL="your@email.com"
export SETUP_FIREWALL="n"

# Dann install.sh entsprechend anpassen oder direkt die Befehle ausführen
```

### 6. Empfohlene Vorgehensweise für Ubuntu 24.04

**Option 1: Cleanup + Neuinstallation (empfohlen bei Problemen)**
```bash
cd ~/WireGuard
sudo ./cleanup.sh
sudo ./install.sh
```

**Option 2: Direkte Installation (bei frischem System)**
```bash
git clone https://github.com/speckitime/WireGuard.git
cd WireGuard
sudo ./install.sh
```

### 7. Verifizierung nach Installation

```bash
# Python Version prüfen
python3.11 --version || python3.12 --version

# MongoDB Status
sudo systemctl status mongod

# Backend Status
sudo supervisorctl status wireguard-backend

# Nginx Status
sudo systemctl status nginx

# WireGuard Installation
which wg
which wg-quick
```

### 8. Bekannte Probleme auf Ubuntu 24.04

#### Problem: apt-Warnungen während Installation
**Symptom**: "WARNING: apt does not have a stable CLI interface"
**Impact**: Keine - nur eine Warnung, Installation funktioniert normal

#### Problem: MongoDB startet nicht sofort
**Symptom**: MongoDB Service läuft nicht nach Installation
**Lösung**:
```bash
sudo systemctl start mongod
sudo systemctl enable mongod
sudo systemctl status mongod
```

#### Problem: Python 3.12 statt 3.11
**Impact**: Keine - Python 3.12 ist vollständig kompatibel
**Info**: Alle Python-Pakete funktionieren mit 3.12

### 9. System-Anforderungen für Ubuntu 24.04

**Minimal**:
- 2 GB RAM
- 2 CPU Cores
- 20 GB Festplatte

**Empfohlen**:
- 4 GB RAM
- 2-4 CPU Cores
- 40 GB Festplatte
- SSD für bessere Performance

### 10. Performance-Tipps für Ubuntu 24.04

```bash
# AppArmor für bessere Performance deaktivieren (optional)
sudo systemctl disable apparmor
sudo systemctl stop apparmor

# Swap anpassen (falls wenig RAM)
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# MongoDB Journaling optimieren
sudo nano /etc/mongod.conf
# Fügen Sie hinzu:
# storage:
#   journal:
#     commitIntervalMs: 100
```

### 11. Sicherheits-Empfehlungen für Ubuntu 24.04

```bash
# Automatische Updates aktivieren
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades

# Fail2ban installieren
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# SSH härten
sudo nano /etc/ssh/sshd_config
# Ändern Sie:
# PermitRootLogin no
# PasswordAuthentication no
# Port 2222  # Oder ein anderer Port

sudo systemctl restart sshd
```

### 12. Troubleshooting-Checkliste

- [ ] Cleanup ausgeführt vor Neuinstallation?
- [ ] Alte MongoDB-Repository-Dateien entfernt?
- [ ] Python 3.11 oder 3.12 installiert?
- [ ] Node.js 20.x installiert?
- [ ] Genug Festplattenspeicher? (`df -h`)
- [ ] Genug RAM? (`free -h`)
- [ ] Internet-Verbindung funktioniert?
- [ ] Port 80 für Let's Encrypt frei?
- [ ] DNS für Domain korrekt konfiguriert?

### 13. Logs bei Problemen

```bash
# System-Logs
sudo journalctl -xeu mongod
sudo journalctl -xeu nginx

# Installation-Logs
tail -f /var/log/wireguard-backend-error.log
tail -f /var/log/nginx/error.log

# Apt-Logs
sudo cat /var/log/apt/term.log
sudo cat /var/log/apt/history.log
```

### 14. Support

Bei Problemen spezifisch für Ubuntu 24.04:
- GitHub Issues: https://github.com/speckitime/WireGuard/issues
- Tag: `ubuntu-24.04`
- Include: `lsb_release -a` Output

### 15. Erfolgs-Bestätigung

Nach erfolgreicher Installation sollten Sie sehen:

```bash
╔═══════════════════════════════════════════════════╗
║                                                   ║
║     Installation erfolgreich abgeschlossen!      ║
║                                                   ║
╚═══════════════════════════════════════════════════╝

📍 Installationsverzeichnis: /opt/wireguard-admin
🌐 Frontend URL: http://vpn-dus.leonboldt.de
🔒 HTTPS URL: https://vpn-dus.leonboldt.de
```

Dann ist alles bereit! 🎉
