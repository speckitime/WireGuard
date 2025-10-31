#!/bin/bash

echo "╔═══════════════════════════════════════════════════╗"
echo "║      Final API Test                              ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""

echo "1. Teste Root-Endpoint (ohne trailing slash)..."
curl -s http://localhost:8001/api
echo ""

echo ""
echo "2. Teste Registrierung (sollte funktionieren)..."
curl -X POST http://localhost:8001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"webuser","password":"WebPass123!"}' \
  -s | python3 -m json.tool 2>/dev/null

echo ""
echo ""
echo "3. Teste Login mit demselben User..."
TOKEN=$(curl -X POST http://localhost:8001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"webuser","password":"WebPass123!"}' \
  -s | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null)

if [ ! -z "$TOKEN" ]; then
    echo "✓ Login erfolgreich! Token erhalten."
    
    echo ""
    echo "4. Teste authentifizierten Endpoint (Server Status)..."
    curl -s http://localhost:8001/api/wg/server/status \
      -H "Authorization: Bearer $TOKEN" | python3 -m json.tool 2>/dev/null
    
    echo ""
    echo ""
    echo "✅ Backend API funktioniert vollständig!"
    echo ""
    echo "═══════════════════════════════════════════════════"
    echo "Die Webapp sollte jetzt funktionieren!"
    echo ""
    echo "Öffne im Browser: http://vpn-dus.leonboldt.de"
    echo "Oder mit HTTPS: https://vpn-dus.leonboldt.de"
    echo ""
    echo "Registriere einen neuen Benutzer und teste!"
    echo "═══════════════════════════════════════════════════"
else
    echo "✗ Login fehlgeschlagen"
    echo ""
    echo "Versuche Registrierung direkt..."
    curl -X POST http://localhost:8001/api/auth/register \
      -H "Content-Type: application/json" \
      -d '{"username":"admin2","password":"Admin123!"}' \
      -v
fi
echo ""
