import Phaser from 'phaser';

export type MartialPath = 'sword' | 'palm' | 'mechanism';
export type StoryPath = 'protect-villagers' | 'seek-evidence';

interface SceneState {
  readonly health: number;
  readonly maxHealth: number;
  readonly silver: number;
  readonly enemies: number;
  readonly message: string;
}

interface EnemySpec {
  readonly name: string;
  readonly x: number;
  readonly y: number;
  readonly health: number;
  readonly silver: number;
}

const ENEMIES: readonly EnemySpec[] = [
  { name: '寒岭门客', x: 520, y: 1170, health: 48, silver: 12 },
  { name: '黑衣暗桩', x: 670, y: 1060, health: 66, silver: 18 },
  { name: '寂音武僧', x: 850, y: 1190, health: 92, silver: 26 },
];

export class LuodongScene extends Phaser.Scene {
  private player!: Phaser.Physics.Arcade.Sprite;
  private enemies!: Phaser.Physics.Arcade.Group;
  private pickups!: Phaser.Physics.Arcade.Group;
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
  private combatStartsAt = 0;
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

  public preload(): void {
    this.load.image(
      'cloud-ford-tiles',
      new URL('../vendor/phaser-rpg/assets/tilesets/cloud-ford.png', import.meta.url).href,
    );
    this.load.tilemapTiledJSON(
      'cloud-ford-map',
      new URL('../vendor/phaser-rpg/assets/tilemaps/cloud-ford.json', import.meta.url).href,
    );
    this.load.atlas(
      'hero-atlas',
      new URL('../vendor/phaser-rpg/assets/atlas/atlas.png', import.meta.url).href,
      new URL('../vendor/phaser-rpg/assets/atlas/atlas.json', import.meta.url).href,
    );
  }

  public create(): void {
    this.health = 100;
    this.silver = 0;
    this.livingEnemies = ENEMIES.length;
    this.attacking = false;
    this.defeated = false;
    this.lastEnemyStrike = 0;
    this.createRuntimeTextures();
    const map = this.make.tilemap({ key: 'cloud-ford-map' });
    const tileset = map.addTilesetImage('tuxemon-sample-32px-extruded', 'cloud-ford-tiles');
    if (tileset === null) throw new Error('Unable to load the ported RPG tileset.');
    map.createLayer('Below Player', tileset, 0, 0);
    const worldLayer = map.createLayer('World', tileset, 0, 0);
    const aboveLayer = map.createLayer('Above Player', tileset, 0, 0);
    if (worldLayer === null || aboveLayer === null)
      throw new Error('Ported map layers are missing.');
    worldLayer.setCollisionByProperty({ collides: true });
    aboveLayer.setDepth(30);

    const spawn = map.findObject('Objects', ({ name }) => name === 'Spawn Point');
    if (spawn?.x === undefined || spawn.y === undefined) throw new Error('Spawn point is missing.');
    this.createPlayer(spawn.x, spawn.y);
    this.createEnemies();
    this.createPickups();
    this.createLabels();
    this.bindControls();

    this.physics.add.collider(this.player, worldLayer);
    this.physics.add.collider(this.enemies, worldLayer);
    this.physics.add.collider(this.player, this.enemies);
    this.physics.add.collider(this.enemies, this.enemies);
    this.physics.world.setBounds(0, 0, map.widthInPixels, map.heightInPixels);
    this.cameras.main
      .setBounds(0, 0, map.widthInPixels, map.heightInPixels)
      .startFollow(this.player, true, 0.12, 0.12)
      .setZoom(1.35)
      .fadeIn(450, 15, 19, 14);
    this.combatStartsAt = this.time.now + 3500;

    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => {
      this.unbindWindowEvents();
    });
    this.emitState('云津渡地图已经载入。沿镇中石径向东，击退寒岭武氏的爪牙。');
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

  private createPlayer(x: number, y: number): void {
    this.player = this.physics.add.sprite(x, y, 'hero-atlas', 'misa-front');
    this.player.setCollideWorldBounds(true).setDepth(20).setSize(32, 42).setOffset(0, 22);
    const animations = [
      ['walk-left', 'misa-left-walk.'],
      ['walk-right', 'misa-right-walk.'],
      ['walk-up', 'misa-back-walk.'],
      ['walk-down', 'misa-front-walk.'],
    ] as const;
    for (const [key, prefix] of animations) {
      if (!this.anims.exists(key)) {
        this.anims.create({
          key,
          frames: this.anims.generateFrameNames('hero-atlas', {
            prefix,
            start: 0,
            end: 3,
            zeroPad: 3,
          }),
          frameRate: 10,
          repeat: -1,
        });
      }
    }
  }

