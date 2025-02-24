Bun.serve({
  port: 3000,
  fetch(req) {
    const url = new URL(req.url).pathname;
    const path = "./public" + (url === "/" ? "/index.html" : url);
    const file = Bun.file(path);

    return new Response(file);
  },
  error() {
    return new Response(null, { status: 404 });
  },
});
