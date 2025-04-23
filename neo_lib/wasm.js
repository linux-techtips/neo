const buffer = await Bun.file('test.wasm').arrayBuffer();

const module = await WebAssembly.instantiate(buffer);

const { square } = module.instance.exports;

console.log(square(2, 2));
