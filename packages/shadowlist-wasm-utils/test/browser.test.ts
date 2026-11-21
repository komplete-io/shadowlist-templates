/*
 * The utilities in headless Chrome through the web example of this repository, driven over the
 * DevTools protocol. Skipped when no Chrome is found (CHROME_PATH picks the binary) or when the
 * example is not built. Run the example's build first. The kit comes from the engine checkout
 * at SHADOWLIST_ROOT (default ../shadowlist next to this repository).
 */
import assert from 'node:assert/strict';
import { spawn, type ChildProcess } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { createServer, type Server } from 'node:http';
import { createRequire } from 'node:module';
import { tmpdir } from 'node:os';
import { extname, join, normalize } from 'node:path';
import { after, before, test } from 'node:test';

const { wasmRoot } = createRequire(import.meta.url)(
  '../../../shadowlist.js'
) as {
  wasmRoot: string;
};
// The engine's kit package, served at /packages/shadowlist-wasm/.
const KIT = `${wasmRoot}/`;
// This repository's packages, served at /packages/<name>/.
const PACKAGES = new URL('../../', import.meta.url).pathname;
// The web example, served at /web/.
const WEB_EXAMPLE = new URL(
  '../../../examples/shadowlist-web-example/',
  import.meta.url
).pathname;
const WEB_EXAMPLE_SKIP = existsSync(join(WEB_EXAMPLE, 'dist/main.js'))
  ? false
  : `the web example at ${WEB_EXAMPLE} is not built`;
let serverPort = 0;
let browserPort = 0;

const CHROME_CANDIDATES = [
  process.env.CHROME_PATH ?? '',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/usr/bin/google-chrome',
  '/usr/bin/google-chrome-stable',
  '/usr/bin/chromium',
  '/usr/bin/chromium-browser',
];
// SHADOWLIST_WASM_BROWSER=0 skips the browser tests.
const CHROME =
  process.env.SHADOWLIST_WASM_BROWSER === '0'
    ? undefined
    : CHROME_CANDIDATES.find((path) => path && existsSync(path));

const TYPES: Record<string, string> = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.wasm': 'application/wasm',
};

let server: Server | null = null;
let chrome: ChildProcess | null = null;
let profile = '';
let page: Page | null = null;

/*
 * One tab over its DevTools WebSocket.
 */
class Page {
  private nextId = 0;
  private readonly pending = new Map<
    number,
    { resolve: (value: unknown) => void; reject: (error: Error) => void }
  >();
  readonly errors: string[] = [];
  private readonly socket: WebSocket;

  private constructor(socket: WebSocket) {
    this.socket = socket;
    socket.addEventListener('message', (event) => {
      const message = JSON.parse(String(event.data));
      const waiting = this.pending.get(message.id);
      if (waiting) {
        this.pending.delete(message.id);
        if (message.error) waiting.reject(new Error(message.error.message));
        else waiting.resolve(message.result);
      } else if (message.method === 'Runtime.exceptionThrown') {
        this.errors.push(JSON.stringify(message.params.exceptionDetails));
      }
    });
  }

  static async open(
    debugPort: number,
    url: string,
    ready = 'window.fixtureReady === true'
  ): Promise<Page> {
    const response = await fetch(
      `http://127.0.0.1:${debugPort}/json/new?about:blank`,
      { method: 'PUT' }
    );
    const target = (await response.json()) as { webSocketDebuggerUrl: string };
    const socket = new WebSocket(target.webSocketDebuggerUrl);
    await new Promise((resolve, reject) => {
      socket.addEventListener('open', resolve);
      socket.addEventListener('error', reject);
    });
    const opened = new Page(socket);
    await opened.send('Runtime.enable');
    await opened.send('Network.setCacheDisabled', { cacheDisabled: true });
    await opened.send('Emulation.setDeviceMetricsOverride', {
      width: 800,
      height: 900,
      deviceScaleFactor: 1,
      mobile: false,
    });
    await opened.send('Page.navigate', { url });
    for (let attempt = 0; attempt < 200; ++attempt) {
      if (await opened.evaluate(ready)) return opened;
      await new Promise((resolve) => setTimeout(resolve, 25));
    }
    throw new Error(`fixture did not load: ${opened.errors.join('\n')}`);
  }

