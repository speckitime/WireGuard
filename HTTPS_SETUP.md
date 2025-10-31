# HTTPS/SSL Setup für WireGuard Admin Panel

## Automatische SSL-Einrichtung während Installation

Das `install.sh` Skript bietet automatische HTTPS-Einrichtung mit Let's Encrypt:

```bash
sudo ./install.sh
```

Wählen Sie bei der Frage "SSL mit Let's Encrypt einrichten?" **y** (ja).

## Voraussetzungen für SSL

1. **Domain-Name**: Sie benötigen eine Domain (z.B. vpn-dus.leonboldt.de)
2. **DNS konfiguriert**: Ihre Domain muss auf die Server-IP zeigen
3. **Port 80 offen**: Let's Encrypt benötigt Port 80 für die Validierung
4. **Port 443 offen**: HTTPS läuft auf Port 443

## DNS-Konfiguration überprüfen

Stellen Sie sicher, dass Ihre Domain auf den Server zeigt:

```bash
# Testen Sie die DNS-Auflösung
nslookup vpn-dus.leonboldt.de

# oder mit dig
dig vpn-dus.leonboldt.de +short
```

Das Ergebnis sollte Ihre Server-IP (43.251.160.244) anzeigen.

## Manuelle SSL-Einrichtung (nach Installation)

Falls Sie SSL während der Installation übersprungen haben:

### Schritt 1: Certbot installieren

```bash
sudo apt install -y certbot python3-certbot-nginx
```

### Schritt 2: SSL-Zertifikat erhalten

```bash
sudo certbot --nginx -d vpn-dus.leonboldt.de
```

Folgen Sie den Prompts:
- Geben Sie Ihre E-Mail-Adresse ein
- Akzeptieren Sie die Nutzungsbedingungen
- Wählen Sie, ob HTTP-Traffic auf HTTPS umgeleitet werden soll (empfohlen: ja)

### Schritt 3: Frontend-Konfiguration aktualisieren

```bash
# Bearbeiten Sie die Frontend .env Datei
sudo nano /opt/wireguard-admin/frontend/.env
```

Ändern Sie:
```
REACT_APP_BACKEND_URL=http://43.251.160.244:8001
```

zu:
```
REACT_APP_BACKEND_URL=https://vpn-dus.leonboldt.de
```

### Schritt 4: Frontend neu bauen

```bash
cd /opt/wireguard-admin/frontend
yarn build
sudo systemctl restart nginx
```

## Automatische Zertifikatserneuerung

Certbot richtet automatische Erneuerung ein. Überprüfen Sie:

```bash
# Timer-Status prüfen
sudo systemctl status certbot.timer

# Manuelle Erneuerung testen
sudo certbot renew --dry-run
```

## Firewall-Konfiguration für HTTPS

```bash
# Port 443 öffnen
sudo ufw allow 443/tcp

# Optional: HTTP zu HTTPS umleiten
sudo ufw allow 80/tcp
```

## Nginx-Konfiguration überprüfen

Nach SSL-Setup sollte Ihre Nginx-Konfiguration etwa so aussehen:

```bash
sudo cat /etc/nginx/sites-available/wireguard-admin
```

Beispiel-Konfiguration:

