#!/bin/bash
# Sets up Outlook (Office 365 Web App) as an installed, app-like window,
# and opens Thunderbird's account wizard so you can add the same account
# there for a true native/offline mail client.
#
# Note: there is no official native Linux build of Outlook. This gives you
# the closest practical equivalent: OWA running in its own app window
# (no address bar / tabs), plus Thunderbird as a real native alternative.

echo "=== Outlook opsætning ==="
echo ""
echo "1) Åbner Outlook Web App i eget vindue (log ind med dit O365-login)..."
firefox-esr --new-window "https://outlook.office.com/mail/" &

sleep 2

echo ""
echo "TIP: I Firefox kan du klikke menuen (☰) -> 'Installer denne side som en app'"
echo "     så får du et fast ikon der åbner Outlook uden adresselinje/faner,"
echo "     ligesom en almindelig app."
echo ""
echo "2) Åbner Thunderbird, så du kan tilføje den samme O365-konto som en"
echo "   rigtig native mailklient (virker også offline)..."
sleep 2
thunderbird &

echo ""
echo "Færdig. Du behøver kun køre dette script én gang."
echo "Tryk Enter for at lukke dette vindue."
read -r _
