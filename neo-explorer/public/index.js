const memory = new WebAssembly.Memory({ initial: 10, maximum: 100 });
const module = await WebAssembly.instantiateStreaming(
  await fetch("/neo.wasm"),
  {
    env: { memory },
  },
);

const libneo = module.instance.exports;

const message = "Hello World";
console.log(`Input: ${message}`);

const input = new Uint8Array(memory.buffer);
const { written } = new TextEncoder().encodeInto(message, input);

const ptr = libneo.Neo_Test(0, written);
const output = new Uint8Array(memory.buffer, ptr, written);
const text = new TextDecoder().decode(output);

console.log(`Output ${text}`);
