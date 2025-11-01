#!/bin/bash

###############################################################################
# WireGuard Admin Panel - Vollautomatisches Setup
# Frisches Ubuntu 24.04 → Produktionsreifer WireGuard VPN Server
###############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${CYAN}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  $1${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════╝${NC}"
}

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }

if [ "$EUID" -ne 0 ]; then 
    print_error "Bitte als root ausführen: sudo $0"
    exit 1
fi

clear
echo -e "${CYAN}"
cat << "EOF"
╦ ╦┬┬─┐┌─┐╔═╗┬ ┬┌─┐┬─┐┌┬┐  ╔═╗┌─┐┌┬┐┬ ┬┌─┐
║║║│├┬┘├┤ ║ ╦│ │├─┤├┬┘ ││  ╚═╗├┤  │ │ │├─┘
╚╩╝┴┴└─└─┘╚═╝└─┘┴ ┴┴└──┴┘  ╚═╝└─┘ ┴ └─┘┴  
     Vollautomatisches Setup v2.0
EOF
echo -e "${NC}"

print_info "Dieses Skript richtet einen PRODUKTIONSREIFEN WireGuard VPN Server ein"
echo ""

# Konfiguration sammeln
print_header "      KONFIGURATION                             "
read -p "Server öffentliche IP: " SERVER_IP
read -p "Server Domain (optional): " SERVER_DOMAIN
SERVER_DOMAIN=${SERVER_DOMAIN:-$SERVER_IP}

read -p "Admin E-Mail (für SSL): " ADMIN_EMAIL
read -p "SSL/HTTPS einrichten? (y/n): " SETUP_SSL

read -p "Admin-Benutzername: " ADMIN_USER
read -sp "Admin-Passwort: " ADMIN_PASS
echo ""

WG_PORT=51820
INSTALL_DIR="/opt/wireguard-admin"

print_info "Konfiguration gespeichert. Starte Installation..."
sleep 2

###############################################################################
# 1. SYSTEM UPDATE & PAKETE
###############################################################################
print_header "      1/12 - SYSTEM UPDATE                      "
rm -f /etc/apt/sources.list.d/mongodb-org-*.list
apt update -qq
apt upgrade -y -qq
apt install -y gnupg curl wget git software-properties-common ufw net-tools -qq
print_success "System aktualisiert"

###############################################################################
# 2. WIREGUARD
###############################################################################
print_header "      2/12 - WIREGUARD                          "
apt install -y wireguard wireguard-tools -qq
print_success "WireGuard installiert"

###############################################################################
# 3. MONGODB
###############################################################################
print_header "      3/12 - MONGODB                            "
UBUNTU_VERSION=$(lsb_release -cs)
if [ "$UBUNTU_VERSION" = "noble" ]; then
    MONGO_UBUNTU_VERSION="jammy"
else
    MONGO_UBUNTU_VERSION=$UBUNTU_VERSION
fi

curl -fsSL https://pgp.mongodb.com/server-7.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg 2>/dev/null
chmod 644 /usr/share/keyrings/mongodb-server-7.0.gpg
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu $MONGO_UBUNTU_VERSION/mongodb-org/7.0 multiverse" > /etc/apt/sources.list.d/mongodb-org-7.0.list
apt update -qq
DEBIAN_FRONTEND=noninteractive apt install -y mongodb-org -qq
systemctl start mongod
systemctl enable mongod
print_success "MongoDB installiert"

###############################################################################
# 4. PYTHON 3.11/3.12
###############################################################################
print_header "      4/12 - PYTHON                             "
if command -v python3.12 &> /dev/null; then
    PYTHON_CMD="python3.12"
    apt install -y python3.12-venv python3-pip -qq
elif command -v python3.11 &> /dev/null; then
    PYTHON_CMD="python3.11"
    apt install -y python3.11-venv python3-pip -qq
else
    add-apt-repository -y ppa:deadsnakes/ppa -qq
    apt update -qq
    apt install -y python3.11 python3.11-venv python3-pip -qq
    PYTHON_CMD="python3.11"
