import './neo.js'

const output = document.getElementById("token-text");
const input = document.getElementById("neo-code-input-box");

const debounce = function (fn, delay) {
  let timeout = null;
  return (...args) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => fn(...args), delay);
  };
};

const handleTokenize = function (text) {
  const start = performance.now();

  const report = () => {
    const end = performance.now();
    console.log(`tokenization took ${end - start}ms`);
  };

  if (!text) {
    output.textContent = "";
    report();
    return;
  }

  const source = libneo.source_alloc(text);
  const tokens = libneo.tokenize(source);

  try {
    const tokenBuffer = new Uint16Array(
      libneo.memory.buffer,
      tokens.ptr,
      tokens.len,
    );
    const byteBuffer = new Uint8Array(
      tokenBuffer.buffer,
      tokenBuffer.byteOffset,
      tokenBuffer.byteLength,
    );

    let outputText = "";
    for (let i = 0; i < byteBuffer.length; i += 2) {
      const [tag, len] = [byteBuffer[i], byteBuffer[i + 1]];
      outputText += `Token { ${libneo.token_name(tag)}, ${len} }\n`;

      // TODO: Remove hardcoded eof check.
      if (tag === 128) break;
    }

    output.textContent = outputText;
  } finally {
    libneo.free(tokens);
    libneo.source_free(source);
    report();
  }
};

input.addEventListener("input", () => debounce(handleTokenize, 0)(input.value));