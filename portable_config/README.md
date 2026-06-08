# MPV Portable Config

Personal mpv config: HDR passthrough + uosc modern UI + keyboard-only workflow.

## Usage

Download the latest package and extract to your mpv root:

```
https://github.com/wzyoct/mpv-config/archive/refs/heads/master.zip
```

Extract the contents into `portable_config` folder next to `mpv.exe`.

Or with Git:

```bash
cd [mpv root]
git clone git@github.com:wzyoct/mpv-config.git portable_config
cd portable_config
git pull
```

## Config Files

| File | Description |
|---|---|
| `mpv.conf` | Main config: D3D11 renderer, HDR passthrough, audio output |
| `input.conf` | Key bindings, all explicitly defined |
| `profiles.conf` | `powerful` / `lite` dual profiles |
| `script-opts/` | uosc UI settings |
| `scripts/` | uosc, stats, cache-display |

## Low-end Machines

Edit `profiles.conf`, change `[default]` from `profile=powerful` to `profile=lite`.