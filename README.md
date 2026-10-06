# AI Toggle — widget Plasma 6

Piccolo widget per KDE Plasma 6 che mostra se l'AI locale è attiva, permette di accenderla/spegnerla con un click e mostra la VRAM usata in MB.

- Pillola verde con pallino pulsante = AI accesa; grigia = spenta.
- Click = `systemctl --user start|stop ai.target`.
- Lo stato viene riletto ogni 2 secondi, quindi si aggiorna anche se l'AI viene accesa/spenta da altro (`ai-on`, `ai-off`, terminale…).
- VRAM letta da `/sys/class/drm/card*/device/mem_info_vram_used` (GPU AMD con driver amdgpu; viene scelta la GPU con più VRAM). Il tooltip mostra anche il totale.

## Requisiti

- KDE Plasma 6 (testato su 6.7)
- `kpackagetool6` (incluso in Plasma)
- Un'unità utente systemd chiamata `ai.target` che raggruppa i servizi AI (nel mio caso `llama-swap` + `open-webui`, con `PartOf=ai.target`)
- GPU che espone `mem_info_vram_used` in sysfs (amdgpu). Con NVIDIA il valore non comparirà: va adattato il comando in `main.qml`.

## Installazione

```sh
git clone <URL-DEL-REPO> ai-toggle-plasmoid
cd ai-toggle-plasmoid
./install.sh
```

Poi: tasto destro sul pannello → **Aggiungi widget…** → cerca **AI Toggle** → trascinalo sul pannello o sul desktop.

Se non compare nell'elenco, riavvia la shell:

```sh
kquitapp6 plasmashell && kstart plasmashell
```

Il widget viene installato in `~/.local/share/plasma/plasmoids/org.andry.aitoggle/`.

## Aggiornamento

Dopo un `git pull` rilancia `./install.sh` (fa l'upgrade). Se la modifica non si vede, riavvia plasmashell come sopra.

## Disinstallazione

```sh
./uninstall.sh
```

## Prova senza aggiungerlo al pannello

```sh
plasmawindowed org.andry.aitoggle
```

## Personalizzazione

Tutto è in `contents/ui/main.qml`:

- servizio controllato: cerca `ai.target`
- intervallo di aggiornamento: `interval: 2000` (ms)
- colore "acceso": `onColor`

## Licenza

MIT