  send(method: string, params: object = {}): Promise<unknown> {
    const id = ++this.nextId;
    this.socket.send(JSON.stringify({ id, method, params }));
    return new Promise((resolve, reject) =>
      this.pending.set(id, { resolve, reject })
    );
  }

  /*
   * The value of an expression in the page, awaited when it is a promise.
   */
  async evaluate<T = unknown>(expression: string): Promise<T> {
    const result = (await this.send('Runtime.evaluate', {
      expression,
      awaitPromise: true,
      returnByValue: true,
    })) as {
      result: { value: T };
      exceptionDetails?: { exception?: { description?: string } };
    };
    if (result.exceptionDetails) {
      throw new Error(
        result.exceptionDetails.exception?.description ?? 'evaluate failed'
      );
    }
    return result.result.value;
  }

  close(): void {
    this.socket.close();
  }
}

function serve(): Promise<number> {
  server = createServer((request, response) => {
    const pathname = decodeURIComponent(
      new URL(request.url!, 'http://x').pathname
    );
    const web = pathname.startsWith('/web/');
    const kit = pathname.startsWith('/packages/shadowlist-wasm/');
    const root = web ? WEB_EXAMPLE : kit ? KIT : PACKAGES;
    let relative = web
      ? pathname.slice('/web/'.length)
      : kit
        ? pathname.slice('/packages/shadowlist-wasm/'.length)
        : pathname.slice('/packages/'.length);
    if (web && relative === '') relative = 'index.html';
    const path = normalize(join(root, relative));
    if (!path.startsWith(root) || !existsSync(path)) {
      response.writeHead(404).end();
      return;
    }
    response.writeHead(200, {
      'Content-Type': TYPES[extname(path)] ?? 'application/octet-stream',
    });
    response.end(readFileSync(path));
  });
  return new Promise((resolve) =>
    server!.listen(0, '127.0.0.1', () => {
      const address = server!.address();
      resolve(typeof address === 'object' && address ? address.port : 0);
    })
  );
}

function launchChrome(): Promise<number> {
  profile = mkdtempSync(join(tmpdir(), 'shadowlist-wasm-utils-'));
  const flags = [
    '--headless=new',
    '--remote-debugging-port=0',
    `--user-data-dir=${profile}`,
    '--no-first-run',
    '--no-default-browser-check',
    'about:blank',
  ];
  if (process.platform === 'linux') flags.unshift('--no-sandbox');
  chrome = spawn(CHROME!, flags, { stdio: ['ignore', 'ignore', 'pipe'] });
  return new Promise((resolve, reject) => {
    let output = '';
    chrome!.stderr!.on('data', (chunk: Buffer) => {
      output += chunk.toString();
      const match = /DevTools listening on ws:\/\/[^:]+:(\d+)\//.exec(output);
      if (match) resolve(Number(match[1]));
    });
    chrome!.on('exit', () => reject(new Error(`Chrome exited: ${output}`)));
  });
}

before(async () => {
  if (!CHROME || WEB_EXAMPLE_SKIP) return;
  const [port, debugPort] = await Promise.all([serve(), launchChrome()]);
  serverPort = port;
  browserPort = debugPort;
  page = await Page.open(
    debugPort,
    `http://127.0.0.1:${port}/packages/shadowlist-wasm-utils/test/fixture.html`
  );
});

after(async () => {
  chrome?.removeAllListeners('exit');
  // Chrome writes its profile until it exits. Remove the profile after that.
  if (chrome && chrome.exitCode === null) {
    const exited = new Promise((resolve) => chrome!.once('exit', resolve));
    // DevTools closes Chrome after its profile is flushed, including the extra example tabs.
    page?.send('Browser.close').catch(() => {});
    await Promise.race([
      exited,
      new Promise((resolve) => setTimeout(resolve, 5000).unref()),
    ]);
    if (chrome.exitCode === null) {
      chrome.kill();
      await exited;
    }
  }
  page?.close();
  server?.close();
  if (profile) {
    rmSync(profile, {
      recursive: true,
      force: true,
      maxRetries: 10,
      retryDelay: 100,
    });
  }
});

