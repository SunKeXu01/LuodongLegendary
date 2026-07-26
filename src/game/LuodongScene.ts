import Phaser from 'phaser';

export type MartialPath = 'sword' | 'palm' | 'mechanism';
export type StoryPath = 'protect-villagers' | 'seek-evidence';

interface EnemySpec {
  readonly name: string;
  readonly x: number;
  readonly y: number;
  readonly health: number;
  readonly silver: number;
}

interface SceneState {
  readonly health: number;
  readonly maxHealth: number;
  readonly silver: number;
  readonly enemies: number;
  readonly message: string;
}

const WORLD_WIDTH = 1600;
const WORLD_HEIGHT = 960;
const ENEMIES: readonly EnemySpec[] = [
  { name: '寒岭门客', x: 960, y: 430, health: 48, silver: 12 },
  { name: '黑衣暗桩', x: 1210, y: 650, health: 66, silver: 18 },
  { name: '寂音武僧', x: 1420, y: 280, health: 92, silver: 26 },
];

export class LuodongScene extends Phaser.Scene {
  private player!: Phaser.Physics.Arcade.Sprite;
  private enemies!: Phaser.Physics.Arcade.Group;
  private pickups!: Phaser.Physics.Arcade.Group;
  private obstacles!: Phaser.Physics.Arcade.StaticGroup;
  private cursors!: Phaser.Types.Input.Keyboard.CursorKeys;
  private movementKeys!: Record<'w' | 'a' | 's' | 'd' | 'j', Phaser.Input.Keyboard.Key>;
  private health = 100;
  private silver = 0;
  private livingEnemies = ENEMIES.length;
  private facing = new Phaser.Math.Vector2(1, 0);
  private martialPath: MartialPath = 'sword';
  private storyPath: StoryPath = 'protect-villagers';
  private attacking = false;
  private defeated = false;
  private lastEnemyStrike = 0;
  private readonly attackRequest = (): void => {
    this.attack();
  };
  private readonly restartRequest = (): void => {
    this.scene.restart();
  };
  private readonly martialPathRequest = (event: Event): void => {
    this.martialPath = (event as CustomEvent<MartialPath>).detail;
    this.emitState(`已切换为${this.pathName}。`);
  };
  private readonly storyPathRequest = (event: Event): void => {
    this.storyPath = (event as CustomEvent<StoryPath>).detail;
    this.emitState(
      this.storyPath === 'protect-villagers'
        ? '你决定先护送渡口百姓撤往西岸。'
        : '你循着武氏暗记，准备追查械斗证据。',
    );
  };

  public constructor() {
    super('luodong-world');
  }

  public create(): void {
    this.createTextures();
    this.physics.world.setBounds(0, 0, WORLD_WIDTH, WORLD_HEIGHT);
    this.drawCloudFord();
    this.createObstacles();
    this.createPlayer();
    this.createEnemies();
    this.createPickups();
    this.createNpcAndLabels();
    this.bindControls();
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => {
      window.removeEventListener('luodong:attack', this.attackRequest);
      window.removeEventListener('luodong:restart', this.restartRequest);
      window.removeEventListener('luodong:martial-path', this.martialPathRequest);
      window.removeEventListener('luodong:story-path', this.storyPathRequest);
    });

    this.cameras.main
      .setBounds(0, 0, WORLD_WIDTH, WORLD_HEIGHT)
      .startFollow(this.player, true, 0.1, 0.1)
      .setZoom(1.15)
      .fadeIn(500, 28, 20, 14);

