#!/bin/bash

# Quick Fix für Backend API 404 Problem

echo "Fixe Backend API Problem..."

# 1. Teste Backend direkt
echo "1. Teste Backend direkt auf Port 8001..."
RESPONSE=$(curl -s http://localhost:8001/api/ 2>&1)
echo "Response: $RESPONSE"

if echo "$RESPONSE" | grep -q "Hello World"; then
    echo "✓ Backend API funktioniert auf Port 8001"
else
    echo "✗ Backend API gibt keinen korrekten Response"
    echo ""
    echo "Teste ohne /api prefix..."
    RESPONSE2=$(curl -s http://localhost:8001/ 2>&1)
    echo "Response: $RESPONSE2"
fi

echo ""
echo "2. Prüfe Nginx Konfiguration..."
if [ -f /etc/nginx/sites-available/wireguard-admin ]; then
    echo "Nginx Config gefunden. Prüfe Proxy-Einstellungen..."
    grep -A5 "location /api" /etc/nginx/sites-available/wireguard-admin
else
    echo "✗ Nginx Config nicht gefunden"
fi

echo ""
echo "3. Prüfe ob Backend wirklich auf 0.0.0.0:8001 läuft..."
ss -tlnp | grep :8001 || netstat -tlnp | grep :8001

echo ""
echo "4. Teste mit curl und Verbose..."
curl -v http://localhost:8001/api/ 2>&1 | head -20

echo ""
echo "====================================="
echo "Führe folgende Befehle aus um zu fixen:"
echo ""
echo "# Backend neu starten"
echo "sudo supervisorctl restart wireguard-backend"
echo ""
echo "# Nginx testen und neu starten"  
echo "sudo nginx -t"
echo "sudo systemctl restart nginx"
echo ""
echo "# Dann erneut testen"
echo "curl http://localhost:8001/api/"
echo ""
