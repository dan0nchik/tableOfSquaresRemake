"""Turns a flat illustration on white into a transparent asset: flood-fills the background from the edges."""
import sys, os, json
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

def cutout(src, name, max_side=1200):
    im = Image.open(src).convert('RGB'); W, H = im.size
    mask = im.copy()
    for pt in [(0, 0), (W - 1, 0), (0, H - 1), (W - 1, H - 1), (W // 2, 0), (W // 2, H - 1), (0, H // 2), (W - 1, H // 2)]:
        ImageDraw.floodfill(mask, pt, (255, 0, 255), thresh=40)
    m = np.array(mask)
    alpha = np.where((m[:, :, 0] == 255) & (m[:, :, 1] == 0) & (m[:, :, 2] == 255), 0, 255).astype('uint8')
    out = im.convert('RGBA'); out.putalpha(Image.fromarray(alpha).filter(ImageFilter.GaussianBlur(1.2)))
    out = out.crop(out.getbbox()); out.thumbnail((max_side, max_side))
    d = f'App/Resources/Assets.xcassets/{name}.imageset'; os.makedirs(d, exist_ok=True)
    out.save(f'{d}/{name}.png')
    json.dump({"images": [{"filename": f"{name}.png", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}}, open(f'{d}/Contents.json', 'w'))

if __name__ == '__main__':
    cutout(sys.argv[1], sys.argv[2])
