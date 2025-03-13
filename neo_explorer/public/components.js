import { Neo } from "./neo.js";

const neo = new Neo();

export const Window = class extends HTMLElement {};

export const Output = class extends HTMLElement {
  constructor() {
    super();
  }

  connectedCallback() {
    this.code = this.querySelector("code");

    neo.onemit = (output) => (this.code.innerHTML = output);
  }
};

export const Editor = class extends HTMLElement {
  constructor() {
    super();

    this.mode = "tokenize";
  }

  connectedCallback() {
    this.text = this.querySelector("textarea");

    neo.onmodechange = (mode) => neo.emit(this.text.value, (this.mode = mode));
    this.text.oninput = () => neo.emit(this.text.value, this.mode);
  }
};
