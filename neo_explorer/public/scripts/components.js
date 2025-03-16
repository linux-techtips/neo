const debounce = function (ms, fn) {
  let timeout;
  return (...args) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => fn.apply(this, args), ms);
  };
};

export const Window = class extends HTMLElement {
  constructor() {
    super();
  }

  // connectedCallback() {
  //   this.editor = this.querySelector("ui-editor");
  //   this.output = this.querySelector("ui-output");
  //   this.slider = this.querySelector(".slider");

  //   this.resizing = false;

  //   this.slider.onmousedown = (event) => this.handleSliderDown(event);
  //   this.onmousemove = (event) => this.handleSliderMove(event);
  //   this.onmouseup = () => this.handleSliderUp();
  // }

  // handleSliderDown(event) {
  //   this.resizing = true;
  //   this.startX = event.clientX;
  //   this.startWidth = parseInt(getComputedStyle(this.output).width, 10);
  // }

  // handleSliderMove(event) {
  //   if (this.resizing) {
  //     const offset = this.startX - event.clientX;
  //     const width = Math.abs(offset + this.startWidth);
  //     this.style.setProperty("--output-width", `${width}px`);
  //   }
  // }

  // handleSliderUp() {
  //   this.resizing = false;
  // }
};

export const Editor = class extends HTMLElement {
  constructor() {
    super();
  }

  connectedCallback() {
    this.lines = this.querySelector(".editor-lines");
    this.text = this.querySelector("textarea");
    this.mode = "tokenize";

    this.text.onscroll = () =>
      (this.lines.style.transform = `translateY(-${this.text.scrollTop}px)`);
    this.text.oninput = () => this.handleInput();
    this.text.onkeydown = (event) => {
      if (event.ctrlKey) {
        if (event.key === "-") {
          event.preventDefault();
          this.handleFontSizeChange(-2);
        }
        if (event.key === "=") {
          event.preventDefault();
          this.handleFontSizeChange(2);
        }
      }

      if (event.key === "Tab") {
        event.preventDefault();
        this.handleTabInput();
      }
    };

    window.neo.onmodechange = (mode) => this.handleModeChange(mode);

    this.loadContent();
  }

  handleTabInput() {
    const start = this.text.selectionStart;
    const end = this.text.selectionEnd;

    this.text.value =
      this.text.value.slice(0, start) + "\t" + this.text.value.slice(end);

    this.text.selectionStart = this.text.selectionEnd = start + 1;
  }

  handleFontSizeChange(amount) {
    const oldSize = parseInt(getComputedStyle(this.text).fontSize, 10);
    const newSize = Math.max(Math.min(oldSize + amount, 40), 10);

    this.lines.style.fontSize = `${newSize}px`;
    this.text.style.fontSize = `${newSize}px`;
  }

  handleModeChange(mode) {
    this.mode = mode;
    this.handleEmit();
  }

  handleInput() {
    debounce(2000, () => this.saveContent());
    debounce(0, () => this.handleEmit())();
    this.render();
    this.saveContent();
  }

  handleEmit() {
    window.neo.emit(this.text.value, this.mode);
  }

  saveContent() {
    localStorage.setItem("editorText", this.text.value);
  }

  loadContent() {
    this.text.value = localStorage.getItem("editorText") || "";
    this.render();
  }

  render() {
    this.lines.innerHTML = this.text.value
      .split("\n")
      .map((_, index) => `<div class="line-number">${index}</div>`)
      .join("");
  }
};

export const Output = class extends HTMLElement {
  constructor() {
    super();
  }

  connectedCallback() {
    this.mode = this.querySelector("select");
    this.code = this.querySelector("code");

    this.mode.onchange = () => window.neo.changeMode(this.mode.value);
    window.neo.onemit = (output, _) => (this.code.innerHTML = output);

    window.neo.changeMode(this.mode.value);
  }
};

export const Stats = class extends HTMLElement {
  constructor() {
    super();
  }

  connectedCallback() {
    this.ratio = this.querySelector(".stat-ratio");
    this.time = this.querySelector(".stat-time");
    this.len = this.querySelector(".stat-len");

    window.neo.onemit = (_, stats) => {
      this.ratio.innerHTML = stats.ratio.toFixed(2) + "%";
      this.time.innerHTML = stats.time.toFixed(2) + "ms";
      this.len.innerHTML = stats.len;
    };
  }
};
