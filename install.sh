#!/bin/bash

###############################################################################
# WireGuard Admin Panel - Automatisches Installationsskript für Ubuntu
# Repository: https://github.com/speckitime/WireGuard
###############################################################################

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Bitte führen Sie das Skript als root aus (sudo ./install.sh)"
    exit 1
fi

# Banner
clear
echo -e "${BLUE}"
cat << "EOF"
╦ ╦┬┬─┐┌─┐╔═╗┬ ┬┌─┐┬─┐┌┬┐  ╔═╗┌┬┐┌┬┐┬┌┐┌
║║║│├┬┘├┤ ║ ╦│ │├─┤├┬┘ ││  ╠═╣ │││││││││
╚╩╝┴┴└─└─┘╚═╝└─┘┴ ┴┴└──┴┘  ╩ ╩─┴┘┴ ┴┴┘└┘
         Automatische Installation
EOF
echo -e "${NC}"

print_info "Dieses Skript installiert das WireGuard Admin Panel auf Ubuntu 20.04+"
echo ""

# Prompt for configuration
print_info "=== Konfiguration ==="
echo ""

read -p "Server öffentliche IP-Adresse: " SERVER_IP
read -p "Server Domain (optional, Enter für IP): " SERVER_DOMAIN
if [ -z "$SERVER_DOMAIN" ]; then
    SERVER_DOMAIN=$SERVER_IP
fi

read -p "WireGuard Port (Standard: 51820): " WG_PORT
WG_PORT=${WG_PORT:-51820}

read -p "Installationsverzeichnis (Standard: /opt/wireguard-admin): " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-/opt/wireguard-admin}

read -p "System-Benutzer (Standard: www-data): " APP_USER
APP_USER=${APP_USER:-www-data}

read -p "Backend Port (Standard: 8001): " BACKEND_PORT
BACKEND_PORT=${BACKEND_PORT:-8001}

read -p "Frontend Port für nginx (Standard: 80): " FRONTEND_PORT
FRONTEND_PORT=${FRONTEND_PORT:-80}

read -p "SSL/HTTPS mit Let's Encrypt einrichten? (y/n): " SETUP_SSL

read -p "Firewall (UFW) konfigurieren? (y/n): " SETUP_FIREWALL

echo ""
print_info "Konfiguration gespeichert. Starte Installation..."
sleep 2

###############################################################################
# 1. System Update & Basis-Tools
###############################################################################
print_info "1/10 - System wird aktualisiert..."

# Entferne alte MongoDB-Repository-Dateien falls vorhanden
if [ -f /etc/apt/sources.list.d/mongodb-org-7.0.list ]; then
    print_info "Entferne alte MongoDB-Repository-Datei..."
    rm -f /etc/apt/sources.list.d/mongodb-org-7.0.list
fi

apt update -qq
apt upgrade -y -qq
apt install -y gnupg curl wget git software-properties-common >/dev/null 2>&1
print_success "System aktualisiert und Basis-Tools installiert"

###############################################################################
# 2. WireGuard installieren
###############################################################################
print_info "2/10 - WireGuard wird installiert..."
apt install -y wireguard wireguard-tools >/dev/null 2>&1
print_success "WireGuard installiert"

###############################################################################
# 3. MongoDB installieren
###############################################################################
print_info "3/10 - MongoDB wird installiert..."

# Check Ubuntu version
UBUNTU_VERSION=$(lsb_release -cs)
UBUNTU_MAJOR=$(lsb_release -rs | cut -d. -f1)

if ! command -v mongod &> /dev/null; then
    print_info "Füge MongoDB Repository hinzu..."
    
    # Ubuntu 24.04 (noble) wird noch nicht offiziell unterstützt, verwende jammy Repository
    if [ "$UBUNTU_VERSION" = "noble" ]; then
        print_warning "Ubuntu 24.04 erkannt. Verwende MongoDB Repository für Ubuntu 22.04 (jammy)"
        MONGO_UBUNTU_VERSION="jammy"
    else
        MONGO_UBUNTU_VERSION=$UBUNTU_VERSION
    fi
    
    # -o flag überschreibt automatisch existierende Dateien
    curl -fsSL https://pgp.mongodb.com/server-7.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg 2>/dev/null
    chmod 644 /usr/share/keyrings/mongodb-server-7.0.gpg
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu $MONGO_UBUNTU_VERSION/mongodb-org/7.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list >/dev/null
    apt update -qq 2>&1 | grep -E "(Reading|Building)" || true
    
    print_info "Installiere MongoDB (kann einige Minuten dauern)..."
    DEBIAN_FRONTEND=noninteractive apt install -y mongodb-org 2>&1 | grep -E "(Setting up|Unpacking|Processing)" || true
    
    # Start MongoDB
    systemctl start mongod 2>/dev/null || true
    systemctl enable mongod >/dev/null 2>&1 || true
    
    # Wait for MongoDB to start
    sleep 3
    
    # Check if MongoDB is running
    if systemctl is-active --quiet mongod 2>/dev/null; then
        print_success "MongoDB installiert und gestartet"
    else
        print_warning "MongoDB Service konnte nicht automatisch gestartet werden"
        print_info "Versuche MongoDB manuell zu starten..."
        systemctl start mongod 2>/dev/null || true
        sleep 2
        if systemctl is-active --quiet mongod 2>/dev/null; then
            print_success "MongoDB läuft jetzt"
        else
            print_error "MongoDB-Start fehlgeschlagen"
            print_warning "MongoDB wird später beim ersten API-Aufruf automatisch gestartet"
            # Nicht abbrechen - MongoDB startet eventuell später
        fi
    fi
