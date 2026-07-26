import Phaser from 'phaser';
import { OfflineSaveRepository } from '../assets/scripts/game/OfflineSave';
import { LuodongScene, type MartialPath, type StoryPath } from './game/LuodongScene';
import './style.css';

interface SceneState {
  readonly health: number;
  readonly maxHealth: number;
  readonly silver: number;
  readonly enemies: number;
  readonly message: string;
}

const healthBar = requiredElement('health-bar');
const healthText = requiredElement('health-text');
const silverText = requiredElement('silver');
const enemyText = requiredElement('enemy-count');
const messageText = requiredElement('message');
const attackButton = requiredElement('attack') as HTMLButtonElement;
const restartButton = requiredElement('restart') as HTMLButtonElement;
const profile = new OfflineSaveRepository(window.localStorage).load();

new Phaser.Game({
  type: Phaser.AUTO,
  parent: 'game-canvas',
  width: 960,
  height: 540,
  backgroundColor: '#263528',
  pixelArt: true,
  roundPixels: true,
  physics: {
    default: 'arcade',
    arcade: { gravity: { x: 0, y: 0 }, debug: false },
  },
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
  },
  scene: [LuodongScene],
});

function requiredElement(id: string): HTMLElement {
  const element = document.getElementById(id);
  if (!(element instanceof HTMLElement)) throw new Error(`Required element #${id} was not found.`);
  return element;
}

window.addEventListener('luodong:state', (event) => {
  const state = (event as CustomEvent<SceneState>).detail;
  healthBar.style.setProperty('--health', `${String((state.health / state.maxHealth) * 100)}%`);
  healthText.textContent = `${String(state.health)} / ${String(state.maxHealth)}`;
  silverText.textContent = String(profile.totalSilver + state.silver);
  enemyText.textContent = String(state.enemies);
  messageText.textContent = state.message;
  attackButton.disabled = state.health === 0;
});

for (const button of document.querySelectorAll<HTMLButtonElement>('[data-martial]')) {
  button.addEventListener('click', () => {
    document.querySelectorAll('[data-martial]').forEach((item) => {
      item.classList.remove('active');
    });
    button.classList.add('active');
    window.dispatchEvent(
      new CustomEvent<MartialPath>('luodong:martial-path', {
        detail: button.dataset.martial as MartialPath,
      }),
    );
  });
}

for (const button of document.querySelectorAll<HTMLButtonElement>('[data-story]')) {
  button.addEventListener('click', () => {
    document.querySelectorAll('[data-story]').forEach((item) => {
      item.classList.remove('active');
    });
    button.classList.add('active');
    window.dispatchEvent(
      new CustomEvent<StoryPath>('luodong:story-path', {
        detail: button.dataset.story as StoryPath,
      }),
    );
  });
}

attackButton.addEventListener('click', () => {
  window.dispatchEvent(new Event('luodong:attack'));
});
restartButton.addEventListener('click', () => {
  window.dispatchEvent(new Event('luodong:restart'));
});
