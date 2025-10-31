# Registrierungs-Fehler beheben

## Häufigste Ursachen und Lösungen

### Problem: "Es ist ein Fehler aufgetreten" bei Registrierung

#### 1. Backend-Logs überprüfen

Führen Sie das Diagnose-Skript aus:
```bash
cd ~/WireGuard  # oder wo auch immer das Repo liegt
sudo ./diagnose.sh
```

#### 2. Manuelle Diagnose

```bash
# Backend-Status prüfen
sudo supervisorctl status wireguard-backend

# Backend-Logs ansehen
sudo tail -n 50 /var/log/wireguard-backend-error.log

# MongoDB-Status prüfen
sudo systemctl status mongod

# API direkt testen
curl -X POST http://localhost:8001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"TestPass123!"}'
```

### Häufige Fehler und Lösungen

#### Fehler 1: Backend läuft nicht

**Symptom**: `supervisorctl status` zeigt `STOPPED` oder `FATAL`

**Lösung**:
```bash
# Backend neu starten
sudo supervisorctl restart wireguard-backend

# Logs prüfen
sudo tail -f /var/log/wireguard-backend-error.log
```

#### Fehler 2: MongoDB läuft nicht

**Symptom**: Fehler in Logs: "ServerSelectionTimeoutError" oder "Connection refused"

**Lösung**:
```bash
# MongoDB starten
sudo systemctl start mongod
sudo systemctl enable mongod

# Status prüfen
sudo systemctl status mongod

# Verbindung testen
mongosh --eval "db.adminCommand('ping')"
```

#### Fehler 3: Passwort-Anforderungen nicht erfüllt

**Symptom**: Fehler bei schwachen Passwörtern

**Anforderungen**:
- Mindestens 8 Zeichen
- Sonderzeichen sind erlaubt
- Keine speziellen Einschränkungen im Backend

**Test mit einfachem Passwort**:
```bash
curl -X POST http://localhost:8001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin123!"}'
```

#### Fehler 4: CORS-Fehler

**Symptom**: In Browser-Console (F12): "CORS policy"

**Lösung**:
```bash
# Backend .env prüfen
cat /opt/wireguard-admin/backend/.env | grep CORS

# CORS auf * setzen
sudo nano /opt/wireguard-admin/backend/.env
# Setzen Sie: CORS_ORIGINS="*"

# Backend neu starten
sudo supervisorctl restart wireguard-backend
```

#### Fehler 5: JWT_SECRET fehlt

**Symptom**: Backend startet nicht, Fehler: "JWT_SECRET not found"

**Lösung**:
```bash
# JWT_SECRET generieren
JWT_SECRET=$(openssl rand -hex 32)

# In .env hinzufügen
echo "JWT_SECRET=\"$JWT_SECRET\"" | sudo tee -a /opt/wireguard-admin/backend/.env

# Backend neu starten
sudo supervisorctl restart wireguard-backend
```

### Schritt-für-Schritt Debug-Prozess

#### Schritt 1: Services prüfen

```bash
# Alle Services prüfen
sudo supervisorctl status
sudo systemctl status mongod
sudo systemctl status nginx
```

Alle sollten "RUNNING" oder "active (running)" zeigen.

#### Schritt 2: API manuell testen

```bash
# Health-Check
curl http://localhost:8001/api/

# Sollte zurückgeben: {"message":"Hello World"}
```

#### Schritt 3: MongoDB-Verbindung testen

```bash
# MongoDB Shell öffnen
mongosh

# In der Shell:
use wireguard_admin
db.users.find()
# Sollte keine Fehler werfen
```

#### Schritt 4: Registrierung mit curl testen

```bash
curl -X POST http://localhost:8001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testadmin","password":"SecurePass123!"}' \
  -v
```

**Erfolgreiche Antwort**:
```json
{
  "access_token": "eyJ...",
  "token_type": "bearer"
}
```

**Fehler-Antwort**:
```json
{
  "detail": "Username already registered"
}
```
oder
```json
{
  "detail": "Internal Server Error"
}
```

#### Schritt 5: Browser-Console prüfen

1. Browser öffnen (F12)
2. Console-Tab öffnen
3. Registrierung versuchen
4. Fehler-Meldungen lesen

**Häufige Browser-Fehler**:
- `Failed to fetch` → Backend nicht erreichbar
- `CORS error` → CORS-Konfiguration falsch
- `500 Internal Server Error` → Backend-Problem

### Komplette Neuinstallation (Last Resort)

Wenn nichts funktioniert:

```bash
cd ~/WireGuard

# Cleanup
sudo ./cleanup.sh

# Neuinstallation
sudo ./install.sh
```

### Backend manuell starten (für Debugging)

```bash
# Supervisor stoppen
sudo supervisorctl stop wireguard-backend

# Manuell mit Logs starten
cd /opt/wireguard-admin/backend
source ../venv/bin/activate
uvicorn server:app --host 0.0.0.0 --port 8001 --reload

# Fehler werden direkt angezeigt
# Mit Strg+C beenden
```

### Frontend-Probleme

Falls das Frontend die API nicht erreicht:

```bash
# Frontend .env prüfen
cat /opt/wireguard-admin/frontend/.env

# Sollte enthalten:
# REACT_APP_BACKEND_URL=http://vpn-dus.leonboldt.de
# oder
# REACT_APP_BACKEND_URL=https://vpn-dus.leonboldt.de

# Falls falsch, korrigieren und Frontend neu bauen:
cd /opt/wireguard-admin/frontend
sudo nano .env
yarn build
sudo systemctl restart nginx
```

### Spezifische Fehler-Codes

| HTTP Code | Bedeutung | Lösung |
|-----------|-----------|--------|
| 500 | Server-Fehler | Backend-Logs prüfen |
| 400 | Ungültige Anfrage | Passwort/Username prüfen |
| 401 | Nicht authentifiziert | Token abgelaufen/ungültig |
| 404 | Endpoint nicht gefunden | API-Route prüfen |
| 502/503 | Backend nicht erreichbar | Backend starten |

### Logs in Echtzeit verfolgen

```bash
# Terminal 1: Backend-Logs
sudo tail -f /var/log/wireguard-backend-error.log

# Terminal 2: Nginx-Logs
sudo tail -f /var/log/nginx/error.log

# Dann im Browser Registrierung versuchen und Logs beobachten
```

### Support

Wenn Sie das Problem immer noch nicht lösen können:

1. Führen Sie `sudo ./diagnose.sh` aus
2. Sammeln Sie alle Ausgaben
3. Erstellen Sie ein GitHub Issue mit:
   - Output von `diagnose.sh`
   - Backend-Logs
   - Browser-Console-Fehler (Screenshot)
   - Ubuntu-Version (`lsb_release -a`)

GitHub Issues: https://github.com/speckitime/WireGuard/issues