else
    print_success "MongoDB bereits installiert"
    # Stelle sicher, dass MongoDB läuft
    if ! systemctl is-active --quiet mongod 2>/dev/null; then
        systemctl start mongod 2>/dev/null || true
    fi
fi

###############################################################################
# 4. Python 3.11 installieren
###############################################################################
print_info "4/10 - Python 3.11 wird installiert..."

# Check Ubuntu version
UBUNTU_MAJOR=$(lsb_release -rs | cut -d. -f1)

if ! command -v python3.11 &> /dev/null; then
    if [ "$UBUNTU_MAJOR" -ge 24 ]; then
        # Ubuntu 24.04 und neuer - verwende Python 3.12 oder installiere 3.11 via PPA
        if command -v python3.12 &> /dev/null; then
            print_info "Ubuntu 24.04+ erkannt. Verwende Python 3.12 (kompatibel)..."
            # Erstelle Symlink für python3.11
            ln -sf /usr/bin/python3.12 /usr/local/bin/python3.11 2>/dev/null || true
            apt install -y python3.12-venv python3-pip >/dev/null 2>&1
        else
            # Fallback: Installiere Python 3.11 via PPA
            print_info "Installiere Python 3.11 via PPA..."
            add-apt-repository -y ppa:deadsnakes/ppa >/dev/null 2>&1
            apt update -qq 2>/dev/null
            apt install -y python3.11 python3.11-venv python3-pip >/dev/null 2>&1
        fi
    else
        # Ubuntu 20.04/22.04 - Python 3.11 direkt verfügbar
        apt install -y python3.11 python3.11-venv python3-pip >/dev/null 2>&1
    fi
else
    print_info "Python 3.11 bereits installiert"
fi

# Verify Python installation
if command -v python3.11 &> /dev/null || command -v python3.12 &> /dev/null; then
    print_success "Python installiert"
else
    print_error "Python-Installation fehlgeschlagen"
    exit 1
fi

###############################################################################
# 5. Node.js und Yarn installieren
###############################################################################
print_info "5/10 - Node.js und Yarn werden installiert..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >/dev/null 2>&1
    apt install -y nodejs >/dev/null 2>&1
fi

if ! command -v yarn &> /dev/null; then
    npm install -g yarn >/dev/null 2>&1
fi
print_success "Node.js und Yarn installiert"

###############################################################################
# 6. Supervisor und Nginx installieren
###############################################################################
print_info "6/10 - Supervisor und Nginx werden installiert..."
apt install -y supervisor nginx >/dev/null 2>&1
print_success "Supervisor und Nginx installiert"

###############################################################################
# 7. Projekt klonen und einrichten
###############################################################################
print_info "7/10 - Projekt wird von GitHub geklont..."

# Remove old installation if exists
if [ -d "$INSTALL_DIR" ]; then
    print_warning "Altes Verzeichnis gefunden. Erstelle Backup..."
    mv "$INSTALL_DIR" "${INSTALL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
fi

git clone https://github.com/speckitime/WireGuard.git "$INSTALL_DIR" >/dev/null 2>&1
cd "$INSTALL_DIR"
print_success "Projekt geklont"

###############################################################################
# 8. Backend einrichten
###############################################################################
print_info "8/10 - Backend wird eingerichtet..."

# Create virtual environment
if command -v python3.11 &> /dev/null; then
    PYTHON_CMD="python3.11"
elif command -v python3.12 &> /dev/null; then
    PYTHON_CMD="python3.12"
else
    PYTHON_CMD="python3"
fi

print_info "Erstelle Python Virtual Environment mit $PYTHON_CMD..."
$PYTHON_CMD -m venv venv
source venv/bin/activate

