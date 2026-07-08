const http = require("http");

const LISTEN_HOST = process.env.NEXUS_PROXY_HOST || "0.0.0.0";
const LISTEN_PORT = Number(process.env.NEXUS_PROXY_PORT || 8080);
const TARGET_HOST = process.env.NEXUS_TARGET_HOST || "127.0.0.1";
const TARGET_PORT = Number(process.env.NEXUS_TARGET_PORT || 18080);

const server = http.createServer((clientReq, clientRes) => {
  const headers = { ...clientReq.headers };
  headers.host = headers.host || `${TARGET_HOST}:${TARGET_PORT}`;

  const proxyReq = http.request(
    {
      host: TARGET_HOST,
      port: TARGET_PORT,
      method: clientReq.method,
      path: clientReq.url,
      headers,
    },
    (proxyRes) => {
      clientRes.writeHead(proxyRes.statusCode || 502, proxyRes.headers);
      proxyRes.pipe(clientRes);
    }
  );

  proxyReq.on("error", (error) => {
    clientRes.writeHead(502, { "content-type": "text/plain; charset=utf-8" });
    clientRes.end(`Nexus proxy could not reach WSL backend: ${error.message}\n`);
  });

  clientReq.pipe(proxyReq);
});

server.on("upgrade", (req, socket) => {
  socket.end("HTTP/1.1 501 Not Implemented\r\n\r\n");
});

server.listen(LISTEN_PORT, LISTEN_HOST, () => {
  console.log(`Nexus Windows proxy listening on http://${LISTEN_HOST}:${LISTEN_PORT}/`);
  console.log(`Forwarding to http://${TARGET_HOST}:${TARGET_PORT}/`);
});