const browserTest = (name: string, body: (tab: Page) => Promise<void>) =>
  test(name, { skip: CHROME ? WEB_EXAMPLE_SKIP : 'no Chrome found' }, () =>
    body(page!)
  );

browserTest(
  'actual web Feed and controlled Poll use the utility binary',
  async (tab) => {
    const result = await tab.evaluate<{
      initials: string;
      time: string;
      before: string;
      after: string;
      switched: string;
      reset: string;
      selected: string[];
      independent: boolean;
    }>(`(async () => {
    const kit = await import('shadowlist-wasm');
    const utils = await import('shadowlist-wasm-utils');
    const independent = kit.isShadowListKitLoaded() && !utils.isShadowListUtilsLoaded() && !performance.getEntriesByType('resource').some(entry => entry.name.endsWith('shadowlistutils.wasm'));
    await utils.loadShadowListUtils();
    const { feedScreen, pollScreen } = await import('/web/dist/Screens.js');
    const { FeedPost, feedTime } = await import('/web/dist/Fixtures.js');
    const feedBody = document.createElement('div');
    document.body.replaceChildren(feedBody);
    const feed = feedScreen(feedBody);
    await frames(4);
    const initials = feedBody.querySelector('.avatar')?.textContent;
    const time = feedTime(new FeedPost(3).createdAtMs);
    feed.remove();
    const body = document.createElement('div');
    document.body.replaceChildren(body);
    const poll = pollScreen(body);
    await frames(4);
    const summary = () => body.querySelector('.banner').textContent;
    const option = (index) => poll.cellForItem(index).view.querySelector('button');
    const before = summary();
    option(1).click();
    await frames(4);
    const after = summary();
    const selected = [0, 1, 2].map(option).filter(button => button.getAttribute('aria-pressed') === 'true').map(button => button.textContent);
    option(2).click();
    await frames(4);
    const switched = summary();
    body.querySelector('.toolbar button').click();
    await frames(4);
    const reset = summary();
    return { initials, time, before, after, switched, reset, selected, independent };
  })()`);
    assert.equal(result.independent, true);
    assert.ok(result.initials?.length > 0);
    assert.equal(result.time, '3h');
    assert.match(result.before, /16 votes$/);
    assert.match(result.after, /17 votes$/);
    assert.match(result.switched, /17 votes$/);
    assert.match(result.reset, /0 votes$/);
    assert.deepEqual(result.selected, ['Coast · 35% · 6 votes']);
    assert.deepEqual(tab.errors, []);
  }
);

browserTest(
  'actual web routes load utilities only for their helper consumers',
  async () => {
    for (const route of [
      'Chat',
      'Masonry',
      'Horizontal',
      'Feed',
      'Poll',
      'Sticky',
    ]) {
      const tab = await Page.open(
        browserPort,
        `http://127.0.0.1:${serverPort}/web/?SLRoute=${route}&SLCount=20`,
        'Boolean(window.list)'
      );
      try {
        const result = await tab.evaluate<{
          loaded: boolean;
          mounted: number;
          errors: string[];
        }>(`(async () => {
        await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
        return {
          loaded: performance.getEntriesByType('resource').some(entry => entry.name.endsWith('shadowlistutils.wasm')),
          mounted: window.list.visibleCells.length,
        };
      })()`);
        assert.equal(
          result.loaded,
          ['Feed', 'Poll', 'Sticky'].includes(route),
          route
        );
        assert.ok(result.mounted > 0, `${route} mounted its actual cells`);
        assert.deepEqual(tab.errors, [], route);
      } finally {
        await tab.send('Page.navigate', { url: 'about:blank' });
        tab.close();
      }
    }
  }
);