fi
print_success "Python ($PYTHON_CMD) installiert"

###############################################################################
# 5. NODE.JS & YARN
###############################################################################
print_header "      5/12 - NODE.JS & YARN                     "
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >/dev/null 2>&1
    apt install -y nodejs -qq
fi
if ! command -v yarn &> /dev/null; then
    npm install -g yarn >/dev/null 2>&1
fi
print_success "Node.js & Yarn installiert"

###############################################################################
# 6. SUPERVISOR & NGINX
###############################################################################
print_header "      6/12 - SUPERVISOR & NGINX                 "
apt install -y supervisor nginx -qq
print_success "Supervisor & Nginx installiert"

###############################################################################
# 7. PROJEKT KLONEN
###############################################################################
print_header "      7/12 - PROJEKT SETUP                      "
if [ -d "$INSTALL_DIR" ]; then
    mv "$INSTALL_DIR" "${INSTALL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
fi

git clone https://github.com/speckitime/WireGuard.git "$INSTALL_DIR" -q
cd "$INSTALL_DIR"
print_success "Projekt geklont"

###############################################################################
# 8. BACKEND SETUP
###############################################################################
print_header "      8/12 - BACKEND KONFIGURATION              "
cd "$INSTALL_DIR/backend"
$PYTHON_CMD -m venv ../venv
source ../venv/bin/activate
pip install -r requirements.txt -q

JWT_SECRET=$(openssl rand -hex 32)

cat > .env << EOF
MONGO_URL="mongodb://localhost:27017"
DB_NAME="wireguard_admin"
CORS_ORIGINS="*"
JWT_SECRET="$JWT_SECRET"
WG_SERVER_IP="$SERVER_IP"
WG_SERVER_DOMAIN="$SERVER_DOMAIN"
WG_SERVER_PORT=$WG_PORT
EOF

print_success "Backend konfiguriert"

###############################################################################
# 9. FRONTEND SETUP
###############################################################################
print_header "      9/12 - FRONTEND BUILD                     "
cd "$INSTALL_DIR/frontend"

if [ "$SETUP_SSL" = "y" ]; then
    PROTOCOL="https"
else
    PROTOCOL="http"
fi

cat > .env << EOF
REACT_APP_BACKEND_URL=${PROTOCOL}://${SERVER_DOMAIN}
WDS_SOCKET_PORT=443
REACT_APP_ENABLE_VISUAL_EDITS=false
ENABLE_HEALTH_CHECK=false
EOF

yarn install -s
yarn build -s
print_success "Frontend gebaut"

###############################################################################
# 10. WIREGUARD & SYSTEM KONFIGURATION
###############################################################################
print_header "      10/12 - WIREGUARD & NETZWERK              "

# IP Forwarding
sysctl -w net.ipv4.ip_forward=1 >/dev/null
sysctl -w net.ipv6.conf.all.forwarding=1 >/dev/null

if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
fi

# WireGuard Verzeichnis
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard

