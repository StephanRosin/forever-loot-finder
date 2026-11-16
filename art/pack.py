"""Pack 40 rendered frames into two 2048x2048 PNG sheets (4 x 5 frames of 512x384 each).
usage: python3 pack.py <framedir> <name> <outdir>"""
import sys, os
from PIL import Image

src, name, out = sys.argv[1:4]
W, H, COLS, PER = 512, 384, 4, 20
for sheet in range(2):
    img = Image.new("RGBA", (2048, 2048), (0, 0, 0, 255))
    for k in range(PER):
        f = sheet * PER + k + 1
        fr = Image.open(os.path.join(src, "%s_%02d.png" % (name, f))).convert("RGBA")
        assert fr.size == (W, H), fr.size
        img.paste(fr, ((k % COLS) * W, (k // COLS) * H))
    img.save(os.path.join(out, "%s_%d.png" % (name.capitalize(), sheet + 1)), optimize=True)  # Panel.lua: "Tailoring_1.png"