# Install dependencies
cd "$INSTALL_DIR/backend"
pip install -r requirements.txt >/dev/null 2>&1

# Generate JWT secret
JWT_SECRET=$(openssl rand -hex 32)

# Create .env file
cat > .env << EOF
MONGO_URL="mongodb://localhost:27017"
DB_NAME="wireguard_admin"
CORS_ORIGINS="*"
JWT_SECRET="$JWT_SECRET"

# SSH Remote Management (optional)
SSH_ENABLED=false
SSH_HOST=""
SSH_PORT=22
SSH_USER="root"
SSH_KEY_PATH=""
EOF

print_success "Backend konfiguriert"

###############################################################################
# 9. Frontend einrichten
###############################################################################
print_info "9/10 - Frontend wird eingerichtet..."

cd "$INSTALL_DIR/frontend"
yarn install >/dev/null 2>&1

# Create .env file
cat > .env << EOF
REACT_APP_BACKEND_URL=http://${SERVER_IP}:${BACKEND_PORT}
EOF

# Build frontend
print_info "Frontend wird gebaut (kann einige Minuten dauern)..."
yarn build >/dev/null 2>&1

print_success "Frontend gebaut"

###############################################################################
# 10. System konfigurieren
###############################################################################
print_info "10/10 - System wird konfiguriert..."

# IP Forwarding aktivieren
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
fi