# Sudo-Berechtigungen
cat > /etc/sudoers.d/wireguard-admin << 'EOF'
www-data ALL=(ALL) NOPASSWD: /usr/bin/wg
www-data ALL=(ALL) NOPASSWD: /usr/bin/wg-quick
www-data ALL=(ALL) NOPASSWD: /bin/cp /tmp/wg0.conf /etc/wireguard/wg0.conf
www-data ALL=(ALL) NOPASSWD: /bin/cp /tmp/peer.conf /etc/wireguard/*
www-data ALL=(ALL) NOPASSWD: /bin/chmod 600 /etc/wireguard/*
www-data ALL=(ALL) NOPASSWD: /bin/bash -c cat /tmp/peer.conf >> /etc/wireguard/wg0.conf
www-data ALL=(ALL) NOPASSWD: /bin/mkdir -p /etc/wireguard
EOF
chmod 440 /etc/sudoers.d/wireguard-admin

# Erkenne Interface
IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
if [ -z "$IFACE" ]; then
    IFACE="eth0"
fi

print_success "WireGuard vorbereitet (Interface: $IFACE)"

###############################################################################
# 11. SERVICES KONFIGURIEREN
###############################################################################
print_header "      11/12 - SERVICES                          "

# Supervisor
cat > /etc/supervisor/conf.d/wireguard-backend.conf << EOF
[program:wireguard-backend]
command=$INSTALL_DIR/venv/bin/uvicorn server:app --host 0.0.0.0 --port 8001
directory=$INSTALL_DIR/backend
autostart=true
autorestart=true
user=www-data
stdout_logfile=/var/log/wireguard-backend.log
stderr_logfile=/var/log/wireguard-backend-error.log
environment=PATH="$INSTALL_DIR/venv/bin"
EOF

# Nginx
cat > /etc/nginx/sites-available/wireguard-admin << EOF
server {
    listen 80;
    server_name $SERVER_DOMAIN;
    root $INSTALL_DIR/frontend/build;
    index index.html;
    
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    
    location /api {
        proxy_pass http://localhost:8001;
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

ln -sf /etc/nginx/sites-available/wireguard-admin /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

chown -R www-data:www-data "$INSTALL_DIR"

systemctl restart supervisor
supervisorctl reread
supervisorctl update
supervisorctl start wireguard-backend

nginx -t
systemctl restart nginx

print_success "Services konfiguriert"

###############################################################################
# 12. SSL & FIREWALL
###############################################################################
print_header "      12/12 - SSL & FIREWALL                    "

# Firewall
ufw --force enable
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow $WG_PORT/udp

if [ "$SETUP_SSL" = "y" ]; then
    apt install -y certbot python3-certbot-nginx -qq
    certbot --nginx -d "$SERVER_DOMAIN" --non-interactive --agree-tos -m "$ADMIN_EMAIL" --redirect
    
    if [ $? -eq 0 ]; then
        sed -i "s|http://|https://|g" "$INSTALL_DIR/frontend/.env"
        cd "$INSTALL_DIR/frontend"
        yarn build -s
        systemctl restart nginx
        systemctl enable certbot.timer
        print_success "SSL eingerichtet"
    else
        print_warning "SSL fehlgeschlagen - läuft auf HTTP"
    fi
fi

print_success "Firewall konfiguriert"

###############################################################################
# ADMIN-BENUTZER ERSTELLEN
###############################################################################
sleep 3
print_header "      ADMIN-BENUTZER ERSTELLEN                  "

TOKEN=$(curl -s -X POST http://localhost:8001/api/auth/register \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$ADMIN_USER\",\"password\":\"$ADMIN_PASS\",\"role\":\"admin\"}" | \
  python3 -c "import sys, json; print(json.load(sys.stdin).get('access_token', ''))" 2>/dev/null)

if [ ! -z "$TOKEN" ]; then
    print_success "Admin-Benutzer erstellt: $ADMIN_USER"
else
    print_warning "Admin-Benutzer manuell erstellen"
fi

###############################################################################
# FERTIG
###############################################################################
echo ""
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════╗
║                                                   ║
║         INSTALLATION ERFOLGREICH! 🎉              ║
║                                                   ║
╚═══════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
print_info "=== ZUGANGSDATEN ==="
if [ "$SETUP_SSL" = "y" ]; then
    echo "🌐 URL: https://$SERVER_DOMAIN"
else
    echo "🌐 URL: http://$SERVER_DOMAIN"
fi
echo "👤 Admin-Benutzer: $ADMIN_USER"
echo "🔑 Admin-Passwort: (gesetzt)"
echo ""
print_info "=== NÄCHSTE SCHRITTE ==="
echo "1. Browser öffnen: https://$SERVER_DOMAIN"
echo "2. Als Admin anmelden"
echo "3. Server initialisieren"
echo "4. Server starten"
echo "5. Clients erstellen"
echo ""
print_info "=== HILFE ==="
echo "Monitoring: sudo $INSTALL_DIR/helpscript.sh"
echo "Logs: sudo tail -f /var/log/wireguard-backend-error.log"
echo ""
print_success "Setup abgeschlossen!"
