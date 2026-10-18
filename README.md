# AI Toggle — widget Plasma 6

Piccolo widget per KDE Plasma 6 che mostra lo stato dell'AI locale, permette di accenderla/spegnerla con un click e mostra quanta memoria sta usando e quanto contesto resta.

## Cosa mostra

**Prima riga: stato** (colore del pallino e del bordo)

| Testo | Colore | Significato |
|---|---|---|
| AI disattivo | grigio | `ai.target` spento |
| AI in avvio… / in spegnimento… | giallo, pulsa | systemd sta avviando/fermando, oppure llama-swap o Open WebUI non rispondono ancora |
| AI pronto | verde | tutto acceso, nessun modello in memoria (si carica alla prima domanda) |
| Carico &lt;modello&gt;… | blu, pulsa | llama-swap sta caricando il modello |
| AI · &lt;modello&gt; | verde (pulsa mentre genera) | modello caricato e pronto |

**Seconda riga: memoria e contesto**

- `VRAM: 10.965 MB` — VRAM usata dalla GPU con più memoria.
- `Ctx 7.1k/32k` — token occupati nella conversazione attuale rispetto al contesto massimo (`-c`). Diventa **giallo oltre il 75%** e **rosso oltre il 90%**: oltre il 100% il modello non riesce più a "vedere" l'inizio della chat.
- `RAM-GPU 1.200 MB` (arancione, solo se > 512 MB) — RAM di sistema usata dalla GPU (GTT) perché la VRAM non basta: tutto rallenta.

**Tooltip (passa il mouse)**: per ogni GPU VRAM usata/totale e GTT; RAM usata da `llama-server` (pesi caricati in RAM, esperti MoE con `--n-cpu-moe`); stato di llama-swap e Open WebUI; contesto in token e contesto massimo supportato dal modello; minuti dopo cui llama-swap scarica il modello inattivo.

**Click sinistro**: `systemctl --user start|stop ai.target`. **Click centrale**: apre Open WebUI (`http://127.0.0.1:8080`).

Lo stato viene riletto ogni 2 secondi, quindi si aggiorna anche se l'AI viene accesa/spenta da altro (`ai-on`, `ai-off`, terminale…).

### Da dove vengono i dati

- `contents/code/poll.sh` (ogni 2 s): stato di `ai.target`, memoria GPU da `/sys/class/drm/card*/device/mem_info_{vram,gtt}_*`, RAM di `llama-server` da `/proc`. Costo: ~5 ms con AI spenta, ~12 ms con AI accesa.
- Richieste HTTP fatte direttamente dal widget, solo con AI accesa: llama-swap `/running` (modello e stato), `/upstream/<modello>/slots` (token usati), `/upstream/<modello>/v1/models` (contesto massimo del modello, una volta per modello) e Open WebUI `/health`.

## Requisiti

- KDE Plasma 6 (testato su 6.7)
- `kpackagetool6` (incluso in Plasma)
- Un'unità utente systemd chiamata `ai.target` che raggruppa i servizi AI (nel mio caso `llama-swap` + `open-webui`, con `PartOf=ai.target`)
- GPU che espone `mem_info_vram_used` in sysfs (amdgpu, anche integrate). Con NVIDIA la memoria non comparirà: va adattato `poll.sh`.
- Opzionali: llama-swap su `127.0.0.1:9292` e Open WebUI su `127.0.0.1:8080` (per modello, contesto e stato "pronto"). Senza, il widget resta su "in avvio…" ma mostra comunque la VRAM.

## Installazione

```sh
git clone <URL-DEL-REPO> ai-toggle-plasmoid
cd ai-toggle-plasmoid
./install.sh
```

`install.sh` copia soltanto il widget in `~/.local/share/plasma/plasmoids/org.andry.aitoggle/`: **non lo mette sul pannello**. Va aggiunto a mano una sola volta:

1. tasto destro su uno spazio vuoto del pannello → **Aggiungi o gestisci widget…** (o **Aggiungi widget…**)
2. nella ricerca scrivi **AI Toggle**
3. trascinalo nel punto del pannello (o del desktop) che preferisci, oppure doppio clic per aggiungerlo in fondo

Se non compare nella ricerca, riavvia la shell e riprova:

```sh
kquitapp6 plasmashell && kstart plasmashell
```

## Aggiornamento

Dopo un `git pull` (o una modifica ai file) rilancia `./install.sh`: fa l'upgrade del widget già installato. Poi riavvia plasmashell con il comando sopra per caricare la nuova versione: il widget resta dov'era sul pannello, non serve riaggiungerlo.

## Problemi comuni

- **Ho riavviato plasmashell ma non vedo il widget** → non è ancora stato aggiunto al pannello: vedi i 3 passi di *Installazione*. Il riavvio aggiorna solo un widget già presente.
- **Non compare nella ricerca dei widget** → controlla che sia installato: `kpackagetool6 -t Plasma/Applet --show org.andry.aitoggle`. Se dice che non esiste, rilancia `./install.sh`.
- **Resta su "AI in avvio…"** → llama-swap (porta 9292) o Open WebUI (porta 8080) non rispondono: `systemctl --user status llama-swap open-webui`. Se uno è `failed`: `systemctl --user reset-failed` e riaccendi.
- **VRAM: —** → la GPU non espone `mem_info_vram_used` (es. NVIDIA): va adattato `contents/code/poll.sh`.
- **Errori del widget** → avvialo in una finestra a parte e leggi gli errori nel terminale: `plasmawindowed org.andry.aitoggle`.

## Disinstallazione

```sh
./uninstall.sh
```

## Prova senza aggiungerlo al pannello

```sh
plasmawindowed org.andry.aitoggle
```

## Personalizzazione

In `contents/ui/main.qml`:

- servizio controllato: cerca `ai.target` (anche in `contents/code/poll.sh`)
- indirizzi: `swapUrl`, `webuiUrl`
- intervallo di aggiornamento: `interval: 2000` (ms)
- soglia avviso RAM-GPU: `gttWarnMB`; soglie contesto: `ctxColor()`
- colori: `onColor`, `warnColor`, `loadColor`, `dangerColor`, `spillColor`

## Licenza

MIT
