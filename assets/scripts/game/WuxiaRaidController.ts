import { SeededRandom } from './SeededRandom';

export type MartialStyleId = 'sword' | 'palm' | 'mechanism';

export interface MartialStyle {
  readonly id: MartialStyleId;
  readonly name: string;
  readonly technique: string;
  readonly maxHealth: number;
  readonly attack: number;
  readonly criticalChance: number;
}

export interface WuxiaEnemy {
  readonly name: string;
  readonly title: string;
  readonly maxHealth: number;
  readonly attack: number;
}

export interface WuxiaLoot {
  readonly name: string;
  readonly grade: 'ordinary' | 'fine' | 'rare';
  readonly bonusAttack: number;
}

export type CloudFordChoice = 'protect-villagers' | 'seek-evidence';

export interface WuxiaRaidState {
  readonly style: MartialStyle;
  readonly playerHealth: number;
  readonly enemy: WuxiaEnemy;
  readonly enemyHealth: number;
  readonly chapter: number;
  readonly silver: number;
  readonly equippedLoot: WuxiaLoot | null;
  readonly attack: number;
  readonly cloudFordStanding: number;
  readonly choice: CloudFordChoice | null;
  readonly complete: boolean;
}

export const MARTIAL_STYLES: Readonly<Record<MartialStyleId, MartialStyle>> = {
  sword: {
    id: 'sword',
    name: '青冥剑式',
    technique: '轻灵善变，容易打出破绽一击',
    maxHealth: 84,
    attack: 18,
    criticalChance: 0.34,
  },
  palm: {
    id: 'palm',
    name: '伏虎掌',
    technique: '气息沉稳，适合正面缠斗',
    maxHealth: 122,
    attack: 14,
    criticalChance: 0.14,
  },
  mechanism: {
    id: 'mechanism',
    name: '机弩术',
    technique: '借助机关，招式刚猛直接',
    maxHealth: 94,
    attack: 21,
    criticalChance: 0.19,
  },
};

const ENEMIES: readonly WuxiaEnemy[] = [
  { name: '寒岭门客', title: '云津渡外的拦路人', maxHealth: 56, attack: 8 },
  { name: '黑衣暗桩', title: '武氏庄外的伏击者', maxHealth: 82, attack: 11 },
  { name: '寂音武僧', title: '禅院地牢的守关人', maxHealth: 116, attack: 14 },
];

const LOOT: readonly WuxiaLoot[] = [
  { name: '百炼护腕', grade: 'ordinary', bonusAttack: 2 },
  { name: '寒铁短剑', grade: 'fine', bonusAttack: 5 },
  { name: '云纹玉佩', grade: 'rare', bonusAttack: 9 },
];

/** A deterministic offline combat slice for the Ming-era original wuxia game. */
export class WuxiaRaidController {
  private readonly random: SeededRandom;
  private playerHealth: number;
  private enemyHealth: number;
  private currentChapter = 0;
  private earnedSilver = 0;
  private equippedLoot: WuxiaLoot | null = null;
  private cloudFordStanding = 0;
  private cloudFordChoice: CloudFordChoice | null = null;
  private finished = false;

  public constructor(
    public readonly style: MartialStyle,
    seed: number,
  ) {
    this.random = new SeededRandom(seed);
    this.playerHealth = style.maxHealth;
    this.enemyHealth = this.currentEnemy.maxHealth;
  }

  public get state(): WuxiaRaidState {
    return {
      style: this.style,
      playerHealth: this.playerHealth,
      enemy: this.currentEnemy,
      enemyHealth: this.enemyHealth,
      chapter: this.currentChapter + 1,
      silver: this.earnedSilver,
      equippedLoot: this.equippedLoot,
      attack: this.attackPower,
      cloudFordStanding: this.cloudFordStanding,
      choice: this.cloudFordChoice,
      complete: this.finished,
    };
  }

  public chooseCloudFordPath(choice: CloudFordChoice): WuxiaRaidState {
    if (this.currentChapter !== 0 || this.cloudFordChoice !== null) {
      throw new Error('The Yunjin Ford choice can only be made once before the first battle.');
    }
    this.cloudFordChoice = choice;
    this.cloudFordStanding = choice === 'protect-villagers' ? 2 : 1;
    return this.state;
  }

  public attack(): {
    readonly damage: number;
    readonly critical: boolean;
    readonly defeated: boolean;
    readonly state: WuxiaRaidState;
  } {
    if (this.finished) throw new Error('The chapter run is complete.');
    const critical = this.random.next() < this.style.criticalChance;
    const damage = this.attackPower * (critical ? 2 : 1);
    this.enemyHealth = Math.max(0, this.enemyHealth - damage);
    const defeated = this.enemyHealth === 0;
    if (defeated) {
      const loot = this.rollLoot();
      this.earnedSilver += 12 + this.currentChapter * 6;
      if (this.equippedLoot === null || loot.bonusAttack > this.equippedLoot.bonusAttack) {
        this.equippedLoot = loot;
      }
      if (this.currentChapter === ENEMIES.length - 1) {
        this.finished = true;
      } else {
        this.currentChapter += 1;
        this.enemyHealth = this.currentEnemy.maxHealth;
      }
    } else {
      this.playerHealth = Math.max(0, this.playerHealth - this.currentEnemy.attack);
      if (this.playerHealth === 0) this.finished = true;
    }
    return { damage, critical, defeated, state: this.state };
  }

  private get currentEnemy(): WuxiaEnemy {
    const enemy = ENEMIES[this.currentChapter];
    if (enemy === undefined) throw new Error('Chapter index is invalid.');
    return enemy;
  }

  private get attackPower(): number {
    return this.style.attack + (this.equippedLoot?.bonusAttack ?? 0);
  }

  private rollLoot(): WuxiaLoot {
    const roll = this.random.next();
    if (roll < 0.12) return LOOT[2] as WuxiaLoot;
    if (roll < 0.42) return LOOT[1] as WuxiaLoot;
    return LOOT[0] as WuxiaLoot;
  }
}
