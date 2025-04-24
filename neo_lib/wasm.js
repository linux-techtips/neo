const buffer = await Bun.file("math.wasm").arrayBuffer();

const module = await WebAssembly.instantiate(buffer);

const { add, square } = module.instance.exports;

console.log("Add: ", add(34, 35));
console.log("Square: ", square(2));
