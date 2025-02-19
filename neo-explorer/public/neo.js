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
    const ptr = this.exports.Neo_Token_Name(tag);
    const unbounded = new Uint8Array(this.memory.buffer, ptr);

    let i = 0;
    for (; unbounded[i] !== 0; i += 1);

    const buffer = new Uint8Array(this.memory.buffer, ptr, i);
    return this.decoder.decode(buffer);
  },

  tokenize: function (text) {
    const { ptr, len } = this.source_alloc(text);
    const tokensInt = this.exports.Neo_Tokenize(ptr, len);
    return bigIntToSlice(tokensInt);
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


