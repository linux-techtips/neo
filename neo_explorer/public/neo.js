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
  exports: module?.instance.exports,
  memory,

  token_name: function (tag) {
    const { ptr, len } = bigIntToSlice(this.exports.Neo_Token_Name(tag));

    const buffer = new Uint8Array(this.memory.buffer, ptr, len);

    return this.decoder.decode(buffer);
  },

  tokenize: function ({ ptr, len }) {
    return bigIntToSlice(this.exports.Neo_Tokenize(ptr, len));
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
    return { ptr: this.exports.Neo_Alloc(len), len };
  },

  free: function ({ ptr, len }) {
    this.exports.Neo_Free(ptr, len);
  },
};

export const Neo = class {
  constructor() {
    this.listeners = new Set();
  }

  set onemit(listener) {
    this.listeners.add(listener);
  }

  emit(text, mode) {
    const output = !text ? "" : this.handleEmit(text, mode);
    this.listeners.forEach((listener) => listener(output));
  }

  handleEmit(text, mode) {
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
            tokens.len,
          );

          return renderTokens(buffer);
        }
        case "parse": {
          tokens = libneo.tokenize(source);
          tree = libneo.parse(tokens);
          const buffer = new Uint8Array(
            libneo.memory.buffer,
            tree.ptr,
            tree.len,
          );

          return renderTokens(buffer);
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
    return `.{ .tag = ${tag}, .len = ${len} }`;
  }

  renderTokens(buffer) {
    let output = "";
    for (let i = 0; i < buffer.length; i += 2) {
      const tag = buffer[i];

      let len = buffer[i + 1];
      if (len === 0) {
        const upper = buffer[i + 2];
        const lower = buffer[i + 3];

        len = (upper << 8) | lower;
        i += 2;
      }

      output += this.renderToken({ tag, len });
    }
  }

  renderTree(buffer) {
    let output = "";
    for (let i = buffer.length; i > 0; i -= 2) {
      const tag = buffer[i];

      let len = buffer[i - 1];
      if (len === 0) {
        const upper = buffer[i - 2];
        const lower = buffer[i - 3];

        len = (upper << 8) | lower;
      }

      output += this.renderToken({ tag, len });
    }
  }
};
