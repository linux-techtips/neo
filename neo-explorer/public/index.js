import './neo.js';

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