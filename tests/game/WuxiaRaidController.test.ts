import { describe, expect, it } from 'vitest';
import { MARTIAL_STYLES, WuxiaRaidController } from '../../assets/scripts/game/WuxiaRaidController';

describe('WuxiaRaidController', () => {
  it('records a once-only Yunjin Ford choice before combat', () => {
    const game = new WuxiaRaidController(MARTIAL_STYLES.sword, 1);

    expect(game.chooseCloudFordPath('protect-villagers')).toMatchObject({
      cloudFordStanding: 2,
      choice: 'protect-villagers',
    });
    expect(() => game.chooseCloudFordPath('seek-evidence')).toThrow('only be made once');
  });

  it('awards silver and equips loot after defeating an enemy', () => {
    const game = new WuxiaRaidController(MARTIAL_STYLES.mechanism, 1);
    let result = game.attack();
    while (!result.defeated) result = game.attack();

    expect(result.state).toMatchObject({ chapter: 2 });
    expect(result.state.silver).toBeGreaterThan(0);
    expect(result.state.equippedLoot).not.toBeNull();
    expect(result.state.attack).toBeGreaterThan(MARTIAL_STYLES.mechanism.attack);
  });

  it('is deterministic for the same martial style and seed', () => {
    const first = new WuxiaRaidController(MARTIAL_STYLES.palm, 20260726);
    const second = new WuxiaRaidController(MARTIAL_STYLES.palm, 20260726);

    expect(first.attack()).toEqual(second.attack());
  });
});
