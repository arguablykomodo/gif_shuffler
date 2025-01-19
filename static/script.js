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
const swapRatioInput = document.getElementById("swapRatio");
/** @type {HTMLInputElement} */
const swapDistanceInput = document.getElementById("swapDistance");
/** @type {HTMLInputElement} */
const seedInput = document.getElementById("seed");
/** @type {HTMLButtonElement} */
const shuffleButton = document.getElementById("shuffle");
/** @type {HTMLDivElement} */
const errorDiv = document.getElementById("error");
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
  errorDiv.textContent = "";
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

/**
 * @param {string} message
 */
function reportError(message) {
  shuffleButton.disabled = false;
  shuffledFigure.classList.add("hidden");
  errorDiv.textContent = message;
}

/**
 * @typedef {object} ShuffleSuccess
 * @property {true} success
 * @property {Uint8Array} buffer
 */

/**
 * @typedef {object} ShuffleError
 * @property {false} success
 * @property {string} error
 */

const worker = new Worker("worker.js", { type: "module" });

worker.addEventListener("message", (e) => {
  /** @type {ShuffleSuccess | ShuffleError} */
  const data = e.data;
  if (data.success) {
    shuffleButton.disabled = false;
    shuffledImg.src = URL.createObjectURL(
      new Blob([data.buffer], { type: "image/gif" }),
    );
  } else reportError(data.error);
});

worker.addEventListener("error", (e) => {
  e.preventDefault();
  reportError(e.message);
});

shuffleButton.addEventListener("click", async () => {
  if (!imageData) reportError("Please upload a file");
  else {
    errorDiv.textContent = "";
    shuffleButton.disabled = true;
    shuffledFigure.classList.remove("hidden");
    shuffledImg.width = originalImg.width;
    shuffledImg.height = originalImg.height;
    shuffledImg.src = "loading.svg";
    worker.postMessage({
      imageData,
      seed: BigInt(seedInput.value),
      speedOverride: speedOverrideInput.checked,
      speed: speedInput.valueAsNumber / 10,
      loopOverride: loopOverrideInput.checked,
      loop: loopInput.valueAsNumber,
      swapRatio: swapRatioInput.valueAsNumber / 100,
      swapDistance: swapDistanceInput.valueAsNumber,
    });
  }
});
