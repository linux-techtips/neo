const buffer = await Bun.file("math.wasm").arrayBuffer();

const module = await WebAssembly.instantiate(buffer);

const { add, square, foo } = module.instance.exports;

console.log(foo());
