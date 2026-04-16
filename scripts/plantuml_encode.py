#!/usr/bin/env python3
"""Encode PlantUML source to a PNG URL (or download the PNG).

Usage:
  python3 plantuml_encode.py /tmp/diagram.puml          # print PNG URL
  python3 plantuml_encode.py /tmp/diagram.puml out.png   # download PNG file

The PlantUML server requires a User-Agent header (returns 403 without it).
URLs are deterministic: same source = same URL.
No Java or local PlantUML installation needed.
"""
import sys, zlib, urllib.request


def encode6bit(b):
    if b < 10: return chr(48 + b)
    b -= 10
    if b < 26: return chr(65 + b)
    b -= 26
    if b < 26: return chr(97 + b)
    b -= 26
    if b == 0: return '-'
    if b == 1: return '_'
    return '?'


def append3bytes(b1, b2, b3):
    c1 = b1 >> 2
    c2 = ((b1 & 0x3) << 4) | (b2 >> 4)
    c3 = ((b2 & 0xF) << 2) | (b3 >> 6)
    c4 = b3 & 0x3F
    return (encode6bit(c1 & 0x3F) + encode6bit(c2 & 0x3F) +
            encode6bit(c3 & 0x3F) + encode6bit(c4 & 0x3F))


def encode(text):
    compressed = zlib.compress(text.encode('utf-8'))[2:-4]
    result = ''
    for i in range(0, len(compressed), 3):
        if i + 2 < len(compressed):
            result += append3bytes(compressed[i], compressed[i + 1], compressed[i + 2])
        elif i + 1 < len(compressed):
            result += append3bytes(compressed[i], compressed[i + 1], 0)
        else:
            result += append3bytes(compressed[i], 0, 0)
    return result


def download_png(puml_text, output_path):
    encoded = encode(puml_text)
    url = f"https://www.plantuml.com/plantuml/png/{encoded}"
    req = urllib.request.Request(url, headers={
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
        'Accept': 'image/png',
    })
    with urllib.request.urlopen(req) as response:
        with open(output_path, 'wb') as f:
            f.write(response.read())
    print(f"OK: {output_path}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: plantuml_encode.py <input.puml> [output.png]", file=sys.stderr)
        sys.exit(1)
    with open(sys.argv[1]) as f:
        puml_text = f.read()
    if len(sys.argv) > 2:
        download_png(puml_text, sys.argv[2])
    else:
        print(f"https://www.plantuml.com/plantuml/png/{encode(puml_text)}")
