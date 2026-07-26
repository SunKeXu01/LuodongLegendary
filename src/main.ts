import {
  MARTIAL_STYLES,
  WuxiaRaidController,
  type CloudFordChoice,
  type MartialStyleId,
} from '../assets/scripts/game/WuxiaRaidController';
import { OfflineSaveRepository } from '../assets/scripts/game/OfflineSave';
import './style.css';

const STYLE_ICONS: Record<MartialStyleId, string> = { sword: '🗡️', palm: '✊', mechanism: '⚙️' };
const ENEMY_ICONS: Record<string, string> = { 寒岭门客: '🧔', 黑衣暗桩: '🥷', 寂音武僧: '🧘' };
const styleChoicesElement = requiredElement('style-choices');
const storyChoicesElement = requiredElement('story-choices');
const playerElement = requiredElement('hero');
const enemyElement = requiredElement('enemy');
const playerHealthElement = requiredElement('hero-health') as HTMLDivElement;
const enemyHealthElement = requiredElement('enemy-health') as HTMLDivElement;
const chapterElement = requiredElement('stage');
const silverElement = requiredElement('coins');
const profileElement = requiredElement('profile');
const statusElement = requiredElement('status');
const lootElement = requiredElement('loot');
const equipmentElement = requiredElement('equipment');
const attackButton = requiredElement('attack') as HTMLButtonElement;
const restartButton = requiredElement('restart') as HTMLButtonElement;

const saveRepository = new OfflineSaveRepository(window.localStorage);
let profile = saveRepository.load();
let styleId: MartialStyleId = profile.selectedStyle;
let raid = new WuxiaRaidController(MARTIAL_STYLES[styleId], 20260726);

function requiredElement(id: string): HTMLElement {
  const element = document.getElementById(id);
  if (!(element instanceof HTMLElement)) throw new Error(`Required element #${id} was not found.`);
  return element;
}

function render(): void {
  const state = raid.state;
  styleChoicesElement.replaceChildren(
    ...Object.values(MARTIAL_STYLES).map((style) => styleChoiceButton(style.id)),
  );
  renderStoryChoices(state.choice);
  playerElement.textContent = STYLE_ICONS[state.style.id];
  enemyElement.textContent = ENEMY_ICONS[state.enemy.name] ?? '⚔️';
  const chapterNames = ['云津渡风波', '寒岭暗局', '寂音禅院'];
  chapterElement.textContent = `主线 · ${chapterNames[state.chapter - 1] ?? '江湖余波'} · ${state.enemy.title}`;
  silverElement.textContent = `行囊碎银 ${String(profile.totalSilver)}`;
  profileElement.textContent = profile.bestEquipment
    ? `离线存档 · 最远第 ${String(profile.bestChapter)} 章 · 最佳兵器 ${profile.bestEquipment.name}`
    : `离线存档 · 最远第 ${String(profile.bestChapter)} 章 · 尚无珍藏兵器`;
  statusElement.textContent = state.complete
    ? state.playerHealth === 0
      ? '伤势过重，需整备后再入江湖。'
      : '云津渡一线暂告平息。'
    : `${state.style.name} · ${state.style.technique}`;
  equipmentElement.textContent = state.equippedLoot
    ? `随身兵器：${state.equippedLoot.name} · 攻势 +${String(state.equippedLoot.bonusAttack)}`
    : `当前攻势 ${String(state.attack)} · 尚无趁手兵器`;
  setHealth(playerHealthElement, state.playerHealth, state.style.maxHealth);
  setHealth(enemyHealthElement, state.enemyHealth, state.enemy.maxHealth);
  attackButton.disabled = state.complete || state.choice === null;
  attackButton.textContent = state.complete
    ? '重新闯荡'
    : state.choice === null
      ? '先作决断'
      : '施展招式';
}

function styleChoiceButton(id: MartialStyleId): HTMLButtonElement {
  const style = MARTIAL_STYLES[id];
  const button = document.createElement('button');
  button.type = 'button';
  button.className = `hero-choice ${id === styleId ? 'active' : ''}`;
  button.innerHTML = `<span>${STYLE_ICONS[id]}</span>${style.name}`;
  button.addEventListener('click', () => {
    styleId = id;
    profile = saveRepository.recordProgress(profile, {
      selectedStyle: styleId,
      silverEarned: 0,
      chapter: profile.bestChapter,
      equipment: profile.bestEquipment,
    });
    restart();
  });
  return button;
}

function renderStoryChoices(current: CloudFordChoice | null): void {
  storyChoicesElement.replaceChildren(
    storyChoiceButton('protect-villagers', '护送渡口百姓', current),
    storyChoiceButton('seek-evidence', '追查械斗证据', current),
  );
}

function storyChoiceButton(
  choice: CloudFordChoice,
  label: string,
  current: CloudFordChoice | null,
): HTMLButtonElement {
  const button = document.createElement('button');
  button.type = 'button';
  button.className = `story-choice ${current === choice ? 'active' : ''}`;
  button.textContent = label;
  button.disabled = current !== null;
  button.addEventListener('click', () => {
    raid.chooseCloudFordPath(choice);
    lootElement.textContent =
      choice === 'protect-villagers'
        ? '百姓记下了这份情义，云津渡声望提升。'
        : '你寻得一枚暗记，武氏庄的线索渐渐清晰。';
    render();
  });
  return button;
}

function setHealth(element: HTMLDivElement, current: number, max: number): void {
  element.style.setProperty('--health', `${String((current / max) * 100)}%`);
  element.setAttribute('aria-label', `气血 ${String(current)} / ${String(max)}`);
  element.textContent = `${String(current)} / ${String(max)}`;
}

function restart(): void {
  raid = new WuxiaRaidController(MARTIAL_STYLES[styleId], 20260726);
  lootElement.textContent = '先决定如何介入云津渡纷争，再踏入江湖。';
  lootElement.className = 'loot';
  render();
}

attackButton.addEventListener('click', () => {
  if (raid.state.complete) {
    restart();
    return;
  }
  const silverBeforeAttack = raid.state.silver;
  const result = raid.attack();
  profile = saveRepository.recordProgress(profile, {
    selectedStyle: styleId,
    silverEarned: result.state.silver - silverBeforeAttack,
    chapter: result.state.chapter,
    equipment: result.state.equippedLoot,
  });
  if (result.defeated) {
    lootElement.textContent = '胜过守关者，获得碎银并换上更好的兵器。';
    lootElement.className = 'loot fine';
  } else if (result.critical) {
    lootElement.textContent = `破绽一击！造成 ${String(result.damage)} 点伤害。`;
  } else {
    lootElement.textContent = `招式命中，造成 ${String(result.damage)} 点伤害；对方随即反击。`;
  }
  render();
});
restartButton.addEventListener('click', restart);

restart();
