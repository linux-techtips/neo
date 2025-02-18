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

const libneo = {
  exports: module.instance.exports,
  encoder: new TextEncoder("utf-8"),
  decoder: new TextDecoder("utf-8"),

  make_source: function (text) {
    const { ptr: textPtr, len: textLen } = this.alloc(text.length);
    console.log(textPtr, textLen);

    const encodeBuffer = new Uint8Array(memory.buffer, textPtr, textLen);

    console.log(encodeBuffer);

    this.encoder.encodeInto(text, encodeBuffer);

    const sourcePtr = this.exports.Neo_Source_Alloc(textPtr, textLen);
    console.log(sourcePtr);

    const decodeBuffer = new Uint8Array(memory.buffer, sourcePtr, 5);

    console.log(decodeBuffer);
    const source = this.decoder.decode(decodeBuffer);

    console.log(source);
  },

  alloc: function (len) {
    return { ptr: this.exports.Neo_Alloc(len), len };
  },

  dealloc: function ({ ptr, len }) {
    this.exports.Neo_Dealloc(ptr, len);
  },
};

globalThis.libneo = libneo;
