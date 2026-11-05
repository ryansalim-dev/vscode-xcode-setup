// Talks to the build server configured in .bsp/skbsp.json the way SourceKit-LSP does when VS Code
// opens a Swift file: initialize, list targets, find the file's target, ask for its compiler arguments.
// Used by the CI test for setup-vscode-xcode.sh (Bazel mode).
//
// node bsp-test.mjs --workspace <dir> --file <abs source path>
import { spawn } from "node:child_process";
import fs from "node:fs";
import { pathToFileURL } from "node:url";

const args = {};
for (let i = 2; i < process.argv.length; i += 2) args[process.argv[i].replace(/^--/, "")] = process.argv[i + 1];
const log = (...a) => console.log("[bsp]", ...a);
let server;
const fail = (msg) => { console.error("[bsp] FAIL:", msg); try { server && server.kill(); } catch {} process.exit(1); };
setTimeout(() => fail("timed out after 18 minutes"), 18 * 60_000).unref();

const cfg = JSON.parse(fs.readFileSync(`${args.workspace}/.bsp/skbsp.json`, "utf8"));
log("argv:", JSON.stringify(cfg.argv));
server = spawn(cfg.argv[0], cfg.argv.slice(1), { cwd: args.workspace, stdio: ["pipe", "pipe", "inherit"] });
server.on("exit", (c, s) => log("server exited", c, s));

let seq = 1, buf = Buffer.alloc(0);
const pending = new Map();
function write(obj) {
  const body = JSON.stringify({ jsonrpc: "2.0", ...obj });
  server.stdin.write(`Content-Length: ${Buffer.byteLength(body)}\r\n\r\n${body}`);
}
function request(method, params, ms = 15 * 60_000) {
  const id = seq++;
  write({ id, method, params });
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    setTimeout(() => reject(new Error(`${method}: no answer within ${ms / 1000}s`)), ms).unref();
  });
}
server.stdout.on("data", (chunk) => {
  buf = Buffer.concat([buf, chunk]);
  for (;;) {
    const sep = buf.indexOf("\r\n\r\n");
    if (sep < 0) return;
    const len = Number(/Content-Length: (\d+)/i.exec(buf.slice(0, sep).toString())[1]);
    if (buf.length < sep + 4 + len) return;
    const msg = JSON.parse(buf.slice(sep + 4, sep + 4 + len).toString());
    buf = buf.slice(sep + 4 + len);
    if (msg.id !== undefined && msg.method) {
      log("server request", msg.method);
      write({ id: msg.id, result: null }); // e.g. window/workDoneProgress/create
    } else if (msg.id !== undefined) {
      const p = pending.get(msg.id);
      pending.delete(msg.id);
      if (p) msg.error ? p.reject(new Error(JSON.stringify(msg.error))) : p.resolve(msg.result);
    } else if (msg.method) {
      const p = msg.params || {};
      const text = p.message || (p.value && (p.value.message || p.value.title)) || "";
      if (text) log(msg.method, String(text).slice(0, 300));
    }
  }
});

async function main() {
  const rootUri = pathToFileURL(args.workspace).href;
  const fileUri = pathToFileURL(args.file).href;
  const init = await request("build/initialize", {
    displayName: "ci", version: "1.0", bspVersion: "2.2.0", rootUri,
    capabilities: { languageIds: ["swift", "objective-c", "c"] },
  });
  log("initialized:", JSON.stringify(init).slice(0, 600));
  write({ method: "build/initialized", params: {} });

  const { targets } = await request("workspace/buildTargets", {});
  log(`${targets.length} build targets:`, targets.map((t) => t.displayName || t.id.uri).join(", "));
  if (!targets.length) fail("no build targets");

  const { items } = await request("buildTarget/sources", { targets: targets.map((t) => t.id) });
  const owner = items.find((it) => it.sources.some((s) => s.uri === fileUri || decodeURIComponent(s.uri).endsWith(args.file)));
  if (!owner) {
    items.forEach((it) => log(it.target.uri, it.sources.map((s) => s.uri).join(" ")));
    fail(`no target lists ${args.file}`);
  }
  log("file belongs to", owner.target.uri);

  try {
    const prep = await request("buildTarget/prepare", { targets: [owner.target] });
    log("prepare:", JSON.stringify(prep));
  } catch (e) { log("prepare failed (continuing):", e.message); }

  const opts = await request("textDocument/sourceKitOptions", {
    textDocument: { uri: fileUri }, target: owner.target, language: "swift",
  });
  const argv = (opts && opts.compilerArguments) || [];
  log(`${argv.length} compiler arguments; workingDirectory=${opts && opts.workingDirectory}`);
  log(argv.slice(0, 40).join(" "));
  const mod = argv.indexOf("-module-name");
  if (mod < 0) fail("compiler arguments have no -module-name");
  log("module:", argv[mod + 1]);
  if (!argv.some((a) => a.endsWith("Greeter.swift"))) fail("compiler arguments don't include the file");

  await request("build/shutdown", null, 30_000).catch(() => {});
  write({ method: "build/exit" });
  log("PASS");
  setTimeout(() => process.exit(0), 500);
}
main().catch((e) => fail(e.stack || e.message));
