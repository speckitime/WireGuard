# Contributing to WireGuard Admin Panel

Vielen Dank für Ihr Interesse, zum WireGuard Admin Panel beizutragen!

## Entwicklungsumgebung einrichten

### Backend

```bash
cd backend
python3.11 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Frontend

```bash
cd frontend
yarn install
yarn start
```

## Code-Stil

### Python (Backend)
- Folgen Sie PEP 8
- Verwenden Sie Type Hints wo möglich
- Schreiben Sie docstrings für Funktionen

```python
def example_function(param: str) -> dict:
    """
    Kurze Beschreibung der Funktion.
    
    Args:
        param: Beschreibung des Parameters
        
    Returns:
        Dictionary mit Ergebnis
    """
    return {"result": param}
```

### JavaScript/React (Frontend)
- Verwenden Sie ES6+ Syntax
- Funktionale Komponenten mit Hooks
- Verwenden Sie Shadcn UI Komponenten

```javascript
const ExampleComponent = ({ data }) => {
  const [state, setState] = useState(null);
  
  return (
    <div data-testid="example-component">
      {/* Component content */}
    </div>
  );
};
```

## Pull Requests

1. Forken Sie das Repository
2. Erstellen Sie einen Feature-Branch (`git checkout -b feature/AmazingFeature`)
3. Committen Sie Ihre Änderungen (`git commit -m 'Add some AmazingFeature'`)
4. Pushen Sie zum Branch (`git push origin feature/AmazingFeature`)
5. Öffnen Sie einen Pull Request

### PR-Checkliste

- [ ] Code folgt dem Projekt-Stil
- [ ] Tests wurden hinzugefügt/aktualisiert (falls zutreffend)
- [ ] Dokumentation wurde aktualisiert
- [ ] Commit-Nachrichten sind aussagekräftig
- [ ] Branch ist auf dem neuesten Stand mit `main`

## Fehler melden

Beim Melden von Fehlern bitte folgende Informationen angeben:

- **Beschreibung**: Klare Beschreibung des Problems
- **Schritte zur Reproduktion**: Wie kann der Fehler reproduziert werden?
- **Erwartetes Verhalten**: Was sollte passieren?
- **Tatsächliches Verhalten**: Was passiert stattdessen?
- **Umgebung**: 
  - OS (z.B. Ubuntu 22.04)
  - Browser (z.B. Chrome 120)
  - Version des Panels
- **Logs**: Relevante Log-Ausgaben

## Feature-Vorschläge

Wir freuen uns über Feature-Vorschläge! Bitte:

1. Überprüfen Sie, ob das Feature nicht bereits vorgeschlagen wurde
2. Beschreiben Sie den Anwendungsfall
3. Erklären Sie, warum das Feature nützlich wäre
4. Schlagen Sie eine mögliche Implementation vor (optional)

## Code-Review-Prozess

- Alle PRs werden von Maintainern überprüft
- Mindestens eine Genehmigung ist erforderlich
- CI/CD-Tests müssen bestehen
- Konstruktives Feedback wird geschätzt

## Verhaltenskodex

- Seien Sie respektvoll und professionell
- Akzeptieren Sie konstruktive Kritik
- Konzentrieren Sie sich auf das Beste für das Projekt
- Zeigen Sie Empathie gegenüber anderen Community-Mitgliedern

## Lizenz

Durch Beiträge stimmen Sie zu, dass Ihre Beiträge unter der MIT-Lizenz lizenziert werden.

## Kontakt

- GitHub Issues: [github.com/speckitime/WireGuard/issues](https://github.com/speckitime/WireGuard/issues)
- Diskussionen: [github.com/speckitime/WireGuard/discussions](https://github.com/speckitime/WireGuard/discussions)

Vielen Dank fürs Beitragen! 🎉
