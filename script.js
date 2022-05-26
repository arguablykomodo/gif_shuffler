/** @type {HTMLInputElement} */
const fileRadio = document.getElementById("fileRadio");
/** @type {HTMLInputElement} */
const fileInput = document.getElementById("file");
/** @type {HTMLInputElement} */
const urlRadio = document.getElementById("urlRadio");
/** @type {HTMLInputElement} */
const urlInput = document.getElementById("url");
/** @type {HTMLInputElement} */
const speedOverrideInput = document.getElementById("speedOverride");
/** @type {HTMLInputElement} */
const speedInput = document.getElementById("speed");
/** @type {HTMLInputElement} */
const loopOverrideInput = document.getElementById("loopOverride");
/** @type {HTMLInputElement} */
const loopInput = document.getElementById("loop");
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
  if (fileRadio.checked) {
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
  } else if (urlRadio.checked) {
    const response = await fetch(urlInput.value);
    const blob = await response.blob();
    imageData = new Uint8Array(await blob.arrayBuffer());
    originalImg.src = URL.createObjectURL(blob);
    originalFigure.classList.remove("hidden");
    shuffledFigure.classList.add("hidden");
  }
}

loadFile();
fileRadio.addEventListener("change", loadFile);
fileInput.addEventListener("change", loadFile);
urlRadio.addEventListener("change", loadFile);
urlInput.addEventListener("change", loadFile);

if (seedInput.value === "") {
  seedInput.value = Math.floor(Math.random() * Number.MAX_SAFE_INTEGER);
}

speedInput.disabled = !speedOverrideInput.checked;
speedOverrideInput.addEventListener("change", () => {
  speedInput.disabled = !speedOverrideInput.checked;
});

loopInput.disabled = !loopOverrideInput.checked;
loopOverrideInput.addEventListener("change", () => {
  loopInput.disabled = !loopOverrideInput.checked;
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
  shuffledImg.src = URL.createObjectURL(
    new Blob([buffer], { type: "image/gif" }),
  );
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
  else {
    try {
      /** @type {number} */
      const ptr = exports.alloc(imageData.length);
      const buffer = new Uint8Array(
        exports.memory.buffer,
        ptr,
        imageData.length,
      );
      buffer.set(imageData);
      /** @type {number} */
      const result = exports.main(
        ptr,
        imageData.length,
        BigInt(seedInput.value),
        speedOverrideInput.checked,
        speedInput.valueAsNumber / 10,
        loopOverrideInput.checked,
        loopInput.valueAsNumber,
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
  }
});
