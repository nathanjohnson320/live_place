// https://www.redditinc.com/blog/how-we-built-rplace
import Panzoom from "@panzoom/panzoom";

export default class Grid {
  el = null;
  id = null;
  size = null;
  selected = [0, 0];
  selectedColor = new Uint8ClampedArray([255, 255, 255, 255]);
  canvas = null;
  overlay = null;
  ctx = null;
  overlayCtx = null;

  constructor({ id, size }, el) {
    this.el = el;
    this.id = id;
    this.size = size;
    this.canvas = document.getElementById("place-canvas");
    this.overlay = document.getElementById("overlay-canvas");

    this.ctx = this.canvas.getContext("2d", { alpha: false });
    this.overlayCtx = this.overlay.getContext('2d');

    this.el.handleEvent("set_pixel", this.writePixel.bind(this));
    this.el.handleEvent("sync_pixels", this.syncPixels.bind(this));
    this.el.handleEvent("select_color", this.selectColor.bind(this));
    this.el.handleEvent("clear_overlay", this.clearOverlay.bind(this));

    const container = document.getElementById("place-control");
    this.panzoom = Panzoom(container, { maxScale: 40 });
    this.canvas.parentElement.addEventListener(
      "wheel",
      this.panzoom.zoomWithWheel
    );

    this.overlay.addEventListener("click", (event) => {
      this.selectPixel(event);
    });

    container.addEventListener("panzoomzoom", ({ detail: { scale } }) => {
      document.getElementById("zoom").innerHTML = `${scale.toFixed(2)}x`;
    });
  }

  writePixel({x, y, rgb}) {
    const view = new Uint8ClampedArray(rgb);
    this.ctx.putImageData(new ImageData(view, 1, 1), x, y);
  }

  syncPixels({pixels}) {
    pixels.forEach((pixel) => this.writePixel(pixel));
  }

  clearOverlay() {
    this.overlayCtx.clearRect(0, 0, this.overlay.width, this.overlay.height);
  }

  selectColor({ color }) {
    const view = new Uint8ClampedArray(color);
    this.selectedColor = view;
    this.writeOverlay();
  }

  writeOverlay() {
    this.overlayCtx.putImageData(new ImageData(this.selectedColor, 1, 1), this.selected[0], this.selected[1]);
  }

  selectPixel(e) {
    this.clearOverlay();

    const [x, y] = this.getCursorPosition(e);
    this.selected = [x, y];
    this.writeOverlay();
    this.el.pushEvent("select_pixel", { x, y });
  }

  getCursorPosition(event) {
    const scale = this.panzoom.getScale();
    const rect = this.canvas.getBoundingClientRect();
    const x = event.clientX - rect.left;
    const y = event.clientY - rect.top;

    return [Math.floor((x - scale) / scale), Math.floor((y - scale) / scale)];
  }

  load() {
    fetch(`/api/places/${this.id}/pixels`, {
      credentials: "same-origin",
    })
      .then((response) => {
        return response.blob();
      })
      .then((blob) => {
        return blob.arrayBuffer();
      })
      .then((buffer) => {
        const view = new Uint8ClampedArray(buffer);
        this.ctx.putImageData(new ImageData(view, this.size, this.size), 0, 0);
      });
  }
}
