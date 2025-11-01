#!/bin/bash

###############################################################################
# WireGuard Admin Panel - Alles-in-Einem Hilfs-Skript
# Diagnose, Reparatur und Wartung in einem Tool
###############################################################################

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
    echo ""
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Bitte als root ausführen: sudo $0"
    exit 1
fi

clear
echo -e "${CYAN}"
cat << "EOF"
╦ ╦┬┬─┐┌─┐╔═╗┬ ┬┌─┐┬─┐┌┬┐  ╦ ╦┌─┐┬  ┌─┐┌─┐┬─┐
║║║│├┬┘├┤ ║ ╦│ │├─┤├┬┘ ││  ╠═╣├┤ │  ├─┘├┤ ├┬┘
╚╩╝┴┴└─└─┘╚═╝└─┘┴ ┴┴└──┴┘  ╩ ╩└─┘┴─┘┴  └─┘┴└─
          Alles-in-Einem Hilfs-Tool
EOF
echo -e "${NC}"

echo "Wählen Sie eine Option:"
echo ""
echo "  ${GREEN}1)${NC} Diagnose - Alle Services und Konfigurationen prüfen"
echo "  ${GREEN}2)${NC} Backend reparieren - Backend neu starten und testen"
echo "  ${GREEN}3)${NC} HTTPS-Konfiguration prüfen und reparieren"
echo "  ${GREEN}4)${NC} Frontend-URL korrigieren und neu bauen"
echo "  ${GREEN}5)${NC} Vollständiger System-Test"
echo "  ${GREEN}6)${NC} Cleanup - Alte Installation entfernen"
echo "  ${GREEN}7)${NC} Alle Logs anzeigen"
echo "  ${GREEN}8)${NC} Services neu starten (Backend + Nginx)"
echo "  ${GREEN}9)${NC} WireGuard Server Setup prüfen und reparieren"
echo "  ${GREEN}0)${NC} Alle Fixes nacheinander ausführen"
echo "  ${RED}q)${NC} Beenden"
echo ""
read -p "Ihre Wahl [1-9,0]: " choice

case $choice in

###############################################################################
# 1. DIAGNOSE
###############################################################################
1)
    print_header "      SYSTEM-DIAGNOSE                          "
    
    print_info "1/8 - Backend-Status prüfen..."
    if supervisorctl status wireguard-backend 2>/dev/null | grep -q RUNNING; then
        print_success "Backend läuft"
    else
        print_error "Backend läuft NICHT"
        supervisorctl start wireguard-backend 2>/dev/null
    fi
    
    print_info "2/8 - MongoDB-Status prüfen..."
    if systemctl is-active --quiet mongod; then
        print_success "MongoDB läuft"
    else
        print_error "MongoDB läuft NICHT"
        systemctl start mongod
    fi
    
    print_info "3/8 - Nginx-Status prüfen..."
    if systemctl is-active --quiet nginx; then
        print_success "Nginx läuft"
    else
        print_error "Nginx läuft NICHT"
    fi
    
    print_info "4/8 - Backend API testen..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8001/api/auth/register 2>/dev/null)
    if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "400" ]; then
        print_success "Backend API erreichbar"
    else
        print_error "Backend API nicht erreichbar (HTTP $RESPONSE)"
    fi
    
    print_info "5/8 - MongoDB-Verbindung testen..."
    if mongosh --eval "db.adminCommand('ping')" --quiet >/dev/null 2>&1; then
        print_success "MongoDB-Verbindung OK"
    else
        print_error "MongoDB-Verbindung fehlgeschlagen"
    fi
    
    print_info "6/8 - SSL-Zertifikat prüfen..."
    if [ -d /etc/letsencrypt/live ]; then
        DOMAINS=$(ls /etc/letsencrypt/live/ 2>/dev/null | grep -v README)
        if [ ! -z "$DOMAINS" ]; then
            print_success "SSL-Zertifikat vorhanden für: $DOMAINS"
        else
            print_warning "Kein SSL-Zertifikat gefunden"
        fi
    else
        print_warning "Let's Encrypt nicht installiert"
    fi
    
    print_info "7/8 - Frontend .env prüfen..."
    if [ -f /opt/wireguard-admin/frontend/.env ]; then
        BACKEND_URL=$(grep REACT_APP_BACKEND_URL /opt/wireguard-admin/frontend/.env | cut -d'=' -f2)
        echo "    Backend-URL: $BACKEND_URL"
        
        if echo "$BACKEND_URL" | grep -q ":8001"; then
            print_error "Frontend verwendet Port 8001 - FALSCH!"
            echo "    Sollte sein: https://IHRE-DOMAIN"
        else
            print_success "Frontend-URL korrekt"
        fi
    else
        print_error ".env nicht gefunden"
    fi
    
    print_info "8/8 - Letzte Fehler aus Logs..."
    echo ""
    echo "Backend Errors (letzte 5 Zeilen):"
    tail -n 5 /var/log/wireguard-backend-error.log 2>/dev/null || echo "Keine Logs"
    
    echo ""
    print_info "Diagnose abgeschlossen!"
    ;;

