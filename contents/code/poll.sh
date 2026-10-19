#!/bin/sh
# Lightweight probe for the widget: prints key=value lines (memory values in MB).
#   ai=active|inactive|activating|deactivating|failed
#   gpu=<nome>;<vram_used>;<vram_total>;<gtt_used>;<gtt_total>   (one line per GPU)
#   llama_rss=<MB>                                                (only while llama-server runs)
# Uses almost only shell built-ins: it runs every 2 s.

ai=$(systemctl --user is-active ai.target)
echo "ai=$ai"

cache="${XDG_RUNTIME_DIR:-/tmp}/aitoggle-gpu"
for d in /sys/class/drm/card[0-9]*/device; do
    [ -r "$d/mem_info_vram_total" ] || continue
    card=${d%/device}; card=${card##*/}
    # Readable name from lspci, computed once and cached
    if ! read -r name 2>/dev/null < "$cache-$card"; then
        name=$(lspci -s "$(basename "$(readlink -f "$d")")" 2>/dev/null | sed -n 's/.*\[\([^]]*\)\].*/\1/p' | sed 's| / .*||')
        [ -n "$name" ] || name="GPU $card"
        echo "$name" > "$cache-$card"
    fi
    read -r vu < "$d/mem_info_vram_used"; read -r vt < "$d/mem_info_vram_total"
    read -r gu < "$d/mem_info_gtt_used";  read -r gt < "$d/mem_info_gtt_total"
    echo "gpu=$name;$((vu >> 20));$((vt >> 20));$((gu >> 20));$((gt >> 20))"
done

[ "$ai" = active ] || exit 0
rss=0
for p in $(pidof llama-server); do
    while read -r k v _; do
        [ "$k" = "VmRSS:" ] && { rss=$((rss + v)); break; }
    done < "/proc/$p/status"
done
[ "$rss" -gt 0 ] && echo "llama_rss=$((rss >> 10))"
exit 0
