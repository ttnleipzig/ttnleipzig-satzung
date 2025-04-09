#!/bin/bash

# Name der Changelog-Datei
CHANGELOG_FILE="../CHANGELOG.md"

# Header für die Changelog-Datei
echo "# Veränderungshistorie" > $CHANGELOG_FILE
echo "" >> $CHANGELOG_FILE
echo "Alle Änderungen zum Satzung werden in dieser Datei dokumentiert." >> $CHANGELOG_FILE
echo "" >> $CHANGELOG_FILE

# OpenAI API-Schlüssel aus Umgebungsvariable
OPENAI_API_KEY=$OPENAI_API_KEY

# Funktion zur Übersetzung von Text über die OpenAI API
translate_to_simple_german() {
    local text="$1"
    
    # Verwende curl, um die OpenAI API anzusprechen
    response=$(curl -s -w "%{http_code}" -X POST https://api.openai.com/v1/chat/completions \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -d '{
            "model": "gpt-4",
            "messages": [{"role": "system", "content": "Du bist ein Übersetzer, der Texte in leicht verständliches Deutsch übersetzt."}, {"role": "user", "content": "'"$text"'"}],
            "max_tokens": 1000,
            "temperature": 0.5
        }')

    # Extrahiere den HTTP-Statuscode und die JSON-Antwort getrennt
    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | head -n -1)

    # Überprüfe, ob die Antwort erfolgreich war (HTTP 200 OK)
    if [[ "$http_code" -ne 200 ]]; then
        echo "Fehler bei der Kommunikation mit der OpenAI API (HTTP $http_code). Bitte überprüfe den API-Schlüssel oder die Netzwerkverbindung."
        exit 1
    fi

    # Extrahiere die Antwort (Übersetzung) aus der JSON-Antwort
    translated_text=$(echo "$response_body" | jq -r '.choices[0].message.content')

    echo "$translated_text"
}

# Alle Git-Tags abrufen und durchgehen (sortiert nach dem Tag-Namen)
git tag --sort=v:refname | while read tag
do
    # Das Veröffentlichungsdatum des Tags abfragen
    DATE=$(git log -1 --format=%ai $tag | cut -d ' ' -f 1)

    # Beginnt einen neuen Abschnitt für jedes Tag
    echo "## [$tag] - $DATE" >> $CHANGELOG_FILE
    echo "" >> $CHANGELOG_FILE

    # Finde alle Commits für das Tag und filtere die semantischen Commit-Nachrichten
    commits=$(git log $tag^..$tag --oneline --pretty=format:"%s")
    
    if [ -z "$commits" ]; then
        # Keine Commits gefunden, übersetze die Warnmeldung
        warning_message="WARNUNG: Keine Commit-Nachrichten für Tag $tag gefunden!"
        translated_warning=$(translate_to_simple_german "$warning_message")
        echo "$translated_warning" >> $CHANGELOG_FILE        
    else
        # Durch alle Commits iterieren und die semantischen Nachrichten filtern
        echo "$commits" | while read commit
        do
            # Prüft, ob der Commit semantisch ist (z.B. feat:, fix:, docs:)
            if [[ "$commit" =~ ^(feat|fix|docs|chore|refactor|style|test)\(.*\):.* ]]; then
                # Übersetze die Commit-Nachricht
                translated_commit=$(translate_to_simple_german "$commit")
                # Fügt den übersetzten Commit zur Changelog-Datei hinzu
                echo "- $translated_commit" >> $CHANGELOG_FILE
            fi
        done
    fi

    echo "" >> $CHANGELOG_FILE
done

echo "Changelog wurde in $CHANGELOG_FILE erstellt."
