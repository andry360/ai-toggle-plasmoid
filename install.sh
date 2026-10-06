#!/bin/sh
# Installa (o aggiorna) il widget per l'utente corrente.
set -e
cd "$(dirname "$0")"
if kpackagetool6 -t Plasma/Applet --show org.andry.aitoggle >/dev/null 2>&1; then
    kpackagetool6 -t Plasma/Applet --upgrade .
else
    kpackagetool6 -t Plasma/Applet --install .
fi
echo "Fatto. Tasto destro sul pannello -> Aggiungi widget -> 'AI Toggle'."
