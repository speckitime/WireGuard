#!/bin/bash

echo "╔═══════════════════════════════════════════════════╗"
echo "║      HTTPS Konfiguration Prüfen                  ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""

# 1. SSL-Zertifikat prüfen
echo "1. SSL-Zertifikat Status:"
if [ -d /etc/letsencrypt/live/vpn-dus.leonboldt.de ]; then
    echo "✓ SSL-Zertifikat für vpn-dus.leonboldt.de existiert"
    
    # Ablaufdatum prüfen
    EXPIRY=$(openssl x509 -in /etc/letsencrypt/live/vpn-dus.leonboldt.de/cert.pem -noout -enddate 2>/dev/null | cut -d= -f2)
    if [ ! -z "$EXPIRY" ]; then
        echo "  Läuft ab: $EXPIRY"
    fi
else
    echo "✗ Kein SSL-Zertifikat gefunden"
    echo ""
    echo "SSL muss eingerichtet werden:"
    echo "  sudo certbot --nginx -d vpn-dus.leonboldt.de"
    exit 1
fi

echo ""
echo "2. Nginx HTTPS Konfiguration:"
if grep -q "listen 443 ssl" /etc/nginx/sites-available/wireguard-admin 2>/dev/null; then
    echo "✓ Nginx ist für HTTPS konfiguriert"
else
    echo "✗ Nginx ist NICHT für HTTPS konfiguriert"
fi

echo ""
echo "3. Nginx Config anzeigen:"
grep -A10 "listen 443" /etc/nginx/sites-available/wireguard-admin 2>/dev/null || echo "Keine HTTPS-Konfiguration gefunden"

echo ""
echo "4. Frontend .env Backend URL:"
if [ -f /opt/wireguard-admin/frontend/.env ]; then
    grep REACT_APP_BACKEND_URL /opt/wireguard-admin/frontend/.env
    
    if grep REACT_APP_BACKEND_URL /opt/wireguard-admin/frontend/.env | grep -q "https://"; then
        echo "✓ Frontend nutzt HTTPS"
    else
        echo "✗ Frontend nutzt noch HTTP - MUSS geändert werden!"
    fi
fi

echo ""
echo "5. Backend .env CORS:"
if [ -f /opt/wireguard-admin/backend/.env ]; then
    grep CORS_ORIGINS /opt/wireguard-admin/backend/.env
fi

echo ""
echo "6. Teste HTTPS-Verbindung:"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://vpn-dus.leonboldt.de 2>/dev/null)
if [ "$STATUS" = "200" ]; then
    echo "✓ HTTPS lädt erfolgreich (HTTP $STATUS)"
elif [ "$STATUS" = "301" ] || [ "$STATUS" = "302" ]; then
    echo "⚠ HTTPS leitet um (HTTP $STATUS)"
else
    echo "✗ HTTPS funktioniert nicht (HTTP $STATUS)"
fi

echo ""
echo "7. Teste HTTP -> HTTPS Weiterleitung:"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -L http://vpn-dus.leonboldt.de 2>/dev/null)
echo "HTTP Status: $HTTP_STATUS"

echo ""
echo "═══════════════════════════════════════════════════"
echo "Empfohlene Schritte:"
echo ""
echo "1. Falls Frontend .env noch HTTP verwendet:"
echo "   sudo ./fix-https.sh"
echo ""
echo "2. Browser-Test mit geöffneter Console (F12):"
echo "   - Öffne https://vpn-dus.leonboldt.de"
echo "   - Prüfe Console auf 'Mixed Content' Fehler"
echo "   - Prüfe Network-Tab auf fehlgeschlagene API-Calls"
echo ""
echo "3. Falls Mixed Content Fehler:"
echo "   Problem: Frontend (HTTPS) → Backend (HTTP)"
echo "   Lösung: Backend-URL in Frontend .env auf HTTPS ändern"
echo ""