# Sudo-Berechtigungen für WireGuard
cat > /etc/sudoers.d/wireguard-admin << EOF
# WireGuard Admin Panel Berechtigungen
$APP_USER ALL=(ALL) NOPASSWD: /usr/bin/wg
$APP_USER ALL=(ALL) NOPASSWD: /usr/bin/wg-quick
$APP_USER ALL=(ALL) NOPASSWD: /bin/cp /tmp/wg0.conf /etc/wireguard/wg0.conf
$APP_USER ALL=(ALL) NOPASSWD: /bin/cp /tmp/peer.conf /etc/wireguard/*
$APP_USER ALL=(ALL) NOPASSWD: /bin/chmod 600 /etc/wireguard/*
$APP_USER ALL=(ALL) NOPASSWD: /bin/bash -c cat /tmp/peer.conf >> /etc/wireguard/wg0.conf
EOF
chmod 440 /etc/sudoers.d/wireguard-admin

# Supervisor Konfiguration
cat > /etc/supervisor/conf.d/wireguard-backend.conf << EOF
[program:wireguard-backend]
command=$INSTALL_DIR/venv/bin/uvicorn server:app --host 0.0.0.0 --port $BACKEND_PORT
directory=$INSTALL_DIR/backend
autostart=true
autorestart=true
user=$APP_USER
stdout_logfile=/var/log/wireguard-backend.log
stderr_logfile=/var/log/wireguard-backend-error.log
environment=PATH="$INSTALL_DIR/venv/bin"
EOF

# Nginx Konfiguration
if [ "$SETUP_SSL" = "y" ] || [ "$SETUP_SSL" = "Y" ]; then
    # HTTPS Configuration (SSL wird später von certbot hinzugefügt)
    cat > /etc/nginx/sites-available/wireguard-admin << EOF
server {
    listen $FRONTEND_PORT;
    server_name $SERVER_DOMAIN;

    # Frontend
    root $INSTALL_DIR/frontend/build;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Backend API Proxy
    location /api {
        proxy_pass http://localhost:$BACKEND_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF
else
    # HTTP Only Configuration
    cat > /etc/nginx/sites-available/wireguard-admin << EOF
server {
    listen $FRONTEND_PORT;
    server_name $SERVER_DOMAIN;

    # Frontend
    root $INSTALL_DIR/frontend/build;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Backend API Proxy
    location /api {
        proxy_pass http://localhost:$BACKEND_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF
fi

# Aktiviere nginx site
ln -sf /etc/nginx/sites-available/wireguard-admin /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test nginx config
nginx -t >/dev/null 2>&1

# Berechtigungen setzen
chown -R $APP_USER:$APP_USER "$INSTALL_DIR"

print_success "System konfiguriert"

###############################################################################
# Services starten
###############################################################################
print_info "Services werden gestartet..."

systemctl restart supervisor
supervisorctl reread >/dev/null 2>&1
supervisorctl update >/dev/null 2>&1
supervisorctl start wireguard-backend >/dev/null 2>&1

systemctl restart nginx

print_success "Services gestartet"

###############################################################################
# Firewall konfigurieren (wenn gewählt)
###############################################################################
if [ "$SETUP_FIREWALL" = "y" ] || [ "$SETUP_FIREWALL" = "Y" ]; then
    print_info "Firewall wird konfiguriert..."
    
    ufw --force enable >/dev/null 2>&1
    ufw allow 22/tcp >/dev/null 2>&1  # SSH
    ufw allow $FRONTEND_PORT/tcp >/dev/null 2>&1  # HTTP
    ufw allow 443/tcp >/dev/null 2>&1  # HTTPS
    ufw allow $WG_PORT/udp >/dev/null 2>&1  # WireGuard
    
    print_success "Firewall konfiguriert"
fi

###############################################################################
# SSL Setup (wenn gewählt)
###############################################################################
if [ "$SETUP_SSL" = "y" ] || [ "$SETUP_SSL" = "Y" ]; then
    print_info "SSL wird eingerichtet..."
    
    # Install certbot
    apt install -y certbot python3-certbot-nginx >/dev/null 2>&1
    
    read -p "E-Mail-Adresse für Let's Encrypt: " SSL_EMAIL
    
    # Run certbot
    print_info "Certbot wird ausgeführt (kann einige Minuten dauern)..."
    certbot --nginx -d "$SERVER_DOMAIN" --non-interactive --agree-tos -m "$SSL_EMAIL" --redirect
    
    if [ $? -eq 0 ]; then
        # Update Frontend .env for HTTPS
        sed -i "s|http://|https://|g" "$INSTALL_DIR/frontend/.env"
        
        # Rebuild frontend with HTTPS URL
        print_info "Frontend wird mit HTTPS-URL neu gebaut..."
        cd "$INSTALL_DIR/frontend"
        yarn build >/dev/null 2>&1
        
        # Setup auto-renewal
        systemctl enable certbot.timer >/dev/null 2>&1
        
        print_success "SSL eingerichtet und automatische Erneuerung aktiviert"
    else
        print_error "SSL-Setup fehlgeschlagen. Bitte überprüfen Sie:"
        print_error "1. Domain $SERVER_DOMAIN zeigt auf $SERVER_IP"
        print_error "2. Port 80 ist nicht blockiert"
        print_error "3. Keine andere Website verwendet diese Domain"
        print_warning "Sie können SSL später manuell einrichten mit: sudo certbot --nginx -d $SERVER_DOMAIN"
    fi
fi

###############################################################################
# Installation abgeschlossen
###############################################################################
echo ""
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════╗
║                                                   ║
║     Installation erfolgreich abgeschlossen!      ║
║                                                   ║
╚═══════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
print_info "=== Wichtige Informationen ==="
echo ""
echo "📍 Installationsverzeichnis: $INSTALL_DIR"
echo "🌐 Frontend URL: http://$SERVER_DOMAIN"
if [ "$SETUP_SSL" = "y" ] || [ "$SETUP_SSL" = "Y" ]; then
    echo "🔒 HTTPS URL: https://$SERVER_DOMAIN"
    echo "🔐 SSL-Zertifikat: Automatische Erneuerung aktiviert"
fi
echo "🔧 Backend API: http://$SERVER_IP:$BACKEND_PORT/api"
echo "📝 API Docs: http://$SERVER_IP:$BACKEND_PORT/docs"
echo ""
print_info "=== Nächste Schritte ==="
echo ""
echo "1. Öffnen Sie http://$SERVER_DOMAIN im Browser"
echo "2. Registrieren Sie einen Admin-Account"
echo "3. Initialisieren Sie den WireGuard Server"
echo "4. Erstellen Sie Client-Profile"
echo ""
print_info "=== Nützliche Befehle ==="
echo ""
echo "# Service Status prüfen"
echo "  sudo supervisorctl status wireguard-backend"
echo ""
echo "# Logs anzeigen"
echo "  sudo tail -f /var/log/wireguard-backend.log"
echo "  sudo tail -f /var/log/wireguard-backend-error.log"
echo ""
echo "# Services neu starten"
echo "  sudo supervisorctl restart wireguard-backend"
echo "  sudo systemctl restart nginx"
echo ""
echo "# Konfiguration bearbeiten"
echo "  nano $INSTALL_DIR/backend/.env"
echo "  nano $INSTALL_DIR/frontend/.env"
echo ""
print_warning "Wichtig: Ändern Sie das JWT_SECRET in $INSTALL_DIR/backend/.env für Produktionsumgebungen!"
echo ""
print_info "Bei Fragen: https://github.com/speckitime/WireGuard"
echo ""

# Service Status
print_info "Service Status:"
supervisorctl status wireguard-backend 2>/dev/null || echo "Backend startet..."
echo ""

print_success "🎉 Viel Erfolg mit dem WireGuard Admin Panel! 🎉"