    this.emitState('云津渡外杀机隐现。沿石径向东，击退寒岭武氏的爪牙。');
  }

  public update(time: number): void {
    if (this.defeated) return;
    this.updatePlayerMovement();
    this.updateEnemies(time);
    if (
      Phaser.Input.Keyboard.JustDown(this.cursors.space) ||
      Phaser.Input.Keyboard.JustDown(this.movementKeys.j)
    ) {
      this.attack();
    }
  }

  private createPlayer(): void {
    this.player = this.physics.add.sprite(205, 505, 'hero');
    this.player.setCollideWorldBounds(true).setDepth(20).setSize(23, 20).setOffset(8, 30);
    this.physics.add.collider(this.player, this.obstacles);
  }

  private createEnemies(): void {
    this.enemies = this.physics.add.group();
    for (const spec of ENEMIES) {
      const enemy = this.enemies.create(spec.x, spec.y, 'enemy') as Phaser.Physics.Arcade.Sprite;
      enemy
        .setDepth(19)
        .setSize(24, 20)
        .setOffset(7, 29)
        .setCollideWorldBounds(true)
        .setDataEnabled();
      enemy.setData('name', spec.name);
      enemy.setData('health', spec.health);
      enemy.setData('silver', spec.silver);
    }
    this.physics.add.collider(this.enemies, this.obstacles);
    this.physics.add.collider(this.enemies, this.enemies);
    this.physics.add.collider(this.player, this.enemies);
  }

  private createPickups(): void {
    this.pickups = this.physics.add.group();
    this.physics.add.overlap(this.player, this.pickups, (_player, pickupObject) => {
      const pickup = pickupObject as Phaser.Physics.Arcade.Sprite;
      const value = pickup.getData('value') as number;
      this.silver += value;
      pickup.destroy();
      this.emitState(`拾得碎银 ${String(value)} 两。`);
    });
  }

  private bindControls(): void {
    const keyboard = this.input.keyboard;
    if (keyboard === null) throw new Error('Keyboard input is unavailable.');
    this.cursors = keyboard.createCursorKeys();
    this.movementKeys = keyboard.addKeys({
      w: Phaser.Input.Keyboard.KeyCodes.W,
      a: Phaser.Input.Keyboard.KeyCodes.A,
      s: Phaser.Input.Keyboard.KeyCodes.S,
      d: Phaser.Input.Keyboard.KeyCodes.D,
      j: Phaser.Input.Keyboard.KeyCodes.J,
    }) as Record<'w' | 'a' | 's' | 'd' | 'j', Phaser.Input.Keyboard.Key>;
    window.addEventListener('luodong:attack', this.attackRequest);
    window.addEventListener('luodong:restart', this.restartRequest);
    window.addEventListener('luodong:martial-path', this.martialPathRequest);
    window.addEventListener('luodong:story-path', this.storyPathRequest);
  }

  private updatePlayerMovement(): void {
    const body = this.player.body as Phaser.Physics.Arcade.Body;
    const left = this.cursors.left.isDown || this.movementKeys.a.isDown;
    const right = this.cursors.right.isDown || this.movementKeys.d.isDown;
    const up = this.cursors.up.isDown || this.movementKeys.w.isDown;
    const down = this.cursors.down.isDown || this.movementKeys.s.isDown;
    const velocity = new Phaser.Math.Vector2(
      Number(right) - Number(left),
      Number(down) - Number(up),
    );

    body.setVelocity(0);
    if (velocity.lengthSq() > 0) {
      velocity.normalize();
      body.setVelocity(velocity.x * 190, velocity.y * 190);
      this.facing.copy(velocity);
      this.player.setFlipX(velocity.x < 0).setTexture('hero-walk');
    } else {
      this.player.setTexture('hero');
    }
  }

  private updateEnemies(time: number): void {
    this.enemies.children.each((child) => {
      const enemy = child as Phaser.Physics.Arcade.Sprite;
      if (!enemy.active) return true;
      const body = enemy.body as Phaser.Physics.Arcade.Body;
      const distance = Phaser.Math.Distance.Between(enemy.x, enemy.y, this.player.x, this.player.y);
      if (distance < 330 && distance > 45) {
        this.physics.moveToObject(enemy, this.player, 72);
        enemy.setFlipX(body.velocity.x < 0);
      } else {
        body.setVelocity(0);
      }
      if (distance <= 48 && time - this.lastEnemyStrike > 850) {
        this.lastEnemyStrike = time;
        this.health = Math.max(0, this.health - 9);
        this.cameras.main.shake(90, 0.006);
        this.flashActor(this.player, 0xf5c9a5);
        if (this.health === 0) {
          this.defeated = true;
          this.player.setTint(0x806f65);
          this.emitState('伤势过重。按右上角重新闯荡，再战云津渡。');
        } else {
          this.emitState('遭到近身反击，气血受损。');
        }
      }
      return true;
    });
  }

  private attack(): void {
    if (this.attacking || this.defeated) return;
    this.attacking = true;
    const range = this.martialPath === 'mechanism' ? 125 : 82;
    const baseDamage =
      this.martialPath === 'palm' ? 24 : this.martialPath === 'mechanism' ? 18 : 21;
    let hit = false;

    this.drawAttackEffect(range);
    for (const child of this.enemies.getChildren()) {
      const enemy = child as Phaser.Physics.Arcade.Sprite;
      if (!enemy.active) continue;
      const offset = new Phaser.Math.Vector2(enemy.x - this.player.x, enemy.y - this.player.y);
      if (offset.length() <= range && offset.clone().normalize().dot(this.facing) > -0.05) {
        hit = true;
        const health = (enemy.getData('health') as number) - baseDamage;
        enemy.setData('health', health);
        this.flashActor(enemy, 0xffffff);
        enemy.setVelocity(this.facing.x * 130, this.facing.y * 130);
        this.showDamage(enemy.x, enemy.y - 30, baseDamage);
        if (health <= 0) this.defeatEnemy(enemy);
      }
    }

    if (!hit) this.emitState(`${this.pathName}破空而出，尚未触及敌手。`);
    this.time.delayedCall(280, () => {
      this.attacking = false;
    });
  }

  private defeatEnemy(enemy: Phaser.Physics.Arcade.Sprite): void {
    const name = enemy.getData('name') as string;
    const value = enemy.getData('silver') as number;
    const coin = this.pickups.create(enemy.x, enemy.y, 'silver') as Phaser.Physics.Arcade.Sprite;
    coin.setData('value', value).setDepth(18);
    this.tweens.add({ targets: coin, y: coin.y - 8, duration: 420, yoyo: true, repeat: -1 });
    enemy.destroy();
    this.livingEnemies -= 1;
    this.emitState(
      this.livingEnemies === 0
        ? '云津渡伏兵尽除！拾取战利品后，前往东岸石碑。'
        : `击败${name}，碎银掉落在地。`,
    );
  }

  private drawAttackEffect(range: number): void {
    const angle = this.facing.angle();
    const effect = this.add.graphics().setDepth(30);
    effect.lineStyle(
      this.martialPath === 'palm' ? 13 : 7,
      this.martialPath === 'mechanism' ? 0xe2b44c : 0xeef1d7,
      0.92,
    );
    effect.beginPath();
    effect.arc(this.player.x, this.player.y, range * 0.72, angle - 0.75, angle + 0.75);
    effect.strokePath();
    this.tweens.add({
      targets: effect,
      alpha: 0,
      scale: 1.2,
      duration: 220,
      onComplete: () => {
        effect.destroy();
      },
    });
  }

  private showDamage(x: number, y: number, damage: number): void {
    const text = this.add
      .text(x, y, `-${String(damage)}`, {
        fontFamily: 'Arial',
        fontSize: '18px',
        color: '#ffe9a8',
        stroke: '#5c1711',
        strokeThickness: 4,
      })
      .setOrigin(0.5)
      .setDepth(40);
    this.tweens.add({
      targets: text,
      y: y - 35,
      alpha: 0,
      duration: 650,
      onComplete: () => {
        text.destroy();
      },
    });
  }

  private flashActor(actor: Phaser.GameObjects.Sprite, color: number): void {
    actor.setTintFill(color);
    this.time.delayedCall(100, () => {
      actor.clearTint();
    });
  }

  private emitState(message: string): void {
    const state: SceneState = {
      health: this.health,
      maxHealth: 100,
      silver: this.silver,
      enemies: this.livingEnemies,
      message,
    };
    window.dispatchEvent(new CustomEvent<SceneState>('luodong:state', { detail: state }));
  }

  private get pathName(): string {
    if (this.martialPath === 'palm') return '伏虎掌';
    if (this.martialPath === 'mechanism') return '机弩术';
    return '青冥剑式';
  }

  private createObstacles(): void {
    this.obstacles = this.physics.add.staticGroup();
    this.addBlocker(805, 205, 170, 410);
    this.addBlocker(805, 765, 170, 390);
    this.addBlocker(275, 240, 220, 150);
    this.addBlocker(535, 185, 190, 130);
    this.addBlocker(1315, 155, 230, 145);
    const trees = [
      [110, 150],
      [160, 170],
      [625, 320],
      [670, 345],
      [1040, 145],
      [1080, 180],
      [1130, 150],
      [1050, 810],
      [1100, 835],
      [1510, 720],
      [1460, 750],
      [360, 830],
      [420, 850],
    ] as const;
    for (const [x, y] of trees) this.addBlocker(x, y + 18, 46, 40);
  }

  private addBlocker(x: number, y: number, width: number, height: number): void {
    const blocker = this.obstacles.create(x, y, 'block') as Phaser.Physics.Arcade.Sprite;
    blocker.setDisplaySize(width, height).setVisible(false).refreshBody();
  }

  private drawCloudFord(): void {
    const ground = this.add.graphics().setDepth(0);
    ground.fillStyle(0x718b55).fillRect(0, 0, WORLD_WIDTH, WORLD_HEIGHT);
    for (let index = 0; index < 320; index += 1) {
      ground.fillStyle(index % 3 === 0 ? 0x91a968 : 0x607b49, 0.32);
      ground.fillCircle((index * 137) % WORLD_WIDTH, (index * 71) % WORLD_HEIGHT, 2 + (index % 3));
    }
    ground.fillStyle(0xa98d62, 0.78).fillRoundedRect(70, 430, 1480, 150, 58);
    ground.fillStyle(0xb79b6f, 0.7).fillRoundedRect(180, 340, 170, 390, 52);
    ground.fillStyle(0x3f7790).fillRect(720, 0, 170, WORLD_HEIGHT);
    ground.lineStyle(3, 0x83b6c2, 0.48);
    for (let y = 25; y < WORLD_HEIGHT; y += 48) {
      ground
        .beginPath()
        .moveTo(735, y)
        .lineTo(875, y - 8)
        .strokePath();
    }
    ground.fillStyle(0x6f4a2d).fillRect(705, 405, 200, 170);
    for (let y = 417; y < 570; y += 21) {
      ground.fillStyle(y % 42 === 0 ? 0xb4834f : 0x987049).fillRect(710, y, 190, 17);
    }
    ground.fillStyle(0x4d3323).fillRect(700, 398, 12, 184).fillRect(898, 398, 12, 184);
    this.drawHouse(165, 155, 220, 150, '云津客栈');
    this.drawHouse(440, 120, 190, 130, '渡口药铺');
    this.drawHouse(1200, 85, 230, 145, '寒岭别院');

    const foliage = this.add.graphics().setDepth(8);
    const treePoints = [
      [110, 150],
      [160, 170],
      [625, 320],
      [670, 345],
      [1040, 145],
      [1080, 180],
      [1130, 150],
      [1050, 810],
      [1100, 835],
      [1510, 720],
      [1460, 750],
      [360, 830],
      [420, 850],
    ] as const;
    for (const [x, y] of treePoints) {
      foliage.fillStyle(0x483824).fillRect(x - 7, y + 15, 14, 34);
      foliage.fillStyle(0x294e35).fillCircle(x - 12, y + 4, 27);
      foliage.fillStyle(0x376344).fillCircle(x + 15, y, 30);
      foliage.fillStyle(0x527553).fillCircle(x, y - 18, 25);
    }
  }

  private drawHouse(x: number, y: number, width: number, height: number, name: string): void {
    const house = this.add.graphics().setDepth(7);
    house.fillStyle(0xdec39a).fillRect(x, y + 42, width, height - 42);
    house
      .fillStyle(0x713a2b)
      .fillTriangle(x - 18, y + 50, x + width / 2, y - 25, x + width + 18, y + 50);
    house.fillStyle(0x3a211c).fillRect(x - 12, y + 45, width + 24, 10);
    house.fillStyle(0x4b2b20).fillRect(x + width / 2 - 24, y + height - 55, 48, 55);
    this.add
      .text(x + width / 2, y + 65, name, {
        fontFamily: 'STSong, serif',
        fontSize: '16px',
        color: '#3b251c',
        backgroundColor: '#e7d5ad',
        padding: { x: 7, y: 4 },
      })
      .setOrigin(0.5)
      .setDepth(9);
  }

  private createNpcAndLabels(): void {
    this.add.sprite(360, 555, 'npc').setDepth(18);
    this.add
      .text(360, 515, '渡口老者', {
        fontFamily: 'PingFang SC',
        fontSize: '14px',
        color: '#f8e8c4',
        stroke: '#31231b',
        strokeThickness: 4,
      })
      .setOrigin(0.5)
      .setDepth(22);
    this.add
      .text(805, 370, '云 津 渡', {
        fontFamily: 'STKaiti, serif',
        fontSize: '26px',
        color: '#f2dfb2',
        stroke: '#3a2b20',
        strokeThickness: 5,
      })
      .setOrigin(0.5)
      .setDepth(22);
    this.add
      .text(1510, 500, '▶ 寂音禅院', {
        fontFamily: 'STKaiti, serif',
        fontSize: '20px',
        color: '#3d2a20',
        backgroundColor: '#d8c39b',
        padding: { x: 8, y: 5 },
      })
      .setOrigin(1, 0.5)
      .setDepth(10);
  }

  private createTextures(): void {
    this.makeActorTexture('hero', '#294f66', '#d5aa63', false);
    this.makeActorTexture('hero-walk', '#315c75', '#e0bd78', false);
    this.makeActorTexture('enemy', '#432f35', '#9f3030', true);
    this.makeActorTexture('npc', '#6d5a3f', '#9c7950', false);
    this.makeSimpleTexture('silver', 18, 18, (context) => {
      context.fillStyle = '#6e4a20';
      context.fillRect(4, 5, 12, 10);
      context.fillStyle = '#e4bd5e';
      context.fillRect(3, 3, 12, 10);
      context.fillStyle = '#fff0a0';
      context.fillRect(6, 5, 6, 2);
    });
    this.makeSimpleTexture('block', 2, 2, () => undefined);
  }

  private makeActorTexture(key: string, robe: string, trim: string, masked: boolean): void {
    this.makeSimpleTexture(key, 40, 54, (context) => {
      context.imageSmoothingEnabled = false;
      context.fillStyle = 'rgba(20,18,15,.28)';
      context.beginPath();
      context.ellipse(20, 48, 14, 5, 0, 0, Math.PI * 2);
      context.fill();
      context.fillStyle = '#2a211e';
      context.fillRect(12, 4, 16, 12);
      context.fillRect(9, 9, 22, 7);
      context.fillStyle = '#d8ab7f';
      context.fillRect(13, 13, 14, 12);
      if (masked) {
        context.fillStyle = '#292127';
        context.fillRect(12, 18, 16, 7);
      }
      context.fillStyle = robe;
      context.fillRect(10, 25, 20, 19);
      context.fillRect(6, 28, 5, 15);
      context.fillRect(29, 28, 5, 15);
      context.fillStyle = trim;
      context.fillRect(10, 33, 20, 4);
      context.fillStyle = '#2c2522';
      context.fillRect(12, 44, 6, 7);
      context.fillRect(23, 44, 6, 7);
      context.fillStyle = '#c7c3b4';
      context.fillRect(32, 17, 3, 27);
      context.fillStyle = '#80603b';
      context.fillRect(30, 36, 7, 3);
    });
  }

  private makeSimpleTexture(
    key: string,
    width: number,
    height: number,
    draw: (context: CanvasRenderingContext2D) => void,
  ): void {
    const texture = this.textures.createCanvas(key, width, height);
    if (texture === null) throw new Error(`Unable to create texture ${key}.`);
    draw(texture.getContext());
    texture.refresh();
  }
}
