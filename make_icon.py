import os, json
from PIL import Image, ImageDraw

S = 1024
k = S / 100
img = Image.new("RGB", (S, S), (255, 90, 31))
d = ImageDraw.Draw(img)

dark = (13, 13, 15)
for x in (10, 39, 68):
    d.rounded_rectangle([x * k, 38 * k, (x + 22) * k, 64 * k], radius=4 * k, fill=dark)

d.rounded_rectangle([48.5 * k, 22 * k, 51.5 * k, 78 * k], radius=1.5 * k, fill=(255, 255, 255))
d.polygon([(43 * k, 16 * k), (57 * k, 16 * k), (50 * k, 25 * k)], fill=(255, 255, 255))

base = "Sources/Assets.xcassets"
icon = base + "/AppIcon.appiconset"
os.makedirs(icon, exist_ok=True)
img.save(icon + "/icon.png")
info = {"author": "xcode", "version": 1}
json.dump({"info": info}, open(base + "/Contents.json", "w"))
json.dump({"images": [{"filename": "icon.png", "idiom": "universal",
                       "platform": "ios", "size": "1024x1024"}],
           "info": info}, open(icon + "/Contents.json", "w"))
