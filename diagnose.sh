#!/bin/bash

###############################################################################
# WireGuard Admin Panel - Diagnose-Skript
# Verwenden Sie dieses Skript um Probleme zu identifizieren
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      WireGuard Admin - Diagnose-Tool             ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

# 1. Backend-Status
echo -e "${BLUE}[1/8] Backend-Status:${NC}"
if supervisorctl status wireguard-backend 2>/dev/null | grep -q RUNNING; then
    echo -e "${GREEN}✓ Backend läuft${NC}"
else
    echo -e "${RED}✗ Backend läuft NICHT${NC}"
    echo "Versuche Backend zu starten..."
    supervisorctl start wireguard-backend
fi
echo ""

# 2. MongoDB-Status
echo -e "${BLUE}[2/8] MongoDB-Status:${NC}"
if systemctl is-active --quiet mongod; then
    echo -e "${GREEN}✓ MongoDB läuft${NC}"
else
    echo -e "${RED}✗ MongoDB läuft NICHT${NC}"
    echo "Versuche MongoDB zu starten..."
    systemctl start mongod
fi
echo ""

# 3. Nginx-Status
echo -e "${BLUE}[3/8] Nginx-Status:${NC}"
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✓ Nginx läuft${NC}"
else
    echo -e "${RED}✗ Nginx läuft NICHT${NC}"
fi
echo ""

# 4. Backend-Logs (letzte 20 Zeilen)
echo -e "${BLUE}[4/8] Backend Error Logs:${NC}"
if [ -f /var/log/wireguard-backend-error.log ]; then
    tail -n 20 /var/log/wireguard-backend-error.log
elif [ -f /var/log/supervisor/wireguard-backend-stderr.log ]; then
    tail -n 20 /var/log/supervisor/wireguard-backend-stderr.log
else
    echo -e "${YELLOW}Keine Error-Logs gefunden${NC}"
fi
echo ""

# 5. Backend API-Test
echo -e "${BLUE}[5/8] Backend API-Test:${NC}"
BACKEND_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8001/api/ 2>/dev/null)
if [ "$BACKEND_RESPONSE" = "200" ]; then
    echo -e "${GREEN}✓ Backend API erreichbar (HTTP $BACKEND_RESPONSE)${NC}"
else
    echo -e "${RED}✗ Backend API nicht erreichbar (HTTP $BACKEND_RESPONSE)${NC}"
fi
echo ""

# 6. MongoDB-Verbindung testen
echo -e "${BLUE}[6/8] MongoDB-Verbindung:${NC}"
if mongosh --eval "db.adminCommand('ping')" --quiet >/dev/null 2>&1; then
    echo -e "${GREEN}✓ MongoDB-Verbindung OK${NC}"
else
    echo -e "${RED}✗ MongoDB-Verbindung fehlgeschlagen${NC}"
fi
echo ""

# 7. Port-Checks
echo -e "${BLUE}[7/8] Port-Status:${NC}"
if netstat -tuln 2>/dev/null | grep -q ":8001 "; then
    echo -e "${GREEN}✓ Port 8001 (Backend) offen${NC}"
else
    echo -e "${RED}✗ Port 8001 (Backend) nicht offen${NC}"
fi

if netstat -tuln 2>/dev/null | grep -q ":80 "; then
    echo -e "${GREEN}✓ Port 80 (HTTP) offen${NC}"
else
    echo -e "${YELLOW}⚠ Port 80 (HTTP) nicht offen${NC}"
fi
echo ""

# 8. Backend .env Datei
echo -e "${BLUE}[8/8] Backend .env Konfiguration:${NC}"
if [ -f /opt/wireguard-admin/backend/.env ]; then
    echo -e "${GREEN}✓ .env Datei existiert${NC}"
    echo "Konfiguration:"
    grep -E "^(MONGO_URL|DB_NAME|JWT_SECRET)" /opt/wireguard-admin/backend/.env | sed 's/JWT_SECRET=.*/JWT_SECRET=***HIDDEN***/'
else
    echo -e "${RED}✗ .env Datei nicht gefunden${NC}"
fi
echo ""

# Zusammenfassung
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Zusammenfassung & Empfehlungen:${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

# Check for common issues
ISSUES_FOUND=0

if ! supervisorctl status wireguard-backend 2>/dev/null | grep -q RUNNING; then
    echo -e "${RED}[!] Backend läuft nicht${NC}"
    echo "    Lösung: sudo supervisorctl restart wireguard-backend"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

if ! systemctl is-active --quiet mongod; then
    echo -e "${RED}[!] MongoDB läuft nicht${NC}"
    echo "    Lösung: sudo systemctl start mongod"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

if [ "$BACKEND_RESPONSE" != "200" ]; then
    echo -e "${RED}[!] Backend API nicht erreichbar${NC}"
    echo "    Lösung: Prüfen Sie die Backend-Logs:"
    echo "    sudo tail -f /var/log/wireguard-backend-error.log"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

if [ $ISSUES_FOUND -eq 0 ]; then
    echo -e "${GREEN}✓ Alle grundlegenden Checks bestanden!${NC}"
    echo ""
    echo "Wenn Sie trotzdem Probleme haben:"
    echo "1. Browser-Cache leeren"
    echo "2. Browser-Console öffnen (F12) und Fehler prüfen"
    echo "3. Backend-Logs in Echtzeit ansehen:"
    echo "   sudo tail -f /var/log/wireguard-backend-error.log"
else
    echo ""
    echo -e "${YELLOW}$ISSUES_FOUND Problem(e) gefunden. Beheben Sie diese zuerst.${NC}"
fi

echo ""
echo -e "${BLUE}Für detaillierte Logs:${NC}"
echo "  Backend Errors:  sudo tail -f /var/log/wireguard-backend-error.log"
echo "  Backend Output:  sudo tail -f /var/log/wireguard-backend.log"
echo "  Nginx Errors:    sudo tail -f /var/log/nginx/error.log"
echo "  MongoDB:         sudo journalctl -u mongod -f"
echo ""
