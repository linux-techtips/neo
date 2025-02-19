import './neo.js'

// placeholder, replaced with dom interaction 
const text = "\"Hello, world.\", 5 + 2";

const source = libneo.source_alloc(text);
const tokens = libneo.tokenize(source);

