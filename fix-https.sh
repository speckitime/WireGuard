#!/bin/bash

echo "╔═══════════════════════════════════════════════════╗"
echo "║      HTTPS Mixed Content Fix                     ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""

# 1. Prüfe Frontend .env
echo "1. Prüfe Frontend .env Konfiguration..."
if [ -f /opt/wireguard-admin/frontend/.env ]; then
    echo "Frontend .env Inhalt:"
    cat /opt/wireguard-admin/frontend/.env
    echo ""
    
    BACKEND_URL=$(grep REACT_APP_BACKEND_URL /opt/wireguard-admin/frontend/.env | cut -d'=' -f2)
    
    if echo "$BACKEND_URL" | grep -q "https://"; then
        echo "✓ Frontend verwendet bereits HTTPS"
    else
        echo "✗ Frontend verwendet noch HTTP - muss auf HTTPS geändert werden"
        echo ""
        echo "Ändere auf HTTPS..."
        sed -i 's|http://|https://|g' /opt/wireguard-admin/frontend/.env
        echo "✓ Geändert auf HTTPS"
    fi
else
    echo "✗ Frontend .env nicht gefunden!"
    exit 1
fi

echo ""
echo "2. Aktuelle Frontend .env:"
cat /opt/wireguard-admin/frontend/.env

echo ""
echo "3. Baue Frontend neu mit HTTPS-URL..."
cd /opt/wireguard-admin/frontend
yarn build

echo ""
echo "4. Nginx neu starten..."
systemctl restart nginx

echo ""
echo "5. Browser-Cache leeren und erneut testen!"
echo ""
echo "╔═══════════════════════════════════════════════════╗"
echo "║  WICHTIG: Browser-Cache leeren!                  ║"
echo "║  Strg + Shift + R (oder Strg + F5)              ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""
echo "Dann öffne: https://vpn-dus.leonboldt.de"
echo ""
