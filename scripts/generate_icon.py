"""Generate the Typikon icon from the bundled Monomakh OFL font.
Tool dependencies: Pillow, fonttools. Run: python scripts/generate_icon.py
The circle and palette match the CS Dictionary; Android foreground is scaled
for the 72/108 launcher viewport, with a separate full-bleed background.
"""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from fontTools.ttLib import TTFont
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets/branding'
FONT = ROOT / 'assets/fonts/MonomakhUnicode.otf'
BACKGROUND, CREAM, INK = '#850014', '#faf5de', '#060606'


def glyph_path():
    font = TTFont(FONT)
    glyphs = font.getGlyphSet()
    glyph = glyphs[font.getBestCmap()[ord('Т')]]
    bounds = BoundsPen(glyphs)
    glyph.draw(bounds)
    left, bottom, right, top = bounds.bounds
    scale = min(610 / (right - left), 610 / (top - bottom))
    pen = SVGPathPen(glyphs)
    glyph.draw(TransformPen(pen, (scale, 0, 0, -scale,
        512 - (left + right) * scale / 2,
        512 + (top + bottom) * scale / 2)))
    return pen.getCommands()


def motif():
    canvas = Image.new('RGBA', (2048, 2048))
    draw = ImageDraw.Draw(canvas)
    draw.ellipse((128, 128, 1920, 1920), fill=CREAM, outline=INK, width=18)
    initial = ImageFont.truetype(str(FONT), 2000)
    left, top, right, bottom = draw.textbbox((0, 0), 'Т', font=initial)
    scale = min(1220 / (right - left), 1220 / (bottom - top))
    actual = ImageFont.truetype(str(FONT), round(2000 * scale))
    left, top, right, bottom = draw.textbbox((0, 0), 'Т', font=actual)
    draw.text((1024 - (left + right) / 2, 1024 - (top + bottom) / 2),
        'Т', font=actual, fill=INK)
    return canvas.resize((1024, 1024), Image.Resampling.LANCZOS)


def main():
    OUT.mkdir(exist_ok=True, parents=True)
    path = glyph_path()
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" '
        f'role="img" aria-label="Уставные чтения: Т">'
        f'<rect width="1024" height="1024" fill="{BACKGROUND}"/>'
        f'<circle cx="512" cy="512" r="448" fill="{CREAM}" stroke="{INK}" stroke-width="9"/>'
        f'<path d="{path}" fill="{INK}"/></svg>\n')
    (OUT / 'app-icon.svg').write_text(svg)
    layer = motif()
    icon = Image.new('RGBA', (1024, 1024), BACKGROUND)
    icon.alpha_composite(layer)
    icon = icon.convert('RGB')
    icon.save(OUT / 'app-icon.png')
    icon.save(ROOT / 'assets/logo.png')
    icon.save(ROOT / 'android/app/src/main/ic_launcher.png')
    foreground = Image.new('RGBA', (1024, 1024))
    foreground.alpha_composite(layer.resize((682, 682), Image.Resampling.LANCZOS), (171, 171))
    foreground.save(OUT / 'adaptive-foreground.png')
    for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
        icon.resize((size, size), Image.Resampling.LANCZOS).save(
            ROOT / f'android/app/src/main/res/mipmap-{density}/ic_launcher.png')
    folder = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    for item in json.loads((folder / 'Contents.json').read_text())['images']:
        if 'filename' in item:
            size = round(float(item['size'].split('x')[0]) * float(item['scale'].removesuffix('x')))
            icon.resize((size, size), Image.Resampling.LANCZOS).save(folder / item['filename'])
    res = ROOT / 'android/app/src/main/res'
    (res / 'drawable').mkdir(exist_ok=True)
    (res / 'mipmap-anydpi-v26').mkdir(exist_ok=True)
    (res / 'drawable/ic_launcher_foreground.xml').write_text(
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
        '    android:width="108dp" android:height="108dp" android:viewportWidth="1024" android:viewportHeight="1024">\n'
        '  <group android:scaleX="0.6666667" android:scaleY="0.6666667" android:translateX="170.66667" android:translateY="170.66667">\n'
        f'    <path android:fillColor="{CREAM}" android:strokeColor="{INK}" android:strokeWidth="9" android:pathData="M64,512 A448,448 0,1 1,960,512 A448,448 0,1 1,64,512 Z"/>\n'
        f'    <path android:fillColor="{INK}" android:pathData="{path}"/>\n'
        '  </group>\n</vector>\n')
    (res / 'drawable/ic_launcher_background.xml').write_text(
        '<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">\n'
        f'  <solid android:color="{BACKGROUND}"/>\n</shape>\n')
    (res / 'mipmap-anydpi-v26/ic_launcher.xml').write_text(
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '  <background android:drawable="@drawable/ic_launcher_background"/>\n'
        '  <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n</adaptive-icon>\n')
    print('Generated Typikon vector master, PNG icons and Android adaptive layers.')


if __name__ == '__main__':
    main()
