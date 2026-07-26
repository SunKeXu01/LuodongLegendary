import { describe, expect, it } from 'vitest';
import { OfflineSaveRepository, type KeyValueStorage } from '../../assets/scripts/game/OfflineSave';

class MemoryStorage implements KeyValueStorage {
  private value: string | null = null;

  public getItem(): string | null {
    return this.value;
  }

  public setItem(_key: string, value: string): void {
    this.value = value;
  }
}

describe('OfflineSaveRepository', () => {
  it('returns a safe default when no save exists', () => {
    const repository = new OfflineSaveRepository(new MemoryStorage());

    expect(repository.load()).toMatchObject({
      version: 1,
      selectedStyle: 'sword',
      totalSilver: 0,
      bestChapter: 1,
    });
  });

  it('persists progress and keeps the strongest equipment', () => {
    const storage = new MemoryStorage();
    const repository = new OfflineSaveRepository(storage);
    const first = repository.recordProgress(repository.load(), {
      selectedStyle: 'palm',
      silverEarned: 12,
      chapter: 2,
      equipment: { name: '寒铁短剑', grade: 'fine', bonusAttack: 5 },
    });
    repository.recordProgress(first, {
      selectedStyle: 'palm',
      silverEarned: 6,
      chapter: 1,
      equipment: { name: '百炼护腕', grade: 'ordinary', bonusAttack: 2 },
    });

    expect(repository.load()).toMatchObject({
      selectedStyle: 'palm',
      totalSilver: 18,
      bestChapter: 2,
      bestEquipment: { name: '寒铁短剑', bonusAttack: 5 },
    });
  });

  it('recovers from malformed save data', () => {
    const storage = new MemoryStorage();
    storage.setItem('ignored', '{broken');

    expect(new OfflineSaveRepository(storage).load().version).toBe(1);
  });
});
