const memory = new WebAssembly.Memory({
  initial: 100,
  maximum: 1000,
});

const module = await WebAssembly.instantiate(
  await (await fetch("/neo.wasm")).arrayBuffer(),
  {
    env: { memory },
  },
);

const bigIntToSlice = function (bigInt) {
  return { ptr: Number(bigInt & 0xffffffffn), len: Number(bigInt >> 32n) };
};

export const libneo = {
  encoder: new TextEncoder("utf-8"),
  decoder: new TextDecoder("utf-8"),
  exports: module.instance.exports,
  memory,

  token_name: function (tag) {
    const { ptr, len } = bigIntToSlice(this.exports.Neo_Token_Name(tag));

    const buffer = new Uint8Array(this.memory.buffer, ptr, len);

    return this.decoder.decode(buffer);
  },

  tokenize: function ({ ptr, len }) {
    return bigIntToSlice(this.exports.Neo_Tokenize(ptr, len));
  },

  parse: function ({ ptr, len }) {
    return bigIntToSlice(this.exports.Neo_Parse(ptr, len));
  },

  source_alloc: function (text) {
    const { ptr, len } = this.alloc(text.length, true);

    const encodeBuffer = new Uint8Array(this.memory.buffer, ptr, len);
    this.encoder.encodeInto(text, encodeBuffer);

    const sourceInt = this.exports.Neo_Source_Alloc(ptr, len);
    return bigIntToSlice(sourceInt);
  },

  source_free: function ({ ptr, len }) {
    this.exports.Neo_Source_Free(ptr, len);
  },

  alloc: function (len) {
    const mem = this.exports.Neo_Alloc(len);
    const slice = bigIntToSlice(mem);

    console.debug(slice);

    return slice;
  },

  free: function ({ ptr, len }) {
    this.exports.Neo_Free(ptr, len);
  },
};

export const Neo = class {
  constructor() {
    this.emitListeners = new Set();
    this.modeListeners = new Set();
  }

  set onemit(listener) {
    this.emitListeners.add(listener);
  }

  set onmodechange(listener) {
    this.modeListeners.add(listener);
  }

  changeMode(mode) {
    this.modeListeners.forEach((listener) => listener(mode));
  }

  emit(text, mode) {
    const start = performance.now();
    const { output, len, byteSize } = this.handleEmit(text, mode);
    const end = performance.now();

    const ratio = (len * byteSize) / (!text ? 1 : text.length);
    const time = end - start;
    const stats = { ratio, time, len };

    this.emitListeners.forEach((listener) => listener(output, stats));
  }

  handleEmit(text, mode) {
    if (!text) return { output: "", len: 0, byteSize: 0 };

    let source = libneo.source_alloc(text);
    let tokens = null;
    let tree = null;

    try {
      switch (mode) {
        case "tokenize": {
          tokens = libneo.tokenize(source);
          const buffer = new Uint8Array(
            libneo.memory.buffer,
            tokens.ptr,
            tokens.len * 2,
          );

          return this.renderTokens(buffer);
        }
        case "parse": {
          tokens = libneo.tokenize(source);
          tree = libneo.parse(tokens);

          const buffer = new Uint8Array(
            libneo.memory.buffer,
            tree.ptr,
            tree.len * 2,
          );

          return this.renderTree(buffer);
        }
        default: {
          throw new Error(`Invalid mode: ${mode}`);
        }
      }
    } finally {
      if (source) libneo.source_free(source);
      if (tokens) libneo.free(tokens);
      if (tree) libneo.free(tree);
    }
  }

  renderToken({ tag, len }) {
    return `<div class="line">.{ .tag = "${libneo.token_name(tag)}", .len = ${len} }</div>`;
  }

  renderTokens(buffer) {
    let tokenLen = 0;
    let output = "";

    for (let i = 0; i < buffer.length; i += 2) {
      const tag = buffer[i];
      tokenLen += 1;

      let len = buffer[i + 1];
      if (len === 0) {
        const upper = buffer[i + 3];
        const lower = buffer[i + 2];

        len = (upper << 8) | lower;
        tokenLen += 1;
        i += 2;
      }

      output += this.renderToken({ tag, len });

      if (tag === 128) break;
    }

    return { output, len: tokenLen, byteSize: 2 };
  }

  renderTree(buffer) {
    let nodeLen = 0;
    let output = "";

    for (let i = buffer.length - 1; i >= 0; i -= 2) {
      const tag = buffer[i - 1];
      nodeLen += 1;

      let len = buffer[i];
      if (len === 0) {
        const upper = buffer[i - 2];
        const lower = buffer[i - 3];

        len = (upper << 8) | lower;
        nodeLen += 1;
        i -= 2;
      }

      output += this.renderToken({ tag, len });

      if (tag === 128) break;
    }

    return { output, len: nodeLen, byteSize: 2 };
  }
};
