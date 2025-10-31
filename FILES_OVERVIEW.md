# Dateiübersicht - WireGuard Admin Panel

## 📁 Hauptdateien

### Installation & Dokumentation
- **install.sh** - Automatisches Installationsskript für Ubuntu (empfohlen!)
- **README.md** - Vollständige Dokumentation mit manuellen Installationsschritten
- **QUICKSTART.md** - Schnellstart-Anleitung für neue Benutzer
- **CONTRIBUTING.md** - Richtlinien für Contributors
- **LICENSE** - MIT Lizenz

### Backend (`/backend`)
- **server.py** - FastAPI Backend mit allen Endpoints
  - JWT Authentifizierung
  - WireGuard Server Management
  - Client Verwaltung
  - Statistiken & Monitoring
  - SSH Remote-Support
- **requirements.txt** - Python Dependencies
- **.env** - Umgebungsvariablen (wird bei Installation erstellt)

### Frontend (`/frontend`)
- **src/App.js** - Haupt-React-Komponente mit Routing
- **src/App.css** - Globale Styles mit Space Grotesk Font
- **src/index.js** - React Entry Point mit Toaster
- **.env** - Frontend-Konfiguration (wird bei Installation erstellt)

#### Frontend Komponenten (`/frontend/src/components`)
- **Login.jsx** - Login/Registrierungs-Seite mit JWT
- **Dashboard.jsx** - Hauptdashboard mit Statistiken
- **AddClientModal.jsx** - Modal zum Hinzufügen neuer Clients
- **QRCodeModal.jsx** - QR-Code Anzeige für Clients

### CI/CD
- **.github/workflows/ci.yml** - GitHub Actions für automatische Tests

## 🚀 Schnellstart

```bash
git clone https://github.com/speckitime/WireGuard.git
cd WireGuard
sudo ./install.sh
```

## 📝 Wichtige Konfigurationsdateien

### Backend .env
```
MONGO_URL="mongodb://localhost:27017"
DB_NAME="wireguard_admin"
JWT_SECRET="..."
SSH_ENABLED=false
```

### Frontend .env
```
REACT_APP_BACKEND_URL=http://YOUR_SERVER_IP:8001
```

## 🔧 Nach der Installation

### Systemkonfiguration
- **/etc/sudoers.d/wireguard-admin** - Sudo-Berechtigungen
- **/etc/supervisor/conf.d/wireguard-backend.conf** - Backend Service
- **/etc/nginx/sites-available/wireguard-admin** - Nginx Konfiguration
- **/etc/wireguard/wg0.conf** - WireGuard Serverkonfiguration

### Logs
- **/var/log/wireguard-backend.log** - Backend Logs
- **/var/log/wireguard-backend-error.log** - Backend Error Logs
- **/var/log/nginx/error.log** - Nginx Error Logs

## 📦 Verzeichnisstruktur

```
/
├── backend/
│   ├── server.py
│   ├── requirements.txt
│   └── .env
├── frontend/
│   ├── src/
│   │   ├── App.js
│   │   ├── App.css
│   │   ├── index.js
│   │   └── components/
│   │       ├── Login.jsx
│   │       ├── Dashboard.jsx
│   │       ├── AddClientModal.jsx
│   │       └── QRCodeModal.jsx
│   ├── package.json
│   └── .env
├── .github/
│   └── workflows/
│       └── ci.yml
├── install.sh
├── README.md
├── QUICKSTART.md
├── CONTRIBUTING.md
└── LICENSE
```

## 🎯 Feature-Übersicht

| Feature | Datei | Status |
|---------|-------|--------|
| JWT Auth | backend/server.py | ✅ |
| Server Init | backend/server.py | ✅ |
| Server Control | backend/server.py | ✅ |
| Client Management | backend/server.py | ✅ |
| QR-Code Generation | backend/server.py | ✅ |
| .conf Download | backend/server.py | ✅ |
| Real-time Stats | backend/server.py | ✅ |
| SSH Remote | backend/server.py | ✅ |
| Login UI | frontend/src/components/Login.jsx | ✅ |
| Dashboard UI | frontend/src/components/Dashboard.jsx | ✅ |
| Auto-Install | install.sh | ✅ |

## 🔐 Sicherheit

- JWT Tokens mit bcrypt password hashing
- CORS konfigurierbar
- Sudo-Berechtigungen minimiert
- Optional: HTTPS mit Let's Encrypt
- Optional: SSH-Key basierte Remote-Verwaltung

## 📞 Support

- GitHub Issues: https://github.com/speckitime/WireGuard/issues
- Dokumentation: README.md & QUICKSTART.md
