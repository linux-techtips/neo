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
    if (textPtr == 0) throw new Error("Failed to allocate memory for text");
    console.log(textPtr, textLen);

    const encodeBuffer = new Uint8Array(memory.buffer, textPtr, textLen);
    this.encoder.encodeInto(text, encodeBuffer);

    console.log(encodeBuffer);

    const sourceInt = this.exports.Neo_Source_Alloc(textPtr, textLen);
    if (sourceInt == 0n)
      throw new Error("Failed to allocate memory for result");

    const sourcePtr = Number(sourceInt & 0xffffffffn);
    const sourceLen = Number(sourceInt >> 32n);

    console.log(sourcePtr, sourceLen);

    const decodeBuffer = new Uint8Array(memory.buffer, sourcePtr, sourceLen);
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
libneo.make_source("Hello Cruel and unforgiving world");
