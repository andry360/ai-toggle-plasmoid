# AI Toggle — Plasma 6 widget

A small KDE Plasma 6 widget that shows the state of your local AI, turns it on or off with
one click, and shows how much memory it uses and how much context is left.

## What it shows

**First line: state** (color of the dot and the border)

| Text | Color | Meaning |
|---|---|---|
| AI off | gray | `ai.target` is stopped |
| AI starting… / AI stopping… | yellow, pulsing | systemd is starting or stopping it, or llama-swap or Open WebUI do not answer yet |
| AI ready | green | everything is on, no model in memory (it loads on the first request) |
| Loading &lt;model&gt;… | blue, pulsing | llama-swap is loading the model |
| AI · &lt;model&gt; | green (pulses while generating) | model loaded and ready |

**Second line: memory and context**

- `VRAM: 10,965 MB` — VRAM used by the GPU with the most memory.
- `Ctx 7.1k/32k` — tokens used by the current conversation compared with the maximum
  context (`-c`). It turns **yellow above 75%** and **red above 90%**: above 100% the model
  can no longer "see" the start of the chat.
- `RAM-GPU 1,200 MB` (orange, only above 512 MB) — system RAM used by the GPU (GTT)
  because the VRAM is not enough: everything slows down.

**Tooltip (hover)**: VRAM used/total and GTT for each GPU; RAM used by `llama-server`
(weights loaded in RAM, MoE experts with `--n-cpu-moe`); llama-swap and Open WebUI state;
context in tokens and the maximum context the model supports; minutes after which
llama-swap unloads the idle model.

**Left click**: `systemctl --user start|stop ai.target`. **Middle click**: opens Open
WebUI (`http://127.0.0.1:8080`).

The state is read again every 2 seconds, so it also updates when the AI is turned on or
off by something else (scripts, the terminal…).

### Where the data comes from

- `contents/code/poll.sh` (every 2 s): `ai.target` state, GPU memory from
  `/sys/class/drm/card*/device/mem_info_{vram,gtt}_*`, `llama-server` RAM from `/proc`.
  Cost: about 5 ms with the AI off, about 12 ms with the AI on.
- HTTP requests made by the widget itself, only while the AI is on: llama-swap
  `/running` (model and state), `/upstream/<model>/slots` (tokens used),
  `/upstream/<model>/v1/models` (the model's maximum context, once per model), and Open
  WebUI `/health`.

## Requirements

- KDE Plasma 6 (tested on 6.7)
- `kpackagetool6` (included in Plasma)
- A systemd user unit called `ai.target` that groups the AI services (for example
  `llama-swap` and `open-webui`, with `PartOf=ai.target`)
- A GPU that exposes `mem_info_vram_used` in sysfs (amdgpu, integrated GPUs too). With
  NVIDIA the memory does not show: `poll.sh` needs to be adapted.
- Optional: llama-swap on `127.0.0.1:9292` and Open WebUI on `127.0.0.1:8080` (for the
  model, the context, and the "ready" state). Without them the widget stays on
  "starting…" but still shows the VRAM.

## Installation

```sh
git clone <REPOSITORY-URL> ai-toggle-plasmoid
cd ai-toggle-plasmoid
./install.sh
```

`install.sh` only copies the widget to
`~/.local/share/plasma/plasmoids/io.github.andry360.aitoggle/`: **it does not add it to
the panel**. Add it by hand, once:

1. right-click an empty spot on the panel → **Add or Manage Widgets…** (or **Add Widgets…**)
2. search for **AI Toggle**
3. drag it where you want it on the panel (or the desktop), or double-click to add it at
   the end

If it does not show up in the search, restart the shell and try again:

```sh
kquitapp6 plasmashell && kstart plasmashell
```

## Update

After a `git pull` (or a change to the files), run `./install.sh` again: it upgrades the
installed widget. Then restart plasmashell with the command above to load the new
version: the widget stays where it was on the panel, no need to add it again.

## Common problems

- **I restarted plasmashell but I do not see the widget** → it has not been added to the
  panel yet: see the 3 steps in *Installation*. A restart only updates a widget that is
  already there.
- **It does not show up in the widget search** → check that it is installed:
  `kpackagetool6 -t Plasma/Applet --show io.github.andry360.aitoggle`. If it does not
  exist, run `./install.sh` again.
- **It stays on "AI starting…"** → llama-swap (port 9292) or Open WebUI (port 8080) do
  not answer: `systemctl --user status llama-swap open-webui`. If one is `failed`:
  `systemctl --user reset-failed` and turn it on again.
- **VRAM: —** → the GPU does not expose `mem_info_vram_used` (for example NVIDIA):
  `contents/code/poll.sh` needs to be adapted.
- **Widget errors** → start it in a separate window and read the errors in the terminal:
  `plasmawindowed io.github.andry360.aitoggle`.

## Uninstall

```sh
./uninstall.sh
```

## Try it without adding it to the panel

```sh
plasmawindowed io.github.andry360.aitoggle
```

## Customization

In `contents/ui/main.qml`:

- controlled service: search for `ai.target` (also in `contents/code/poll.sh`)
- addresses: `swapUrl`, `webuiUrl`
- refresh interval: `interval: 2000` (ms)
- RAM-GPU warning threshold: `gttWarnMB`; context thresholds: `ctxColor()`
- colors: `onColor`, `warnColor`, `loadColor`, `dangerColor`, `spillColor`

## Tested with

- CachyOS, KDE Plasma 6.7, Wayland, AMD Radeon GPU (amdgpu), llama-swap and Open WebUI
  as systemd user services.

## License

[MIT](LICENSE). This project was written with the help of AI (Claude Code).
