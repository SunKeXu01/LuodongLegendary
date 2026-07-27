const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const WIDTH = 48;
const HEIGHT = 48;
const FIRST_GID = 1;

function variant(x, y, offset) {
  return FIRST_GID + offset + Math.abs((x * 17 + y * 31 + x * y * 3) % 4);
}

function layerData(kind) {
  const rows = [];
  for (let y = 0; y < HEIGHT; y += 1) {
    const row = [];
    for (let x = 0; x < WIDTH; x += 1) {
      let gid = 0;
      if (kind === "base") {
        gid = x >= 34 ? variant(x, y, 8) : variant(x, y, 0);
      } else if (kind === "road") {
        const northSouth = x >= 21 && x <= 25;
        const riverApproach = y >= 20 && y <= 23 && x >= 8 && x <= 39;
        const marketSquare = x >= 16 && x <= 30 && y >= 27 && y <= 34;
        if (northSouth || riverApproach || marketSquare) {
          gid = variant(x, y, 4);
        }
      }
      row.push(gid);
    }
    rows.push(row.join(","));
  }
  return rows.join(",\n");
}

function emptyData() {
  return Array.from({ length: HEIGHT }, () =>
    Array.from({ length: WIDTH }, () => "0").join(","),
  ).join(",\n");
}

function objectProperties(values) {
  return Object.entries(values)
    .map(([name, value]) => {
      const type = Number.isInteger(value) ? ' type="int"' : "";
      return `    <property name="${name}"${type} value="${value}"/>`;
    })
    .join("\n");
}

function pointObject(id, name, values) {
  const gridX = values.grid_x;
  const gridY = values.grid_y;
  const x = (gridX - gridY) * 64;
  const y = (gridX + gridY) * 32;
  return `  <object id="${id}" name="${name}" class="江湖对象" x="${x}" y="${y}">
   <properties>
${objectProperties(values)}
   </properties>
   <point/>
  </object>`;
}

const tmx = `<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" tiledversion="1.12.2" orientation="isometric" renderorder="right-down" compressionlevel="-1" width="${WIDTH}" height="${HEIGHT}" tilewidth="128" tileheight="64" infinite="1" nextlayerid="8" nextobjectid="6">
 <properties>
  <property name="chapter" value="第一回·渡口风波"/>
  <property name="location_id" value="cloud_ford"/>
  <property name="projection_spec" value="128x64"/>
 </properties>
 <tileset firstgid="${FIRST_GID}" source="../tilesets/cloud_ford_ground.tsx"/>
 <layer id="1" name="ground_base" width="${WIDTH}" height="${HEIGHT}">
  <properties><property name="role" value="基础地表"/></properties>
  <data encoding="csv">
   <chunk x="0" y="0" width="${WIDTH}" height="${HEIGHT}">
${layerData("base")}
   </chunk>
  </data>
 </layer>
 <layer id="2" name="ground_detail" width="${WIDTH}" height="${HEIGHT}">
  <properties><property name="role" value="地表细节"/></properties>
  <data encoding="csv">
   <chunk x="0" y="0" width="${WIDTH}" height="${HEIGHT}">
${layerData("road")}
   </chunk>
  </data>
 </layer>
 <objectgroup id="3" name="collision" color="#d95b55">
  <properties><property name="role" value="不可行走区域"/></properties>
  <object id="5" name="云津河不可行走区" x="2176" y="0" width="896" height="3072">
   <properties><property name="kind" value="water_block"/></properties>
  </object>
 </objectgroup>
 <layer id="4" name="objects_low" width="${WIDTH}" height="${HEIGHT}">
  <properties><property name="role" value="参与Y排序的矮物件"/></properties>
  <data encoding="csv">
   <chunk x="0" y="0" width="${WIDTH}" height="${HEIGHT}">
${emptyData()}
   </chunk>
  </data>
 </layer>
 <objectgroup id="5" name="entities" color="#e0b050">
  <properties><property name="role" value="出生点与交互对象"/></properties>
${pointObject(1, "玩家出生点", {
  id: "player_spawn",
  kind: "player_spawn",
  grid_x: 23,
  grid_y: 35,
})}
${pointObject(2, "渡口巡检沈砚", {
  id: "npc_inspector",
  kind: "npc",
  interaction: "main_quest",
  grid_x: 22,
  grid_y: 29,
})}
${pointObject(3, "寒岭追兵出生组", {
  id: "enemy_hanling_wave",
  kind: "enemy_spawn",
  spawn_group: "hanling_wave_01",
  grid_x: 17,
  grid_y: 12,
})}
${pointObject(4, "寂音禅院入口", {
  id: "portal_silent_temple",
  kind: "portal",
  interaction: "scene_transition",
  destination: "silent_temple",
  grid_x: 23,
  grid_y: 3,
})}
 </objectgroup>
 <layer id="6" name="objects_high" width="${WIDTH}" height="${HEIGHT}">
  <properties><property name="role" value="屋顶树冠前景遮挡"/></properties>
  <data encoding="csv">
   <chunk x="0" y="0" width="${WIDTH}" height="${HEIGHT}">
${emptyData()}
   </chunk>
  </data>
 </layer>
 <imagelayer id="7" name="foreground_fx">
  <properties><property name="role" value="雾雨飘叶前景"/></properties>
 </imagelayer>
</map>
`;

const output = path.join(ROOT, "art/source/maps/cloud_ford_2d.tmx");
fs.writeFileSync(output, tmx);
process.stdout.write(`Built ${path.relative(ROOT, output)} (${WIDTH}x${HEIGHT})\n`);