```nginx
server {
    listen 80;
    server_name vpn-dus.leonboldt.de;
    
    # HTTP zu HTTPS umleiten
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name vpn-dus.leonboldt.de;

    # SSL-Zertifikate (von certbot verwaltet)
    ssl_certificate /etc/letsencrypt/live/vpn-dus.leonboldt.de/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/vpn-dus.leonboldt.de/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # Frontend
    root /opt/wireguard-admin/frontend/build;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Backend API Proxy
    location /api {
        proxy_pass http://localhost:8001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Backend HTTPS-Unterstützung

Das Backend läuft intern auf HTTP (localhost:8001). Nginx fungiert als Reverse Proxy und terminiert SSL.

Falls Sie das Backend direkt über HTTPS zugänglich machen möchten:

### Backend .env erweitern

```bash
sudo nano /opt/wireguard-admin/backend/.env
```

Fügen Sie hinzu:
```
CORS_ORIGINS="https://vpn-dus.leonboldt.de"
```

### Backend neu starten

```bash
sudo supervisorctl restart wireguard-backend
```

## Troubleshooting

### Problem: Certbot schlägt fehl

**Lösung 1**: DNS überprüfen
```bash
dig vpn-dus.leonboldt.de +short
# Sollte Ihre Server-IP zeigen
```

**Lösung 2**: Port 80 freigeben
```bash
sudo ufw allow 80/tcp
sudo systemctl stop nginx
sudo certbot certonly --standalone -d vpn-dus.leonboldt.de
sudo systemctl start nginx
```

**Lösung 3**: Alte Zertifikate entfernen
```bash
sudo certbot delete --cert-name vpn-dus.leonboldt.de
sudo certbot --nginx -d vpn-dus.leonboldt.de
```

### Problem: "Mixed Content" Fehler im Browser

Das bedeutet, die Frontend-Seite (HTTPS) versucht, auf HTTP-Ressourcen zuzugreifen.

**Lösung**: Backend-URL in Frontend .env auf HTTPS ändern
```bash
sudo nano /opt/wireguard-admin/frontend/.env
# Ändere http:// zu https://
cd /opt/wireguard-admin/frontend
yarn build
sudo systemctl restart nginx
```

### Problem: SSL-Zertifikat läuft ab

Certbot erneuert automatisch. Manuell erneuern:
```bash
sudo certbot renew
sudo systemctl restart nginx
```

### Problem: Backend über HTTPS nicht erreichbar

Überprüfen Sie die Nginx-Proxy-Konfiguration:
```bash
sudo nginx -t
sudo systemctl restart nginx
sudo tail -f /var/log/nginx/error.log
```

## HSTS (HTTP Strict Transport Security) aktivieren

Für zusätzliche Sicherheit HSTS aktivieren:

```bash
sudo nano /etc/nginx/sites-available/wireguard-admin
```

Im `server` Block (Port 443) hinzufügen:
```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

Nginx neu starten:
```bash
sudo nginx -t
sudo systemctl restart nginx
```

## SSL-Labs Test

Testen Sie Ihre SSL-Konfiguration:

https://www.ssllabs.com/ssltest/analyze.html?d=vpn-dus.leonboldt.de

Ziel: **A oder A+ Rating**

## Zertifikat-Informationen anzeigen

```bash
# Zertifikat-Details
sudo certbot certificates

# Ablaufdatum prüfen
sudo openssl x509 -in /etc/letsencrypt/live/vpn-dus.leonboldt.de/cert.pem -noout -dates
```

## Backup der Zertifikate

```bash
# Zertifikate sichern
sudo tar -czf /backup/letsencrypt-$(date +%Y%m%d).tar.gz /etc/letsencrypt

# Restore (falls nötig)
sudo tar -xzf /backup/letsencrypt-20250131.tar.gz -C /
sudo systemctl restart nginx
```

## Wildcard-Zertifikat (Optional)

Für mehrere Subdomains:

```bash
sudo certbot certonly --dns-cloudflare \
  -d vpn-dus.leonboldt.de \
  -d *.vpn-dus.leonboldt.de
```

(Benötigt DNS-Provider-Integration)

## Let's Encrypt Rate Limits

- **50 Zertifikate pro Domain pro Woche**
- **5 fehlgeschlagene Validierungen pro Stunde**

Bei Problemen: Testen Sie zuerst mit `--dry-run`

```bash
sudo certbot --nginx -d vpn-dus.leonboldt.de --dry-run
```

## Support

- Let's Encrypt Dokumentation: https://letsencrypt.org/docs/
- Certbot Dokumentation: https://certbot.eff.org/
- Nginx SSL Guide: https://nginx.org/en/docs/http/configuring_https_servers.html
