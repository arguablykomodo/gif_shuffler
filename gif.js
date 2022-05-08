const header = "GIF89a";

/**
 * @param {any[]} array
 */
function shuffleArray(array) {
  for (let i = array.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [array[i], array[j]] = [array[j], array[i]];
  }
}

/**
 * @typedef Section
 * @property {number} start
 * @property {number} start
 * @property {"start"|"shuffle"|"end"} type
 */

export class GifShuffler {
  /**
   * @param {Uint8Array} original
   * @param {boolean} override
   * @param {number} frameSpeed
   */
  constructor(original, override, frameSpeed) {
    this.buffer = original;
    this.i = 0;
    this.override = override;
    if (override) {
      if (frameSpeed < 20) frameSpeed = 20;
      else if (frameSpeed > 6553500) frameSpeed = 6553500;
      frameSpeed /= 10;
      this.frameSpeed = [frameSpeed & 0x00FF, (frameSpeed & 0xFF00) >> 8];
    }
    /** @type {Section[]} */
    this.sections = [];
  }

  /**
   * @param {number} n
   */
  #read(n) {
    if (this.i + n > this.buffer.length) {
      throw new Error("Reading past end of buffer");
    }
    return this.buffer.slice(this.i, this.i += n);
  }

  /**
   * @param {number} byte
   */
  #colorTableSize(byte) {
    const hasTable = byte & 0b10000000;
    if ((hasTable >> 7) === 1) {
      const packedSize = (byte & 0b00000111);
      return 3 * 2 ** (packedSize + 1);
    } else {
      return 0;
    }
  }

  #skipSubBlocks() {
    while (true) {
      const length = this.#read(1)[0];
      if (length === 0) break;
      else this.i += length;
    }
  }

  /** @returns {Section} */
  #parseSection() {
    const start = this.i;
    switch (this.#read(1)[0]) {
      case 0x21:
        switch (this.#read(1)[0]) {
          case 0xFF: // Application extension
            this.i = this.#read(1)[0] + this.i;
            this.#skipSubBlocks();
            return { start, end: this.i, type: "start" };
          case 0xFE: // Comment extension
            this.i = this.#read(1)[0] + this.i;
            this.#skipSubBlocks();
            return { start, end: this.i, type: "start" };
          case 0xF9: // Graphics control extension
            this.i = this.#read(1)[0] + this.i + 1;
            const otherBlock = this.#read(1)[0];
            if (otherBlock !== 0x2C) throw new Error("Unknown block");
            const imageDescriptor = this.#read(9);
            this.i += this.#colorTableSize(imageDescriptor[8]) + 1;
            this.#skipSubBlocks();
            return { start, end: this.i, type: "shuffle" };
          default:
            throw new Error("Unknown extension block");
        }
      case 0x2C: // Image descriptor
        const imageDescriptor = this.#read(9);
        this.i += this.#colorTableSize(imageDescriptor[8]) + 1;
        this.#skipSubBlocks();
        return { start, end: this.i, type: "start" };
      case 0x3B: // Trailer
        return { start, end: this.i, type: "end" };
      default:
        throw new Error("Unknown block");
    }
  }

  shuffle() {
    if (!this.#read(6).every((b, i) => b === header.charCodeAt(i))) {
      throw new Error("Invalid header");
    }
    const logicalScreenDescriptor = this.#read(7);
    this.i += this.#colorTableSize(logicalScreenDescriptor[4]);
    this.sections.push({
      start: 0,
      end: this.i,
      type: "start",
    });

    while (true) {
      const section = this.#parseSection();
      this.sections.push(section);
      if (section.type === "end") break;
    }

    const newBuffer = new Uint8Array(this.buffer.length);
    let newI = 0;

    for (const section of this.sections.filter((s) => s.type === "start")) {
      newBuffer.set(this.buffer.slice(section.start, section.end), newI);
      newI += section.end - section.start;
    }

    const toShuffle = this.sections.filter((s) => s.type === "shuffle");
    shuffleArray(toShuffle);
    for (const section of toShuffle) {
      newBuffer.set(this.buffer.slice(section.start, section.end), newI);
      if (this.override) {
        newBuffer.set(this.frameSpeed, newI + 4);
      }
      newI += section.end - section.start;
    }

    for (const section of this.sections.filter((s) => s.type === "end")) {
      newBuffer.set(this.buffer.slice(section.start, section.end), newI);
      newI += section.end - section.start;
    }

    return newBuffer;
  }
}