  private createEnemies(): void {
    this.enemies = this.physics.add.group();
    for (const spec of ENEMIES) {
      const enemy = this.enemies.create(
        spec.x,
        spec.y,
        'wushi-enemy',
      ) as Phaser.Physics.Arcade.Sprite;
      enemy.setDepth(19).setSize(24, 20).setOffset(7, 29).setCollideWorldBounds(true);
      enemy.setData({ name: spec.name, health: spec.health, silver: spec.silver });
      this.add
        .text(spec.x, spec.y - 38, spec.name, {
          fontFamily: 'Microsoft YaHei',
          fontSize: '12px',
          color: '#f0d8b0',
          stroke: '#261a15',
          strokeThickness: 3,
        })
        .setOrigin(0.5)
        .setDepth(25)
        .setData('enemy', enemy);
    }
  }

  private createPickups(): void {
    this.pickups = this.physics.add.group();
    this.physics.add.overlap(this.player, this.pickups, (_player, pickupObject) => {
      const pickup = pickupObject as Phaser.Physics.Arcade.Sprite;
      this.silver += pickup.getData('value') as number;
      pickup.destroy();
      this.emitState('拾得寒岭武氏遗落的碎银。');
    });
  }

  private createLabels(): void {
    this.add
      .text(405, 1135, '云津渡 · 西市', {
        fontFamily: 'STKaiti, serif',
        fontSize: '18px',
        color: '#f4dfae',
        backgroundColor: '#4e2e22cc',
        padding: { x: 9, y: 5 },
      })
      .setDepth(24);
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
    }) as typeof this.movementKeys;
    window.addEventListener('luodong:attack', this.attackRequest);
    window.addEventListener('luodong:restart', this.restartRequest);
    window.addEventListener('luodong:martial-path', this.martialPathRequest);
    window.addEventListener('luodong:story-path', this.storyPathRequest);
  }

  private unbindWindowEvents(): void {
    window.removeEventListener('luodong:attack', this.attackRequest);
    window.removeEventListener('luodong:restart', this.restartRequest);
    window.removeEventListener('luodong:martial-path', this.martialPathRequest);
    window.removeEventListener('luodong:story-path', this.storyPathRequest);
  }

  private updatePlayerMovement(): void {
    const body = this.player.body as Phaser.Physics.Arcade.Body;
    const x =
      Number(this.cursors.right.isDown || this.movementKeys.d.isDown) -
      Number(this.cursors.left.isDown || this.movementKeys.a.isDown);
    const y =
      Number(this.cursors.down.isDown || this.movementKeys.s.isDown) -
      Number(this.cursors.up.isDown || this.movementKeys.w.isDown);
    const velocity = new Phaser.Math.Vector2(x, y);
    body.setVelocity(0);
    if (velocity.lengthSq() === 0) {
      this.player.anims.stop();
      return;
    }
    velocity.normalize();
    body.setVelocity(velocity.x * 175, velocity.y * 175);
    this.facing.copy(velocity);
    if (Math.abs(velocity.x) > Math.abs(velocity.y)) {
      this.player.anims.play(velocity.x < 0 ? 'walk-left' : 'walk-right', true);
    } else {
      this.player.anims.play(velocity.y < 0 ? 'walk-up' : 'walk-down', true);
    }
  }

  private updateEnemies(time: number): void {
    for (const child of this.enemies.getChildren()) {
      const enemy = child as Phaser.Physics.Arcade.Sprite;
      if (!enemy.active) continue;
      const distance = Phaser.Math.Distance.Between(enemy.x, enemy.y, this.player.x, this.player.y);
      if (distance < 310 && distance > 45) this.physics.moveToObject(enemy, this.player, 62);
      else enemy.setVelocity(0);
      if (distance <= 48 && time >= this.combatStartsAt && time - this.lastEnemyStrike > 1100) {
        this.lastEnemyStrike = time;
        this.health = Math.max(0, this.health - 9);
        this.cameras.main.shake(90, 0.006);
        this.flashActor(this.player);
        this.defeated = this.health === 0;
        this.emitState(
          this.defeated ? '伤势过重。点击重新闯荡再战云津渡。' : '敌人近身反击，气血受损。',
        );
      }
    }
  }

  private attack(): void {
    if (this.attacking || this.defeated) return;
    this.attacking = true;
    const range = this.martialPath === 'mechanism' ? 125 : 82;
    const damage = this.martialPath === 'palm' ? 24 : this.martialPath === 'mechanism' ? 18 : 21;
    let hit = false;
    this.drawAttackEffect(range);
    for (const child of this.enemies.getChildren()) {
      const enemy = child as Phaser.Physics.Arcade.Sprite;
      const offset = new Phaser.Math.Vector2(enemy.x - this.player.x, enemy.y - this.player.y);
      if (offset.length() > range || offset.clone().normalize().dot(this.facing) <= -0.05) continue;
      hit = true;
      const health = (enemy.getData('health') as number) - damage;
      enemy.setData('health', health);
      this.flashActor(enemy);
      this.showDamage(enemy.x, enemy.y - 28, damage);
      if (health <= 0) this.defeatEnemy(enemy);
    }
    if (!hit) this.emitState(`${this.pathName}破空而出，尚未触及敌手。`);
    this.time.delayedCall(260, () => {
      this.attacking = false;
    });
  }

  private defeatEnemy(enemy: Phaser.Physics.Arcade.Sprite): void {
    const name = enemy.getData('name') as string;
    const coin = this.pickups.create(enemy.x, enemy.y, 'silver') as Phaser.Physics.Arcade.Sprite;
    coin.setData('value', enemy.getData('silver')).setDepth(18);
    this.tweens.add({ targets: coin, y: coin.y - 7, duration: 400, yoyo: true, repeat: -1 });
    enemy.destroy();
    this.livingEnemies -= 1;
    this.emitState(this.livingEnemies === 0 ? '云津渡伏兵尽除！' : `击败${name}，碎银落在地上。`);
  }

  private drawAttackEffect(range: number): void {
    const effect = this.add.graphics().setDepth(40);
    effect.lineStyle(8, this.martialPath === 'mechanism' ? 0xe6b953 : 0xf4efd1, 0.95);
    effect.beginPath();
    effect.arc(
      this.player.x,
      this.player.y,
      range * 0.72,
      this.facing.angle() - 0.75,
      this.facing.angle() + 0.75,
    );
    effect.strokePath();
    this.tweens.add({
      targets: effect,
      alpha: 0,
      scale: 1.2,
      duration: 210,
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
      .setDepth(50);
    this.tweens.add({
      targets: text,
      y: y - 32,
      alpha: 0,
      duration: 620,
      onComplete: () => {
        text.destroy();
      },
    });
  }

  private flashActor(actor: Phaser.GameObjects.Sprite): void {
    actor.setTintFill(0xffffff);
    this.time.delayedCall(100, () => actor.clearTint());
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

  private createRuntimeTextures(): void {
    this.makeActorTexture('wushi-enemy', '#3c2633', '#a13331');
    this.makeTexture('silver', 18, 18, (context) => {
      context.fillStyle = '#73501f';
      context.fillRect(4, 5, 12, 10);
      context.fillStyle = '#e4bd5e';
      context.fillRect(3, 3, 12, 10);
      context.fillStyle = '#fff0a0';
      context.fillRect(6, 5, 6, 2);
    });
  }

  private makeActorTexture(key: string, robe: string, trim: string): void {
    this.makeTexture(key, 40, 54, (context) => {
      context.fillStyle = '#241c22';
      context.fillRect(9, 7, 22, 10);
      context.fillStyle = '#d8ab7f';
      context.fillRect(13, 14, 14, 10);
      context.fillStyle = '#292127';
      context.fillRect(12, 19, 16, 6);
      context.fillStyle = robe;
      context.fillRect(10, 25, 20, 20);
      context.fillRect(6, 29, 5, 14);
      context.fillRect(29, 29, 5, 14);
      context.fillStyle = trim;
      context.fillRect(10, 34, 20, 4);
      context.fillStyle = '#242120';
      context.fillRect(12, 44, 6, 8);
      context.fillRect(23, 44, 6, 8);
    });
  }

  private makeTexture(
    key: string,
    width: number,
    height: number,
    draw: (context: CanvasRenderingContext2D) => void,
  ): void {
    if (this.textures.exists(key)) return;
    const texture = this.textures.createCanvas(key, width, height);
    if (texture === null) throw new Error(`Unable to create texture ${key}.`);
    draw(texture.getContext());
    texture.refresh();
  }
}
