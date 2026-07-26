import type { MartialStyleId, WuxiaLoot } from './WuxiaRaidController';

export interface OfflineProfileV1 {
  readonly version: 1;
  readonly selectedStyle: MartialStyleId;
  readonly totalSilver: number;
  readonly bestChapter: number;
  readonly bestEquipment: WuxiaLoot | null;
}

export interface KeyValueStorage {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
}

const SAVE_KEY = 'luodong-legendary.profile';

export class OfflineSaveRepository {
  public constructor(private readonly storage: KeyValueStorage) {}

  public load(): OfflineProfileV1 {
    const raw = this.storage.getItem(SAVE_KEY);
    if (raw === null) return defaultProfile();
    try {
      const parsed: unknown = JSON.parse(raw);
      return isProfile(parsed) ? parsed : defaultProfile();
    } catch {
      return defaultProfile();
    }
  }

  public save(profile: OfflineProfileV1): void {
    this.storage.setItem(SAVE_KEY, JSON.stringify(profile));
  }

  public recordProgress(
    profile: OfflineProfileV1,
    progress: {
      readonly selectedStyle: MartialStyleId;
      readonly silverEarned: number;
      readonly chapter: number;
      readonly equipment: WuxiaLoot | null;
    },
  ): OfflineProfileV1 {
    const equipment =
      profile.bestEquipment === null ||
      (progress.equipment?.bonusAttack ?? 0) > profile.bestEquipment.bonusAttack
        ? progress.equipment
        : profile.bestEquipment;
    const updated: OfflineProfileV1 = {
      version: 1,
      selectedStyle: progress.selectedStyle,
      totalSilver: profile.totalSilver + Math.max(0, progress.silverEarned),
      bestChapter: Math.max(profile.bestChapter, progress.chapter),
      bestEquipment: equipment,
    };
    this.save(updated);
    return updated;
  }
}

function defaultProfile(): OfflineProfileV1 {
  return {
    version: 1,
    selectedStyle: 'sword',
    totalSilver: 0,
    bestChapter: 1,
    bestEquipment: null,
  };
}

function isProfile(value: unknown): value is OfflineProfileV1 {
  if (typeof value !== 'object' || value === null) return false;
  const profile = value as Partial<OfflineProfileV1>;
  return (
    profile.version === 1 &&
    (profile.selectedStyle === 'sword' ||
      profile.selectedStyle === 'palm' ||
      profile.selectedStyle === 'mechanism') &&
    typeof profile.totalSilver === 'number' &&
    Number.isFinite(profile.totalSilver) &&
    profile.totalSilver >= 0 &&
    typeof profile.bestChapter === 'number' &&
    Number.isInteger(profile.bestChapter) &&
    profile.bestChapter >= 1 &&
    (profile.bestEquipment === null || isLoot(profile.bestEquipment))
  );
}

function isLoot(value: unknown): value is WuxiaLoot {
  if (typeof value !== 'object' || value === null) return false;
  const loot = value as Partial<WuxiaLoot>;
  return (
    typeof loot.name === 'string' &&
    (loot.grade === 'ordinary' || loot.grade === 'fine' || loot.grade === 'rare') &&
    typeof loot.bonusAttack === 'number' &&
    Number.isFinite(loot.bonusAttack) &&
    loot.bonusAttack >= 0
  );
}
