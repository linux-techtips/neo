const memory = new WebAssembly.Memory({
  initial: 100,
  maximum: 1000,
});

const module = await WebAssembly.instantiateStreaming(
  fetch("/neo.wasm", {
    headers: {
      "Content-Type": "application/wasm",
    },
  }),
  { env: { memory } },
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
