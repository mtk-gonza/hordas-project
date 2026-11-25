from pathlib import Path
from random import Random

from PIL import Image, ImageDraw, ImageEnhance, ImageOps


ROOT = Path(__file__).resolve().parents[1]
FLOOR_TILE = ROOT / "art/processed/dungeon_floor_tile.png"
OUTPUT = ROOT / "art/processed/swarm_arena.png"
SOURCE_TILE = 16
PIXEL_SCALE = 3
GRID = 48


def main() -> None:
	 source_tile = Image.open(FLOOR_TILE).convert("RGBA")
	 random = Random(247)
	 canvas = Image.new("RGBA", (GRID * SOURCE_TILE, GRID * SOURCE_TILE), "#10191b")
	 for y in range(GRID):
		 for x in range(GRID):
			 tile = source_tile.copy()
			 transform = random.randrange(8)
			 if transform & 1:
				 tile = ImageOps.mirror(tile)
			 if transform & 2:
				 tile = ImageOps.flip(tile)
			 if transform & 4:
				 tile = tile.transpose(Image.Transpose.ROTATE_90)
			 gray = ImageOps.autocontrast(ImageOps.grayscale(tile), cutoff=0)
			 tile = ImageOps.colorize(gray, "#172326", "#586b6b").convert("RGBA")
			 if random.random() < 0.14:
				 tile = ImageEnhance.Brightness(tile).enhance(random.uniform(0.85, 1.1))
			 canvas.alpha_composite(tile, (x * SOURCE_TILE, y * SOURCE_TILE))

	 draw = ImageDraw.Draw(canvas, "RGBA")
	 center = (canvas.width // 2, canvas.height // 2)
	 # A low contrast pixel-art seal gives the combat area a focal point without
	 # reducing visibility beneath the player sprites and enemy telegraphs.
	 for radius, color, width in (
		 (90, (112, 151, 149, 28), 1),
		 (185, (129, 151, 139, 23), 1),
		 (360, (88, 125, 127, 20), 1),
	 ):
		 bounds = (center[0] - radius, center[1] - radius,
				  center[0] + radius, center[1] + radius)
		 draw.ellipse(bounds, outline=color, width=width)
	 for angle in range(0, 360, 45):
		 from math import cos, radians, sin
		 theta = radians(angle)
		 inner = 96
		 outer = 108
		 points = [
			 (center[0] + round(cos(theta) * inner), center[1] + round(sin(theta) * inner)),
			 (center[0] + round(cos(theta) * outer), center[1] + round(sin(theta) * outer)),
		 ]
		 draw.line(points, fill=(183, 133, 73, 58), width=2)
	 final = canvas.resize((canvas.width * PIXEL_SCALE, canvas.height * PIXEL_SCALE), Image.Resampling.NEAREST)
	 final.save(OUTPUT, optimize=True)
	 print(f"Wrote {OUTPUT} ({final.width}x{final.height})")


if __name__ == "__main__":
	main()
