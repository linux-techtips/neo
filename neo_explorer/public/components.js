import { Neo } from "./neo.js";

export const Window = class extends HTMLElement {};

export const Output = class extends HTMLElement {
  constructor() {
    super();
  }

  connectedCallback() {}
};

export const Editor = class extends HTMLElement {
  constructor() {
    super();
  }

  connectedCallback() {
    this.text = this.querySelector(".editor-text");

    this.text.oninput = (event) => this.handleInput(event);
  }

  handleInput(event) {}

  render() {}
};
