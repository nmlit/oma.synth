#!/usr/bin/env bash
# oma.synth – styr strömmen. Spelaren körs i en egen systemd --user-enhet,
# så den lever oberoende av omarchy-shell (ingen föräldralös process) och
# kan alltid hittas/stoppas via enhetsnamnet.
#   synth.sh start|stop|toggle|status|nowplaying
set -euo pipefail

URL="${OMA_SYNTH_URL:-https://stream.synthwaveradio.eu/listen/synthwaveradio.eu/radio.mp3}"
UNIT="oma-synth"
# Andra oma-radioplugin som stoppas när den här startar (bara en ström åt gången).
SIBLINGS=(oma-metal oma-jul)
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/oma.synth"
PID_FILE="$STATE_DIR/pid"
NOW_FILE="$STATE_DIR/nowplaying"
RUN_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/oma.synth"
SOCK="$RUN_DIR/mpv.sock"
# SynthwaveRadio.eu kör AzuraCast; dess publika now playing-API.
API="${OMA_SYNTH_API:-https://stream.synthwaveradio.eu/api/nowplaying/synthwaveradio.eu}"
mkdir -p "$STATE_DIR"

player_cmd() {
  if command -v mpv >/dev/null 2>&1; then
    mkdir -p "$RUN_DIR"
    PLAYER=(mpv --no-video --no-terminal --really-quiet --audio-client-name=oma.synth
      --input-ipc-server="$SOCK" "$URL")
  elif command -v ffplay >/dev/null 2>&1; then
    PLAYER=(ffplay -nodisp -loglevel quiet "$URL")
  elif command -v mpg123 >/dev/null 2>&1; then
    PLAYER=(mpg123 -q "$URL")
  else
    echo "oma.synth: hittar ingen spelare (mpv, ffplay eller mpg123)" >&2
    exit 1
  fi
}

active() { systemctl --user is-active --quiet "$UNIT.service" 2>/dev/null; }

sync_state() {
  if active; then
    systemctl --user show -p MainPID --value "$UNIT.service" > "$PID_FILE"
    echo playing
  else
    rm -f "$PID_FILE"
    echo stopped
  fi
}

start() {
  active && { sync_state; return; }
  player_cmd
  local u
  for u in "${SIBLINGS[@]}"; do
    systemctl --user stop "$u.service" >/dev/null 2>&1 || true
  done
  systemctl --user reset-failed "$UNIT.service" >/dev/null 2>&1 || true
  systemd-run --user --quiet --collect --unit="$UNIT" \
    --description="oma.synth stream" \
    -p KillMode=control-group \
    "${PLAYER[@]}"
  sync_state
}

stop() {
  systemctl --user stop "$UNIT.service" >/dev/null 2>&1 || true
  rm -f "$SOCK"
  sync_state
}

# "Artist - Låt" som spelas just nu. I första hand strömmens egen ICY-titel
# via mpv:s IPC-socket (exakt det som hörs), annars webbplatsens JSON-API.
# Senast kända titel sparas i $NOW_FILE och visas om båda källorna saknas.
icy_title() {
  active && [[ -S "$SOCK" ]] && command -v socat >/dev/null || return 1
  printf '%s\n' '{"command":["get_property","metadata"]}' |
    timeout 2 socat -t1 - "UNIX-CONNECT:$SOCK" 2>/dev/null |
    jq -r 'select(.error=="success") | .data["icy-title"] // empty' 2>/dev/null | head -n1
}

api_title() {
  curl -fsS -m 5 "$API" 2>/dev/null |
    jq -r '.now_playing.song // empty | select(.artist != "" and .title != "") | "\(.artist) - \(.title)"' 2>/dev/null
}

nowplaying() {
  local t
  t="$(icy_title || true)"
  [[ "$t" == *" - "* ]] || t="$(api_title || true)"
  if [[ "$t" == *" - "* ]]; then
    [[ "$(cat "$NOW_FILE" 2>/dev/null)" == "$t" ]] || printf '%s\n' "$t" > "$NOW_FILE"
  else
    t="$(cat "$NOW_FILE" 2>/dev/null || true)"
  fi
  printf '%s\n' "$t"
}

case "${1:-status}" in
  start) start ;;
  stop) stop ;;
  toggle) if active; then stop; else start; fi ;;
  status) sync_state ;;
  nowplaying) nowplaying ;;
  *) echo "Användning: synth.sh start|stop|toggle|status|nowplaying" >&2; exit 2 ;;
esac
