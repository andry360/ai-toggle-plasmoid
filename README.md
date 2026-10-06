# AI Toggle — Plasma 6 widget

A small KDE Plasma 6 widget that shows whether your local AI stack is running, lets you start/stop it with a single click, and displays the VRAM currently in use (in MB).

- Green pill with a pulsing dot = AI running; grey = stopped.
- Click = `systemctl --user start|stop ai.target`.
- The state is polled every 2 seconds, so the widget stays in sync even if the AI stack is started or stopped by other means (shell aliases, terminal, etc.).
- VRAM is read from `/sys/class/drm/card*/device/mem_info_vram_used` (AMD GPUs with the amdgpu driver; the GPU with the most VRAM is selected). The tooltip also shows the total.

## Requirements

- KDE Plasma 6 (tested on 6.7)
- `kpackagetool6` (shipped with Plasma)
- A systemd user unit named `ai.target` that groups your AI services (e.g. an inference server and a web UI, each declaring `PartOf=ai.target`)
- A GPU exposing `mem_info_vram_used` in sysfs (amdgpu). On NVIDIA the value will not show up: adapt the command in `main.qml`.

## Installation

```sh
git clone <REPO-URL> ai-toggle-plasmoid
cd ai-toggle-plasmoid
./install.sh
```

Then: right-click the panel → **Add Widgets…** → search for **AI Toggle** → drag it onto the panel or desktop.

If it doesn't appear in the list, restart the shell:

```sh
kquitapp6 plasmashell && kstart plasmashell
```

The widget is installed to `~/.local/share/plasma/plasmoids/org.andry.aitoggle/`.

## Updating

After a `git pull`, run `./install.sh` again (it performs an upgrade). If the change isn't visible, restart plasmashell as shown above.

## Uninstalling

```sh
./uninstall.sh
```

## Trying it without adding it to a panel

```sh
plasmawindowed org.andry.aitoggle
```

## Customization

Everything lives in `contents/ui/main.qml`:

- controlled unit: search for `ai.target`
- refresh interval: `interval: 2000` (ms)
- "on" color: `onColor`

## License

MIT
