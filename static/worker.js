/**
 * @typedef {object} ShuffleRequest
 * @property {Uint8Array} imageData
 * @property {bigint} seed
 * @property {boolean} speedOverride
 * @property {number} speed
 * @property {boolean} loopOverride
 * @property {number} loop
 * @property {number} swapRatio
 * @property {number} swapDistance
 */

const { instance: { exports } } = await WebAssembly.instantiateStreaming(
  fetch("gif_shuffler.wasm"),
  { env: { print: console.log, ret } },
);

const errors = {
  OutOfMemory: "WASM has ran out of memory",
  NoSpaceLeft: "Frame buffer has ran out of memory",
  WrongHeader: "Are you sure this is a GIF file?",
  UnknownBlock: "Unknown block found in file",
  UnknownExtensionBlock: "Unknown extension block found in file",
  MissingColorTable: "No global or local color table found",
  BlockAndStreamEndMismatch:
    "End of LZW stream doesn't match end of sub-blocks",
};

/**
 * @param {number} ptr
 * @param {number} len
 */
function ret(ptr, len) {
  const buffer = new Uint8Array(exports.memory.buffer, ptr, len);
  postMessage({ success: true, buffer });
  exports.free(ptr, len);
}

self.addEventListener("message", (e) => {
  /** @type {ShuffleRequest} */
  const data = e.data;
  /** @type {number} */
  const ptr = exports.alloc(data.imageData.length);
  const buffer = new Uint8Array(
    exports.memory.buffer,
    ptr,
    data.imageData.length,
  );
  buffer.set(data.imageData);
  /** @type {number} */
  const result = exports.main(
    ptr,
    data.imageData.length,
    data.seed,
    data.speedOverride,
    data.speed,
    data.loopOverride,
    data.loop,
    data.swapRatio,
    data.swapDistance,
  );
  if (result !== 0) {
    const keyBuffer = new Uint8Array(exports.memory.buffer, result, 25);
    let i = 0;
    while (keyBuffer[i] !== 0) i += 1;
    const key = new TextDecoder().decode(keyBuffer.slice(0, i));
    postMessage({ success: false, error: errors[key] });
  }
});
