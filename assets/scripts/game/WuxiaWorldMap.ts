export interface WorldPoint {
  readonly x: number;
  readonly y: number;
}

export type CellAttribute = 'walk' | 'low-wall' | 'high-wall' | 'water';

export interface WorldCell {
  readonly attribute: CellAttribute;
  readonly safeZone: boolean;
}

export interface SafeZone {
  readonly center: WorldPoint;
  readonly radius: number;
}

export interface WorldObject {
  readonly id: string;
  readonly kind: 'player' | 'npc' | 'enemy' | 'loot';
  readonly location: WorldPoint;
  readonly blocking: boolean;
}

export type MoveResult =
  | { readonly moved: true; readonly location: WorldPoint }
  | {
      readonly moved: false;
      readonly reason: 'out-of-bounds' | 'blocked-cell' | 'occupied' | 'not-adjacent';
    };

/**
 * Offline TypeScript port of the generic map/cell/object structure in
 * JevLOMCN/mir1 Server/MirEnvir/Map.cs and Server/MirObjects/MapObject.cs.
 *
 * Mir names, binary map data, content and assets are not used. The port keeps
 * only the Unlicense-covered technical ideas: rectangular cells, cached
 * walkable points, safe zones, blocking objects and validated movement.
 */
export class WuxiaWorldMap {
  private readonly cells: WorldCell[];
  private readonly objects = new Map<string, WorldObject>();
  private readonly walkablePoints: WorldPoint[];

  public constructor(
    public readonly width: number,
    public readonly height: number,
    attributes: readonly CellAttribute[],
    safeZones: readonly SafeZone[] = [],
  ) {
    if (!Number.isInteger(width) || !Number.isInteger(height) || width < 1 || height < 1) {
      throw new Error('Map dimensions must be positive integers.');
    }
    if (attributes.length !== width * height) {
      throw new Error('Map attributes must contain one value for every cell.');
    }

    this.cells = attributes.map((attribute, index) => {
      const location = { x: index % width, y: Math.floor(index / width) };
      return {
        attribute,
        safeZone: safeZones.some((zone) => withinSafeZone(location, zone)),
      };
    });
    this.walkablePoints = this.cells.flatMap((cell, index) =>
      cell.attribute === 'walk' ? [{ x: index % width, y: Math.floor(index / width) }] : [],
    );
  }

  public validPoint(location: WorldPoint): boolean {
    return (
      Number.isInteger(location.x) &&
      Number.isInteger(location.y) &&
      location.x >= 0 &&
      location.x < this.width &&
      location.y >= 0 &&
      location.y < this.height
    );
  }

  public getCell(location: WorldPoint): WorldCell | null {
    if (!this.validPoint(location)) return null;
    return this.cells[location.y * this.width + location.x] ?? null;
  }

  public getWalkablePoints(): readonly WorldPoint[] {
    return this.walkablePoints.map((point) => ({ ...point }));
  }

  public addObject(object: WorldObject): void {
    if (this.objects.has(object.id)) throw new Error(`World object ${object.id} already exists.`);
    const cell = this.getCell(object.location);
    if (cell?.attribute !== 'walk') throw new Error('World objects must spawn on walkable cells.');
    if (object.blocking && this.hasBlockingObjectAt(object.location)) {
      throw new Error('A blocking world object already occupies the spawn cell.');
    }
    this.objects.set(object.id, { ...object, location: { ...object.location } });
  }

  public moveObject(id: string, destination: WorldPoint): MoveResult {
    const object = this.objects.get(id);
    if (object === undefined) throw new Error(`World object ${id} does not exist.`);
    if (!this.validPoint(destination)) return { moved: false, reason: 'out-of-bounds' };
    const distance =
      Math.abs(object.location.x - destination.x) + Math.abs(object.location.y - destination.y);
    if (distance !== 1) return { moved: false, reason: 'not-adjacent' };
    if (this.getCell(destination)?.attribute !== 'walk') {
      return { moved: false, reason: 'blocked-cell' };
    }
    if (this.hasBlockingObjectAt(destination)) return { moved: false, reason: 'occupied' };

    const movedObject = { ...object, location: { ...destination } };
    this.objects.set(id, movedObject);
    return { moved: true, location: { ...destination } };
  }

  public getObject(id: string): WorldObject | null {
    const object = this.objects.get(id);
    return object === undefined ? null : { ...object, location: { ...object.location } };
  }

  private hasBlockingObjectAt(location: WorldPoint): boolean {
    return [...this.objects.values()].some(
      (object) =>
        object.blocking && object.location.x === location.x && object.location.y === location.y,
    );
  }
}

function withinSafeZone(location: WorldPoint, zone: SafeZone): boolean {
  return (
    Math.abs(location.x - zone.center.x) <= zone.radius &&
    Math.abs(location.y - zone.center.y) <= zone.radius
  );
}