###############################################################################
# 2. BACKEND REPARIEREN
###############################################################################
2)
    print_header "      BACKEND REPARATUR                        "
    
    print_info "Stoppe Backend..."
    supervisorctl stop wireguard-backend
    sleep 2
    
    print_info "Starte Backend neu..."
    supervisorctl start wireguard-backend
    sleep 3
    
    print_info "Prüfe Backend-Status..."
    supervisorctl status wireguard-backend
    
    echo ""
    print_info "Teste API..."
    curl -X POST http://localhost:8001/api/auth/register \
      -H "Content-Type: application/json" \
      -d '{"username":"test_'$(date +%s)'","password":"Test123!"}' \
      -s | python3 -m json.tool 2>/dev/null
    
    echo ""
    print_success "Backend-Reparatur abgeschlossen!"
    ;;

###############################################################################
# 3. HTTPS-KONFIGURATION PRÜFEN
###############################################################################
3)
    print_header "      HTTPS KONFIGURATION                     "
    
    if [ -d /etc/letsencrypt/live ]; then
        DOMAIN=$(ls /etc/letsencrypt/live/ 2>/dev/null | grep -v README | head -n1)
        
        if [ ! -z "$DOMAIN" ]; then
            print_success "SSL-Zertifikat für $DOMAIN gefunden"
            
            EXPIRY=$(openssl x509 -in /etc/letsencrypt/live/$DOMAIN/cert.pem -noout -enddate 2>/dev/null | cut -d= -f2)
            echo "    Läuft ab: $EXPIRY"
            
            print_info "Teste HTTPS-Verbindung..."
            STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN 2>/dev/null)
            if [ "$STATUS" = "200" ]; then
                print_success "HTTPS funktioniert (HTTP $STATUS)"
            else
                print_error "HTTPS funktioniert nicht (HTTP $STATUS)"
            fi
        else
            print_error "Kein SSL-Zertifikat gefunden"
        fi
    else
        print_error "Let's Encrypt nicht installiert"
    fi
    
    print_info "Nginx HTTPS-Konfiguration:"
    grep -A5 "listen 443" /etc/nginx/sites-available/wireguard-admin 2>/dev/null || echo "Nicht konfiguriert"
    ;;

###############################################################################
# 4. FRONTEND-URL KORRIGIEREN
###############################################################################
4)
    print_header "      FRONTEND-URL REPARATUR                   "
    
    print_info "Aktuelle Frontend .env:"
    cat /opt/wireguard-admin/frontend/.env 2>/dev/null
    
    echo ""
    read -p "Domain eingeben (z.B. vpn-dus.leonboldt.de): " DOMAIN
    read -p "HTTPS verwenden? (y/n): " USE_HTTPS
    
    if [ "$USE_HTTPS" = "y" ]; then
        PROTOCOL="https"
        PORT="443"
    else
        PROTOCOL="http"
        PORT="80"
    fi
    
    print_info "Erstelle neue .env..."
    cat > /opt/wireguard-admin/frontend/.env << EOF
