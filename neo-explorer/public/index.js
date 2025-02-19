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

  tokenize: function (text) {
    const { ptr, len } = this.source_alloc(text);
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

globalThis.libneo = libneo;

const text = "Hello World! 2 + 2 = 4";
console.log(text);

const { ptr, len } = libneo.tokenize(text);
const tokenBuffer = new Uint16Array(libneo.memory.buffer, ptr, len);
const byteBuffer = new Uint8Array(
  tokenBuffer.buffer,
  tokenBuffer.byteOffset,
  tokenBuffer.byteLength,
);

for (let i = 0; i < byteBuffer.length; i += 2) {
  const [tag, len] = [byteBuffer[i], byteBuffer[i + 1]];
  console.log(`Token { ${libneo.token_name(tag)}, ${len} }`);
}

libneo.free({ ptr, len });
