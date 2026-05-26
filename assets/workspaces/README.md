# Workspace media — Alt+Tab fullscreen background

Cada archivo se asocia al ID de workspace por nombre: `w1`, `w2`, …

## Formato recomendado (en orden)

1. **`.mp4` H.264 / AAC** — Mejor compresión. Hardware decoding en intel/amd/nvidia. ~5-50× más liviano que GIF para el mismo loop.
2. **`.webm` VP9 / Opus** — Libre. Decoding HW menos universal.
3. **`.gif`** — Solo si no podés convertir. Heavy en CPU/RAM, paleta 256 colores.

Todos cargan vía QtMultimedia `MediaPlayer` + `VideoOutput`. El componente detecta extensión automáticamente.

## Nombres esperados

```
w1.mp4      ← workspace 1
w2.mp4      ← workspace 2
w3.mp4      ← workspace 3
w4.mp4      ← workspace 4
w5.mp4      ← workspace 5
```

Si falta un archivo: fallback al wallpaper actual con blur.

## Specs sugeridas

- Resolución: ≥ resolución de pantalla (1920×1080 mínimo, 2560×1440 ideal). Se aplica `PreserveAspectCrop`.
- Loop: el archivo debe loopear limpio (último frame ≈ primer frame).
- Duración: 3–10s. Loops más cortos se notan.
- Bitrate: 2-6 Mbps H.264 es buen punto medio. Más bajo = más liviano pero artefactos visibles.
- Audio: irrelevante (lo silencio en el player). Podés exportar sin pista de audio para ahorrar peso.

## Convertir GIF → MP4 rápido

```bash
ffmpeg -i input.gif -movflags +faststart -pix_fmt yuv420p \
       -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -an output.mp4
```

`-an` quita audio. El `scale` asegura dimensiones pares (H.264 lo requiere).
