#!/bin/bash

###############################################################################
# WireGuard Initialisierungs-Fehler Fix
###############################################################################

if [ "$EUID" -ne 0 ]; then 
    echo "Bitte als root ausführen: sudo $0"
    exit 1
fi

echo "╔═══════════════════════════════════════════════════╗"
echo "║  WireGuard Initialisierungs-Fix                  ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""

# 1. Prüfe ob WireGuard installiert ist
echo "1. Prüfe WireGuard-Installation..."
if command -v wg &> /dev/null && command -v wg-quick &> /dev/null; then
    echo "✓ WireGuard ist installiert"
    wg version
else
    echo "✗ WireGuard ist NICHT installiert!"
    echo ""
    echo "Installiere WireGuard..."
    apt update -qq
    apt install -y wireguard wireguard-tools
    echo "✓ WireGuard installiert"
fi

# 2. Prüfe Sudo-Berechtigungen
echo ""
echo "2. Prüfe Sudo-Berechtigungen für www-data..."

if [ ! -f /etc/sudoers.d/wireguard-admin ]; then
    echo "✗ Sudoers-Datei nicht gefunden"
    echo "Erstelle Sudoers-Datei..."
    
    cat > /etc/sudoers.d/wireguard-admin << 'EOF'
# WireGuard Admin Panel Berechtigungen
www-data ALL=(ALL) NOPASSWD: /usr/bin/wg
www-data ALL=(ALL) NOPASSWD: /usr/bin/wg-quick
www-data ALL=(ALL) NOPASSWD: /bin/cp /tmp/wg0.conf /etc/wireguard/wg0.conf
www-data ALL=(ALL) NOPASSWD: /bin/cp /tmp/peer.conf /etc/wireguard/*
www-data ALL=(ALL) NOPASSWD: /bin/chmod 600 /etc/wireguard/*
www-data ALL=(ALL) NOPASSWD: /bin/bash -c cat /tmp/peer.conf >> /etc/wireguard/wg0.conf
www-data ALL=(ALL) NOPASSWD: /bin/mkdir -p /etc/wireguard
EOF
    
    chmod 440 /etc/sudoers.d/wireguard-admin
    echo "✓ Sudoers-Datei erstellt"
else
    echo "✓ Sudoers-Datei existiert"
fi

# 3. Teste Sudo-Berechtigungen
echo ""
echo "3. Teste Sudo-Berechtigungen..."
sudo -u www-data sudo wg version &>/dev/null
if [ $? -eq 0 ]; then
    echo "✓ www-data kann wg ausführen"
else
    echo "✗ www-data kann wg NICHT ausführen"
    echo "Prüfe /etc/sudoers.d/wireguard-admin"
fi

# 4. Erstelle WireGuard-Verzeichnis
echo ""
echo "4. Erstelle WireGuard-Verzeichnis..."
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard
echo "✓ /etc/wireguard erstellt"

# 5. Prüfe Netzwerk-Einstellungen
echo ""
echo "5. Prüfe IP-Forwarding..."
FORWARD=$(sysctl net.ipv4.ip_forward | awk '{print $3}')
if [ "$FORWARD" = "1" ]; then
    echo "✓ IP-Forwarding aktiviert"
else
    echo "✗ IP-Forwarding nicht aktiviert"
    echo "Aktiviere IP-Forwarding..."
    sysctl -w net.ipv4.ip_forward=1
    sysctl -w net.ipv6.conf.all.forwarding=1
    
    # Dauerhaft aktivieren
    if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
        echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
    fi
    echo "✓ IP-Forwarding aktiviert"
fi

# 6. Teste WireGuard-Initialisierung manuell
echo ""
echo "6. Teste WireGuard-Schlüssel-Generierung..."

# Als www-data testen
sudo -u www-data bash << 'EOTEST'
PRIV_KEY=$(wg genkey 2>/dev/null)
if [ $? -eq 0 ] && [ ! -z "$PRIV_KEY" ]; then
    PUB_KEY=$(echo "$PRIV_KEY" | wg pubkey 2>/dev/null)
    if [ $? -eq 0 ] && [ ! -z "$PUB_KEY" ]; then
        echo "✓ Schlüssel-Generierung erfolgreich"
        echo "   Private Key: ${PRIV_KEY:0:10}..."
        echo "   Public Key:  ${PUB_KEY:0:10}..."
    else
        echo "✗ Public Key Generierung fehlgeschlagen"
    fi
else
    echo "✗ Private Key Generierung fehlgeschlagen"
fi
EOTEST

# 7. Backend neu starten
echo ""
echo "7. Starte Backend neu..."
supervisorctl restart wireguard-backend
sleep 3

# 8. Prüfe Backend-Status
echo ""
echo "8. Prüfe Backend-Status..."
supervisorctl status wireguard-backend

# 9. Teste Server-Init API
echo ""
echo "9. Teste Server-Initialisierung über API..."
echo "   (Verwende einen Test-Token)"

# Erstelle Test-User und hole Token
RESPONSE=$(curl -s -X POST http://localhost:8001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"wgtest_'$(date +%s)'","password":"Test123!"}')

TOKEN=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null)

if [ ! -z "$TOKEN" ]; then
    echo "✓ Test-Token erhalten"
    
    # Teste Server-Init
    echo ""
    echo "Teste /api/wg/server/init..."
    INIT_RESPONSE=$(curl -s -X POST http://localhost:8001/api/wg/server/init \
      -H "Authorization: Bearer $TOKEN")
    
    echo "$INIT_RESPONSE" | python3 -m json.tool 2>/dev/null
    
    if echo "$INIT_RESPONSE" | grep -q "public_key"; then
        echo ""
        echo "✓ Server-Initialisierung erfolgreich!"
    else
        echo ""
        echo "✗ Server-Initialisierung fehlgeschlagen"
        echo ""
        echo "Fehler-Details:"
        echo "$INIT_RESPONSE"
    fi
else
    echo "✗ Konnte Test-Token nicht erhalten"
fi

echo ""
echo "═══════════════════════════════════════════════════"
echo "Fix abgeschlossen!"
echo ""
echo "Nächste Schritte:"
echo "1. Im Browser: https://vpn-dus.leonboldt.de"
echo "2. Anmelden"
echo "3. 'Server initialisieren' klicken"
echo ""
echo "Falls es immer noch nicht funktioniert:"
echo "  sudo tail -f /var/log/wireguard-backend-error.log"
echo ""
