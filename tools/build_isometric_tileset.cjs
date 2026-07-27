const fs = require("node:fs/promises");
const path = require("node:path");
const sharp = require("sharp");

const ROOT = path.resolve(__dirname, "..");
const TILE_WIDTH = 128;
const TILE_HEIGHT = 64;
const COLUMNS = 4;
const SOURCES = [
  {
    key: "earth",
    file: "art/source/textures/cloud_ford_earth-v1.png",
    tint: { r: 104, g: 105, b: 75, alpha: 0.1 },
  },
  {
    key: "stone",
    file: "art/source/textures/cloud_ford_stone-v1.png",
    tint: { r: 78, g: 91, b: 92, alpha: 0.08 },
  },
  {
    key: "water",
    file: "art/source/textures/cloud_ford_water-v1.png",
    tint: { r: 26, g: 77, b: 72, alpha: 0.08 },
  },
];
const OFFSETS = [
  [0, 0],
  [371, 123],
  [742, 371],
  [123, 742],
];

const diamondMask = Buffer.from(`
  <svg width="${TILE_WIDTH}" height="${TILE_HEIGHT}" xmlns="http://www.w3.org/2000/svg">
    <path d="M64 -2 L132 32 L64 66 L-4 32 Z" fill="white"/>
  </svg>
`);

async function buildTile(source, offset, tint) {
  const texture = await sharp(source)
    .extract({
      left: offset[0],
      top: offset[1],
      width: 512,
      height: 512,
    })
    .resize(TILE_WIDTH, TILE_HEIGHT, { fit: "fill", kernel: "lanczos3" })
    .modulate({ saturation: 0.82, brightness: 0.92 })
    .ensureAlpha()
    .composite([
      {
        input: {
          create: {
            width: TILE_WIDTH,
            height: TILE_HEIGHT,
            channels: 4,
            background: tint,
          },
        },
        blend: "overlay",
      },
      { input: diamondMask, blend: "dest-in" },
    ])
    .png()
    .toBuffer();

  return texture;
}

async function main() {
  const outputDir = path.join(ROOT, "godot/assets/isometric/tiles");
  await fs.mkdir(outputDir, { recursive: true });
  const composites = [];

  for (let row = 0; row < SOURCES.length; row += 1) {
    const definition = SOURCES[row];
    const sourcePath = path.join(ROOT, definition.file);
    for (let column = 0; column < COLUMNS; column += 1) {
      const tile = await buildTile(
        sourcePath,
        OFFSETS[column],
        definition.tint,
      );
      composites.push({
        input: tile,
        left: column * TILE_WIDTH,
        top: row * TILE_HEIGHT,
      });
    }
  }

  const outputPath = path.join(outputDir, "cloud_ford_ground_atlas.png");
  await sharp({
    create: {
      width: TILE_WIDTH * COLUMNS,
      height: TILE_HEIGHT * SOURCES.length,
      channels: 4,
      background: { r: 0, g: 0, b: 0, alpha: 0 },
    },
  })
    .composite(composites)
    .png({ compressionLevel: 9, adaptiveFiltering: true })
    .toFile(outputPath);

  process.stdout.write(
    `Built ${path.relative(ROOT, outputPath)} (${COLUMNS}x${SOURCES.length} tiles)\n`,
  );
}

main().catch((error) => {
  process.stderr.write(`${error.stack || error.message}\n`);
  process.exitCode = 1;
});
