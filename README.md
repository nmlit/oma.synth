# oma.synth

Spela [SynthwaveRadio.eu](https://www.synthwaveradio.eu) med ett klick i Omarchy-baren.

- **Klick** på keytaren: strömmen startar och ikonen blir **röd**.
- **Klick igen**: strömmen stoppas och ikonen blir **vit**.
- **Hovra** över ikonen: `Artist - Låt` medan strömmen spelar, annars `SynthwaveRadio.eu`.

## Installation

```bash
omarchy plugin add https://github.com/nmlit/oma.synth.git --enable
omarchy-restart-shell
```

Flytta vid behov widgeten:

```bash
omarchy bar move oma.synth --section right
```

Uppdatera:

```bash
omarchy plugin update oma.synth --yes
omarchy-restart-shell
```

## Krav

- `mpv` (används i första hand, med `--no-video`). Saknas den används `ffplay` eller `mpg123`.
- systemd-användarsession (`systemd-run --user`), som i en vanlig Omarchy-installation.
- `jq` och `curl` för låttiteln, `socat` för att läsa titeln direkt från mpv.

## Så fungerar det

Spelaren startas av `synth.sh` som en egen systemd-användarenhet, `oma-synth.service`.
Den lever alltså inte som barnprocess till omarchy-shell:

- Vid `omarchy-restart-shell` fortsätter musiken, och ikonen synkas direkt till rött
  eftersom pluginet frågar enheten om läget (var tredje sekund och vid start).
- Det blir aldrig någon föräldralös spelare: stopp gör `systemctl --user stop oma-synth`,
  som avslutar hela enhetens processgrupp.
- Dör strömmen av sig själv (t.ex. nätverksfel) blir ikonen vit igen.

Pluginet skriver aldrig i sin egen mapp. Spelarens PID sparas i
`~/.local/state/oma.synth/pid` medan strömmen spelar och tas bort vid stopp.
Allt är skilt från [oma.metal](https://github.com/nmlit/oma.metal): egen enhet, egen
tillståndsmapp, egen socket och eget ljudklientnamn (`oma.synth`).

## Bara en ström åt gången

När oma.synth startar stoppas `oma-metal.service` om den spelar (och oma.metal stoppar
på samma sätt `oma-synth.service`). Den andra widgetens ikon blir vit inom några sekunder.

## Låt och artist i tooltip

- Titeln hämtas i första hand från strömmens egen ICY-metadata via mpv:s
  IPC-socket (`$XDG_RUNTIME_DIR/oma.synth/mpv.sock`), alltså exakt det som hörs.
- Fungerar inte det används stationens AzuraCast-API:
  `https://stream.synthwaveradio.eu/api/nowplaying/synthwaveradio.eu`.
- Titeln uppdateras var 15:e sekund, bara medan strömmen spelar, och direkt när
  pekaren förs över ikonen. Senast kända titel sparas i
  `~/.local/state/oma.synth/nowplaying`.

## Kommandon

```bash
omarchy-shell -q oma.synth toggle   # start/stopp
omarchy-shell -q oma.synth play
omarchy-shell -q oma.synth stop

~/.config/omarchy/plugins/oma.synth/synth.sh status       # playing | stopped
~/.config/omarchy/plugins/oma.synth/synth.sh nowplaying   # Artist - Låt
systemctl --user status oma-synth                         # spelarens enhet
```

En annan ström kan väljas med miljövariabeln `OMA_SYNTH_URL` i omarchy-shells miljö.

## Ikon

`icon-white.png` och `icon-red.png` skapas från en vit, transparent käll-PNG:

```bash
python3 tools/make-icons.py keytar.png
```

## Licens

MIT

## oma.jul (1.1.0)

Från version 1.1.0 stoppas även [oma.jul](https://github.com/nmlit/oma.jul)
(`oma-jul.service`) när oma.synth startar, och tvärtom. Bara en av oma.metal,
oma.synth och oma.jul spelar alltså åt gången.
