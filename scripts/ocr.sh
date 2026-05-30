#!/usr/bin/env bash

# Check dependencies
for dep in grim slurp tesseract wl-copy notify-send magick; do
    if ! command -v "$dep" &> /dev/null; then
        notify-send "OCR Error" "Missing dependency: $dep" -u critical
        exit 1
    fi
done

# Select region
REGION=$(slurp)
if [ -z "$REGION" ]; then
    exit 0 # User cancelled
fi

# Languages based on installed tesseract packages:
# eng (English), spa (Spanish), lat (Latin), jpn (Japanese),
# chi_sim (Simplified Chinese), chi_tra (Traditional Chinese), kor (Korean)
LANGS="${1:-eng+spa}"

# Tesseract recognises best around ~300dpi, but screens give ~96dpi, so small
# text comes in too low-res. Capture at 2x (grim -s) for more pixels and
# preprocess for contrast before recognition. This is the single biggest win.
TMP=$(mktemp --suffix=.png)
trap 'rm -f "$TMP"' EXIT

# 2x capture -> grayscale + contrast normalize + light sharpen.
grim -s 2 -g "$REGION" - \
    | magick - -colorspace Gray -normalize -sharpen 0x1 "$TMP"

# Auto-invert dark-mode captures (light text on dark background) so Tesseract
# sees dark-on-light, which it handles far better. Decide by mean brightness.
MEAN=$(magick "$TMP" -format "%[fx:mean]" info:)
if awk "BEGIN { exit !($MEAN < 0.5) }"; then
    magick "$TMP" -negate "$TMP"
fi

# --oem 1: LSTM engine.  --psm 6: treat the selection as a uniform text block.
TEXT=$(tesseract "$TMP" - -l "$LANGS" --oem 1 --psm 6 2>/dev/null)

# Trim whitespace
TEXT=$(echo "$TEXT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

if [ -n "$TEXT" ]; then
    printf '%s' "$TEXT" | wl-copy
    notify-send "OCR Result" "Text copied to clipboard" -i edit-paste
else
    notify-send "OCR Result" "No text detected" -u low -i dialogue-error
fi
