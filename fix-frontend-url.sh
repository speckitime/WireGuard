#!/bin/bash

echo "╔═══════════════════════════════════════════════════╗"
echo "║      Frontend Backend-URL Fix                    ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""

# 1. Aktuelle Config anzeigen
echo "1. Aktuelle Frontend .env:"
cat /opt/wireguard-admin/frontend/.env
echo ""

# 2. Korrigiere die URL
echo "2. Korrigiere Backend-URL..."
echo "   Von: https://43.251.160.244:8001"
echo "   Zu:  https://vpn-dus.leonboldt.de"
echo ""

# Erstelle korrekte .env
cat > /opt/wireguard-admin/frontend/.env << 'EOF'
REACT_APP_BACKEND_URL=https://vpn-dus.leonboldt.de
WDS_SOCKET_PORT=443
REACT_APP_ENABLE_VISUAL_EDITS=false
ENABLE_HEALTH_CHECK=false
EOF

echo "✓ .env aktualisiert"
echo ""
echo "Neue .env:"
cat /opt/wireguard-admin/frontend/.env
echo ""

# 3. Frontend neu bauen
echo "3. Baue Frontend neu (kann 1-2 Minuten dauern)..."
cd /opt/wireguard-admin/frontend
yarn build > /tmp/frontend-build.log 2>&1

if [ $? -eq 0 ]; then
    echo "✓ Frontend-Build erfolgreich"
else
    echo "✗ Frontend-Build fehlgeschlagen"
    echo "Siehe Log: /tmp/frontend-build.log"
    tail -n 20 /tmp/frontend-build.log
    exit 1
fi

# 4. Nginx neu starten
echo ""
echo "4. Starte Nginx neu..."
systemctl restart nginx
echo "✓ Nginx neu gestartet"

# 5. Test
echo ""
echo "5. Teste API über Nginx Reverse Proxy..."
curl -s https://vpn-dus.leonboldt.de/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"finaltest","password":"FinalTest123!"}' | python3 -m json.tool 2>/dev/null

echo ""
echo ""
echo "╔═══════════════════════════════════════════════════╗"
echo "║              FIX ABGESCHLOSSEN!                   ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""
echo "WICHTIG:"
echo "1. Browser-Cache KOMPLETT leeren:"
echo "   - Chrome/Edge: Strg+Shift+Entf → Alles löschen"
echo "   - Firefox: Strg+Shift+Entf → Alles löschen"
echo "   - Oder Inkognito-Modus verwenden"
echo ""
echo "2. Dann öffne: https://vpn-dus.leonboldt.de"
echo ""
echo "3. Registriere deinen Account (lbol + Passwort)"
echo ""
echo "Die Webapp sollte JETZT funktionieren! 🎉"
echo ""
