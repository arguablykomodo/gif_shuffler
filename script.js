/** @type {HTMLInputElement} */
const fileInput = document.getElementById("file");
/** @type {HTMLInputElement} */
const overrideInput = document.getElementById("override");
/** @type {HTMLInputElement} */
const speedInput = document.getElementById("speed");
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

speedInput.disabled = !overrideInput.checked;
overrideInput.addEventListener("change", () => {
  speedInput.disabled = !overrideInput.checked;
});

const { instance: { exports } } = await WebAssembly.instantiateStreaming(
  fetch("main.wasm"),
  { env: { print: console.log, ret } },
);

function ret(ptr, len) {
  const buffer = new Uint8Array(exports.memory.buffer, ptr, len);
  shuffledImg.src = URL.createObjectURL(new Blob([buffer]));
  shuffledFigure.classList.remove("hidden");
  exports.free(ptr, len);
}

shuffleButton.addEventListener("click", async () => {
  if (!imageData) alert("Please upload a file");
  try {
    /** @type {number} */
    const ptr = exports.alloc(imageData.length);
    const buffer = new Uint8Array(exports.memory.buffer, ptr, imageData.length);
    buffer.set(imageData);
    exports.shuffle(ptr, imageData.length, 0n, overrideInput.checked, speedInput.valueAsNumber / 10);
  } catch (e) {
    alert(e);
  }
});
