import { describe, expect, it } from 'vitest';
import { WuxiaWorldMap, type CellAttribute } from '../../assets/scripts/game/WuxiaWorldMap';

const allWalkable = Array.from({ length: 16 }, () => 'walk' as const);

describe('WuxiaWorldMap', () => {
  it('caches walkable cells and marks safe zones', () => {
    const attributes: CellAttribute[] = [...allWalkable];
    attributes[0] = 'high-wall';
    const map = new WuxiaWorldMap(4, 4, attributes, [{ center: { x: 2, y: 2 }, radius: 1 }]);

    expect(map.getWalkablePoints()).toHaveLength(15);
    expect(map.getCell({ x: 2, y: 2 })).toMatchObject({ safeZone: true });
    expect(map.getCell({ x: 0, y: 0 })).toMatchObject({ attribute: 'high-wall' });
  });

  it('validates adjacent movement and blocking occupancy', () => {
    const map = new WuxiaWorldMap(4, 4, allWalkable);
    map.addObject({
      id: 'player',
      kind: 'player',
      location: { x: 1, y: 1 },
      blocking: true,
    });
    map.addObject({
      id: 'guard',
      kind: 'enemy',
      location: { x: 2, y: 1 },
      blocking: true,
    });

    expect(map.moveObject('player', { x: 2, y: 1 })).toEqual({
      moved: false,
      reason: 'occupied',
    });
    expect(map.moveObject('player', { x: 1, y: 2 })).toEqual({
      moved: true,
      location: { x: 1, y: 2 },
    });
  });

  it('returns defensive copies of object locations', () => {
    const map = new WuxiaWorldMap(4, 4, allWalkable);
    map.addObject({
      id: 'player',
      kind: 'player',
      location: { x: 1, y: 1 },
      blocking: true,
    });

    expect(map.getObject('player')).toEqual({
      id: 'player',
      kind: 'player',
      location: { x: 1, y: 1 },
      blocking: true,
    });
  });
});
