#!/bin/bash

###############################################################################
# Backend-Fix: Supervisor-Konfiguration und Backend-Neustart
###############################################################################

if [ "$EUID" -ne 0 ]; then 
    echo "Bitte als root ausführen: sudo $0"
    exit 1
fi

echo "╔═══════════════════════════════════════════════════╗"
echo "║      Backend API 404 Fix                         ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""

# 1. Backend stoppen
echo "1. Stoppe Backend..."
supervisorctl stop wireguard-backend

# 2. Prüfe Supervisor-Konfiguration
echo "2. Prüfe Supervisor-Konfiguration..."
if [ -f /etc/supervisor/conf.d/wireguard-backend.conf ]; then
    echo "✓ Supervisor Config gefunden"
    
    # Zeige aktuelle Config
    echo "Aktuelle Konfiguration:"
    cat /etc/supervisor/conf.d/wireguard-backend.conf
else
    echo "✗ Supervisor Config nicht gefunden!"
    exit 1
fi

echo ""
echo "3. Teste Backend manuell..."

# Wechsle zum Backend-Verzeichnis und teste
cd /opt/wireguard-admin/backend
source ../venv/bin/activate

# Prüfe ob server.py existiert
if [ ! -f server.py ]; then
    echo "✗ server.py nicht gefunden!"
    exit 1
fi

echo "✓ server.py gefunden"

# Teste Import
echo "Teste Python-Imports..."
timeout 5 python3 -c "from server import app; print('✓ Import erfolgreich')" 2>&1

echo ""
echo "4. Starte Backend über Supervisor neu..."
supervisorctl start wireguard-backend

sleep 3

# 5. Prüfe Status
echo ""
echo "5. Prüfe Backend-Status..."
supervisorctl status wireguard-backend

echo ""
echo "6. Teste API..."
sleep 2
curl -s http://localhost:8001/api/ && echo "" || echo "✗ API nicht erreichbar"

echo ""
echo "7. Teste Registrierung..."
curl -X POST http://localhost:8001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"TestPass123!"}' \
  -s | python3 -m json.tool 2>/dev/null || echo "Backend-Response erhalten (möglicherweise Fehler)"

echo ""
echo "═══════════════════════════════════════════════════"
echo "Backend-Fix abgeschlossen!"
echo ""
echo "Teste jetzt im Browser: http://vpn-dus.leonboldt.de"
echo ""
echo "Falls es immer noch nicht funktioniert, prüfe die Logs:"
echo "  sudo tail -f /var/log/wireguard-backend-error.log"
echo ""
