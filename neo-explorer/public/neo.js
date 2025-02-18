const memory = new WebAssembly.Memory({
  initial: 100,
  maximum: 1000,
});

const module = await WebAssembly.instantiateStreaming(
  await fetch("/neo.wasm"),
  {
    env: { memory },
  },
);

const bigIntToSlice = function (bigInt) {
  return { ptr: Number(bigInt & 0xffffffffn), len: Number(bigInt >> 32n) };
};

const libneo = {
  exports: module.instance.exports,
  encoder: new TextEncoder("utf-8"),
  decoder: new TextDecoder("utf-8"),
  memory,

  source_alloc: function (text) {
    const { ptr: textPtr, len: textLen } = this.alloc(text.length);
    if (textPtr == 0) throw new Error("Failed to allocate memory for text");

    const encodeBuffer = new Uint8Array(this.memory.buffer, textPtr, textLen);
    this.encoder.encodeInto(text, encodeBuffer);

    const sourceInt = this.exports.Neo_Source_Alloc(textPtr, textLen);
    if (sourceInt == 0n)
      throw new Error("Failed to allocate memory for result");

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
