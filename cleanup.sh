#!/bin/bash

###############################################################################
# WireGuard Admin Panel - Cleanup & Neuinstallations-Script
# Verwenden Sie dieses Skript, wenn eine Installation fehlgeschlagen ist
###############################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}[ERROR]${NC} Bitte führen Sie das Skript als root aus (sudo ./cleanup.sh)"
    exit 1
fi

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════╗
║    WireGuard Admin - Cleanup & Neuinstallation   ║
╚═══════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_warning "Dieses Skript entfernt alte Installations-Reste und bereitet eine Neuinstallation vor."
echo ""
read -p "Möchten Sie fortfahren? (y/n): " CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Abgebrochen."
    exit 0
fi

echo ""
print_info "Starte Cleanup..."

# 1. Services stoppen
print_info "1/7 - Stoppe Services..."
supervisorctl stop wireguard-backend 2>/dev/null || true
systemctl stop nginx 2>/dev/null || true
print_success "Services gestoppt"

# 2. Alte Repository-Dateien entfernen
print_info "2/7 - Entferne alte Repository-Dateien..."
rm -f /etc/apt/sources.list.d/mongodb-org-7.0.list
rm -f /etc/apt/sources.list.d/mongodb-org-6.0.list
rm -f /usr/share/keyrings/mongodb-server-7.0.gpg
rm -f /usr/share/keyrings/mongodb-server-6.0.gpg
print_success "Repository-Dateien entfernt"

# 3. Apt cache aufräumen
print_info "3/7 - Räume apt cache auf..."
apt clean
apt update -qq 2>/dev/null || apt update
print_success "Apt cache aufgeräumt"

# 4. Alte Konfigurationsdateien entfernen
print_info "4/7 - Entferne alte Konfigurationsdateien..."
rm -f /etc/supervisor/conf.d/wireguard-backend.conf
rm -f /etc/nginx/sites-enabled/wireguard-admin
rm -f /etc/nginx/sites-available/wireguard-admin
print_success "Konfigurationsdateien entfernt"

# 5. Installations-Verzeichnis sichern (falls vorhanden)
print_info "5/7 - Sichere altes Installations-Verzeichnis..."
if [ -d /opt/wireguard-admin ]; then
    BACKUP_DIR="/opt/wireguard-admin_backup_$(date +%Y%m%d_%H%M%S)"
    mv /opt/wireguard-admin "$BACKUP_DIR"
    print_success "Altes Verzeichnis nach $BACKUP_DIR verschoben"
else
    print_info "Kein altes Verzeichnis gefunden"
fi

# 6. WireGuard Konfiguration sichern (falls vorhanden)
print_info "6/7 - Sichere WireGuard Konfiguration..."
if [ -f /etc/wireguard/wg0.conf ]; then
    BACKUP_WG="/etc/wireguard/wg0.conf.backup_$(date +%Y%m%d_%H%M%S)"
    cp /etc/wireguard/wg0.conf "$BACKUP_WG"
    print_success "WireGuard Config nach $BACKUP_WG gesichert"
else
    print_info "Keine WireGuard Konfiguration gefunden"
fi

# 7. Services neu laden
print_info "7/7 - Services neu laden..."
supervisorctl reread 2>/dev/null || true
supervisorctl update 2>/dev/null || true
systemctl restart nginx 2>/dev/null || true
print_success "Services neu geladen"

echo ""
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════╗
║            Cleanup erfolgreich!                   ║
╚═══════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
print_success "System ist bereit für eine Neuinstallation!"
echo ""
print_info "Führen Sie jetzt aus:"
echo "  sudo ./install.sh"
echo ""
print_info "Gesicherte Dateien:"
if [ -d "$BACKUP_DIR" ]; then
    echo "  - Altes Verzeichnis: $BACKUP_DIR"
fi
if [ -f "$BACKUP_WG" ]; then
    echo "  - WireGuard Config: $BACKUP_WG"
fi
echo ""