REACT_APP_BACKEND_URL=${PROTOCOL}://${DOMAIN}
WDS_SOCKET_PORT=${PORT}
REACT_APP_ENABLE_VISUAL_EDITS=false
ENABLE_HEALTH_CHECK=false
EOF
    
    print_success ".env aktualisiert"
    cat /opt/wireguard-admin/frontend/.env
    
    echo ""
    print_info "Baue Frontend neu (1-2 Minuten)..."
    cd /opt/wireguard-admin/frontend
    yarn build > /tmp/frontend-build.log 2>&1
    
    if [ $? -eq 0 ]; then
        print_success "Frontend-Build erfolgreich"
    else
        print_error "Frontend-Build fehlgeschlagen"
        echo "Siehe: /tmp/frontend-build.log"
    fi
    
    print_info "Starte Nginx neu..."
    systemctl restart nginx
    print_success "Fertig!"
    ;;

###############################################################################
# 5. VOLLSTÄNDIGER SYSTEM-TEST
###############################################################################
5)
    print_header "      VOLLSTÄNDIGER SYSTEM-TEST                "
    
    print_info "1. Backend API Test..."
    curl -s http://localhost:8001/api/auth/register \
      -X POST \
      -H "Content-Type: application/json" \
      -d '{"username":"systest","password":"Test123!"}' | python3 -m json.tool 2>/dev/null
    
    echo ""
    print_info "2. MongoDB Test..."
    mongosh --eval "db.adminCommand('ping')" --quiet 2>/dev/null && print_success "MongoDB OK" || print_error "MongoDB Fehler"
    
    echo ""
    print_info "3. Nginx Test..."
    nginx -t 2>&1 | grep successful && print_success "Nginx Config OK" || print_error "Nginx Config Fehler"
    
    echo ""
    print_info "4. Frontend Build Test..."
    if [ -d /opt/wireguard-admin/frontend/build ]; then
        FILES=$(ls -1 /opt/wireguard-admin/frontend/build/*.js 2>/dev/null | wc -l)
        if [ $FILES -gt 0 ]; then
            print_success "Frontend Build existiert ($FILES JS-Dateien)"
        else
            print_error "Frontend Build unvollständig"
        fi
    else
        print_error "Frontend Build nicht gefunden"
    fi
    
    echo ""
    print_info "5. Netzwerk-Ports..."
    ss -tlnp 2>/dev/null | grep -E ":(80|443|8001|27017) " || netstat -tlnp 2>/dev/null | grep -E ":(80|443|8001|27017) "
    ;;

###############################################################################
# 6. CLEANUP
###############################################################################
6)
    print_header "      CLEANUP - ALTE INSTALLATION              "
    
    print_warning "Dies entfernt alte Installations-Reste!"
    read -p "Fortfahren? (y/n): " confirm
    
    if [ "$confirm" = "y" ]; then
        print_info "Stoppe Services..."
        supervisorctl stop wireguard-backend 2>/dev/null
        
        print_info "Entferne alte Repository-Dateien..."
        rm -f /etc/apt/sources.list.d/mongodb-org-*.list
        rm -f /usr/share/keyrings/mongodb-server-*.gpg
        
        print_info "Räume apt cache auf..."
        apt clean
        apt update -qq
        
        print_info "Sichere altes Verzeichnis..."
        if [ -d /opt/wireguard-admin ]; then
            BACKUP="/opt/wireguard-admin_backup_$(date +%Y%m%d_%H%M%S)"
            mv /opt/wireguard-admin "$BACKUP"
            print_success "Gesichert nach: $BACKUP"
        fi
        
        print_info "Entferne alte Configs..."
        rm -f /etc/supervisor/conf.d/wireguard-backend.conf
        rm -f /etc/nginx/sites-enabled/wireguard-admin
        
        supervisorctl reread 2>/dev/null
        supervisorctl update 2>/dev/null
        
        print_success "Cleanup abgeschlossen!"
    fi
    ;;

###############################################################################
# 7. LOGS ANZEIGEN
###############################################################################
7)
    print_header "      LOGS ANZEIGEN                            "
    
    echo "1) Backend Error Log"
    echo "2) Backend Output Log"
    echo "3) Nginx Error Log"
    echo "4) MongoDB Log"
    echo "5) Supervisor Log"
    echo "6) Alle Logs (tail -f)"
    echo ""
    read -p "Wahl [1-6]: " log_choice
    
    case $log_choice in
        1) tail -n 50 /var/log/wireguard-backend-error.log 2>/dev/null ;;
        2) tail -n 50 /var/log/wireguard-backend.log 2>/dev/null ;;
        3) tail -n 50 /var/log/nginx/error.log 2>/dev/null ;;
        4) journalctl -u mongod -n 50 ;;
        5) tail -n 50 /var/log/supervisor/supervisord.log 2>/dev/null ;;
        6) 
            print_info "Logs in Echtzeit (Strg+C zum Beenden)..."
            tail -f /var/log/wireguard-backend-error.log /var/log/nginx/error.log 2>/dev/null
            ;;
    esac
    ;;

###############################################################################
# 8. SERVICES NEU STARTEN
###############################################################################
8)
    print_header "      SERVICES NEU STARTEN                    "
    
    print_info "Starte Backend neu..."
    supervisorctl restart wireguard-backend
    sleep 2
    
    print_info "Starte Nginx neu..."
    systemctl restart nginx
    
    print_info "Starte MongoDB neu..."
    systemctl restart mongod
    
    sleep 3
    
    print_info "Prüfe Status..."
    echo ""
    echo "Backend:"
    supervisorctl status wireguard-backend
    echo ""
    echo "Nginx:"
    systemctl status nginx --no-pager -l | head -n 5
    echo ""
    echo "MongoDB:"
    systemctl status mongod --no-pager -l | head -n 5
    
    print_success "Alle Services neu gestartet!"
    ;;

###############################################################################
# 9. ALLE FIXES
###############################################################################
9)
    print_header "      ALLE FIXES AUSFÜHREN                    "
    
    print_info "1/5 - Backend reparieren..."
    supervisorctl restart wireguard-backend
    sleep 3
    
    print_info "2/5 - MongoDB prüfen..."
    systemctl restart mongod
    sleep 2
    
    print_info "3/5 - Frontend .env prüfen..."
    if grep -q ":8001" /opt/wireguard-admin/frontend/.env 2>/dev/null; then
        print_warning "Frontend-URL enthält Port 8001 - muss korrigiert werden!"
        echo "Bitte Option 4 ausführen!"
    fi
    
    print_info "4/5 - Nginx neu starten..."
    systemctl restart nginx
    
    print_info "5/5 - System-Test..."
    curl -s http://localhost:8001/api/auth/register \
      -X POST \
      -H "Content-Type: application/json" \
      -d '{"username":"autofix","password":"Test123!"}' | python3 -m json.tool 2>/dev/null
    
    print_success "Alle Fixes ausgeführt!"
    echo ""
    print_info "Teste jetzt im Browser!"
    ;;

###############################################################################
# 0. BEENDEN
###############################################################################
0)
    echo "Auf Wiedersehen!"
    exit 0
    ;;

*)
    print_error "Ungültige Auswahl!"
    exit 1
    ;;

esac

echo ""
echo "═══════════════════════════════════════════════════"
echo "Fertig! Weitere Hilfe:"
echo "  Dokumentation: README.md"
echo "  GitHub: https://github.com/speckitime/WireGuard"
echo "═══════════════════════════════════════════════════"
