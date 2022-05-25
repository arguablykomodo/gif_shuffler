/** @type {HTMLInputElement} */
const fileInput = document.getElementById("file");
/** @type {HTMLInputElement} */
const overrideInput = document.getElementById("override");
/** @type {HTMLInputElement} */
const speedInput = document.getElementById("speed");
/** @type {HTMLInputElement} */
const seedInput = document.getElementById("seed");
/** @type {HTMLButtonElement} */
const shuffleButton = document.getElementById("shuffle");
/** @type {HTMLElement} */
const originalFigure = document.getElementById("originalFigure");
/** @type {HTMLImageElement} */
const originalImg = document.getElementById("original");
/** @type {HTMLElement} */
const shuffledFigure = document.getElementById("shuffledFigure");
/** @type {HTMLImageElement} */
const shuffledImg = document.getElementById("shuffled");

/** @type {Uint8Array | undefined} */
let imageData;

async function loadFile() {
  const file = fileInput.files?.[0];
  if (file) {
    const buffer = await file.arrayBuffer();
    imageData = new Uint8Array(buffer);
    originalImg.src = URL.createObjectURL(file);
    originalFigure.classList.remove("hidden");
    shuffledFigure.classList.add("hidden");
  } else {
    originalFigure.classList.add("hidden");
  }
}

loadFile();
fileInput.addEventListener("change", loadFile);

if (seedInput.value === "") seedInput.value = Math.floor(Math.random() * Number.MAX_SAFE_INTEGER);
speedInput.disabled = !overrideInput.checked;
overrideInput.addEventListener("change", () => {
  speedInput.disabled = !overrideInput.checked;
});

const { instance: { exports } } = await WebAssembly.instantiateStreaming(
  fetch("main.wasm"),
  { env: { print: console.log, ret } },
);

/**
 * @param {number} ptr
 * @param {number} len
 */
function ret(ptr, len) {
  const buffer = new Uint8Array(exports.memory.buffer, ptr, len);
  shuffledImg.src = URL.createObjectURL(new Blob([buffer]));
  shuffledFigure.classList.remove("hidden");
  exports.free(ptr, len);
}

const errors = {
  OutOfMemory: "WASM has ran out of memory",
  WrongHeader: "Are you sure this is a GIF file?",
  UnknownBlock: "Unknown block found in file",
  UnknownExtensionBlock: "Unknown extension block found in file",
  MissingColorTable: "No global or local color table found",
  BlockAndStreamEndMismatch:
    "End of LZW stream doesn't match end of sub-blocks",
};

shuffleButton.addEventListener("click", async () => {
  if (!imageData) alert("Please upload a file");
  else try {
    /** @type {number} */
    const ptr = exports.alloc(imageData.length);
    const buffer = new Uint8Array(exports.memory.buffer, ptr, imageData.length);
    buffer.set(imageData);
    /** @type {number} */
    const result = exports.main(
      ptr,
      imageData.length,
      BigInt(seedInput.value),
      overrideInput.checked,
      speedInput.valueAsNumber / 10,
    );
    if (result !== 0) {
      const keyBuffer = new Uint8Array(exports.memory.buffer, result, 25);
      let i = 0;
      while (keyBuffer[i] !== 0) i += 1;
      const key = new TextDecoder().decode(keyBuffer.slice(0, i));
      alert(errors[key]);
    }
  } catch (e) {
    alert(e);
  }
});
