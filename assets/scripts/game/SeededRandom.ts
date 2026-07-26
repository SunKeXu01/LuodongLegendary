export class SeededRandom {
  private state: number;

  public constructor(seed: number) {
    if (!Number.isInteger(seed)) {
      throw new Error('Random seed must be an integer.');
    }
    this.state = seed >>> 0;
  }

  public next(): number {
    this.state = (Math.imul(this.state, 1_664_525) + 1_013_904_223) >>> 0;
    return this.state / 0x1_0000_0000;
  }

  public pick<T>(values: readonly T[]): T {
    if (values.length === 0) {
      throw new Error('Cannot pick from an empty collection.');
    }
    const value = values[Math.floor(this.next() * values.length)];
    if (value === undefined) {
      throw new Error('Seeded random generated an invalid collection index.');
    }
    return value;
  }
}
