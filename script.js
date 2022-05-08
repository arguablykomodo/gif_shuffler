import { GifShuffler } from "./gif.js";

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

shuffleButton.addEventListener("click", () => {
  if (!imageData) alert("Please upload a file");
  try {
    const buffer = new GifShuffler(
      imageData,
      overrideInput.checked,
      speedInput.valueAsNumber,
    ).shuffle();
    shuffledImg.src = URL.createObjectURL(new Blob([buffer]));
    shuffledFigure.classList.remove("hidden");
  } catch (e) {
    alert(e);
  }
});
