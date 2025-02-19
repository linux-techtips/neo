const memory = new WebAssembly.Memory({
  initial: 100,
  maximum: 1000,
});

const module = await WebAssembly.instantiateStreaming(
  await fetch("/neo.wasm"),
  { env: { memory } },
);

const bigIntToSlice = function (bigInt) {
  return { ptr: Number(bigInt & 0xffffffffn), len: Number(bigInt >> 32n) };
};

const libneo = {
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

const output = document.getElementById("output");
const input = document.getElementById("input");

const debounce = function (fn, delay) {
  let timeout = null;
  return (...args) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => fn(...args), delay);
  };
};

const handleTokenize = function (text) {
  const start = performance.now();

  const report = () => {
    const end = performance.now();
    console.log(`tokenization took ${end - start}ms`);
  };

  if (!text) {
    output.textContent = "";
    report();
    return;
  }

  const source = libneo.source_alloc(text);
  const tokens = libneo.tokenize(source);

  try {
    const tokenBuffer = new Uint16Array(
      libneo.memory.buffer,
      tokens.ptr,
      tokens.len,
    );
    const byteBuffer = new Uint8Array(
      tokenBuffer.buffer,
      tokenBuffer.byteOffset,
      tokenBuffer.byteLength,
    );

    let outputText = "";
    for (let i = 0; i < byteBuffer.length; i += 2) {
      const [tag, len] = [byteBuffer[i], byteBuffer[i + 1]];
      outputText += `Token { ${libneo.token_name(tag)}, ${len} }\n`;

      // TODO: Remove hardcoded eof check.
      if (tag === 128) break;
    }

    output.textContent = outputText;
  } finally {
    libneo.free(tokens);
    libneo.source_free(source);
    report();
  }
};

input.addEventListener("input", () => debounce(handleTokenize, 0)(input.value));
