/*
 * Serves the example at http://127.0.0.1:<port>/web/ with the packages it imports beside it:
 * /packages/shadowlist-wasm/ from the engine checkout and every other /packages/<name>/ from this
 * repository. The engine's browser test serves the same layout.
 *   node --experimental-strip-types serve.ts [port]
 * The engine checkout is SHADOWLIST_ROOT (default ../shadowlist next to this repository).
 */
import { existsSync, readFileSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { createRequire } from 'node:module';
import { extname, join, normalize } from 'node:path';

const { wasmRoot } = createRequire(import.meta.url)('../../shadowlist.js') as {
  wasmRoot: string;
};
const EXAMPLE = new URL('.', import.meta.url).pathname;
const PACKAGES = new URL('../../packages/', import.meta.url).pathname;
const KIT = `${wasmRoot}/`;
const PORT = Number(process.argv[2] ?? 8080);

const TYPES: Record<string, string> = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.wasm': 'application/wasm',
  '.json': 'application/json',
  '.map': 'application/json',
};

/*
 * The folder and the path inside it for a request, or null outside the layout.
 */
function locate(pathname: string): [string, string] | null {
  if (pathname.startsWith('/web/')) {
    return [EXAMPLE, pathname.slice('/web/'.length) || 'index.html'];
  }
  if (pathname.startsWith('/packages/shadowlist-wasm/')) {
    return [KIT, pathname.slice('/packages/shadowlist-wasm/'.length)];
  }
  if (pathname.startsWith('/packages/')) {
    return [PACKAGES, pathname.slice('/packages/'.length)];
  }
  return null;
}

createServer((request, response) => {
  const url = new URL(request.url!, 'http://x');
  const pathname = decodeURIComponent(url.pathname);
  if (pathname === '/' || pathname === '/web') {
    response.writeHead(302, { Location: `/web/${url.search}` }).end();
    return;
  }
  const located = locate(pathname);
  const path = located && normalize(join(...located));
  if (
    !path ||
    !path.startsWith(located![0]) ||
    !existsSync(path) ||
    !statSync(path).isFile()
  ) {
    response.writeHead(404).end();
    return;
  }
  response.writeHead(200, {
    'Content-Type': TYPES[extname(path)] ?? 'application/octet-stream',
  });
  response.end(readFileSync(path));
}).listen(PORT, '127.0.0.1', () => {
  console.log(`shadowlist web example: http://127.0.0.1:${PORT}/web/`);
  console.log(`shadowlist-wasm from ${KIT}`);
});
