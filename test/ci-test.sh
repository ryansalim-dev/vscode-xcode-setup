#!/bin/bash
# End-to-end test for setup-vscode-xcode.sh on a real Mac (GitHub Actions macOS runner).
# Runs under /bin/bash on purpose: that's the bash 3.2 every Mac ships with.
#
#   /bin/bash test/ci-test.sh ios     # sample iOS app (XcodeGen), Simulator, LLDB + CodeLLDB
#   /bin/bash test/ci-test.sh macos   # sample Mac app (XcodeGen), run, LLDB
#   /bin/bash test/ci-test.sh bazel   # rules_apple iOS app built with Bazel directly (+ tests, code completion)
#   /bin/bash test/ci-test.sh bazel-xcodeproj   # same app through a rules_xcodeproj-generated project
set -eo pipefail

MODE="${1:-ios}"
HERE="$(cd "$(dirname "$0")" && pwd)"
TOOL="$(cd "$HERE/.." && pwd)"
SETUP="$TOOL/setup-vscode-xcode.sh"
WORK="${RUNNER_TEMP:-$(mktemp -d)}/vscode-setup-$MODE"
LOGS="${RUNNER_TEMP:-/tmp}/vscode-setup-logs"
mkdir -p "$LOGS"
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 HOMEBREW_NO_ENV_HINTS=1

STEP_NAME=""
step() { STEP_NAME="$*"; printf '\n::group::%s\n' "$*"; }
end_step() { echo "::endgroup::"; echo "PASS: $STEP_NAME"; }
fail() { echo "::endgroup::"; echo "::error::$STEP_NAME: $*"; exit 1; }
assert() { local msg="$1"; shift; "$@" || fail "$msg"; }

# wait_for <text> <file> <seconds>
wait_for() {

  for _ in $(seq 1 "$3"); do
    if grep -qF -- "$1" "$2" 2>/dev/null; then return 0; fi
    sleep 1
  done
  echo "---- $2 ----"; cat "$2" 2>/dev/null || true
  return 1
}
# wait_exit <pid> <seconds>
wait_exit() {
  for _ in $(seq 1 "$2"); do kill -0 "$1" 2>/dev/null || return 0; sleep 1; done
  return 1
}
# with_timeout <seconds> <cmd...> (macOS has no `timeout`)
with_timeout() { perl -e 'alarm shift; exec @ARGV or die "exec: $!"' "$@"; }
json_ok() { node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8").replace(/^\/\/.*\n/,""))' "$1"; }
XC() { /bin/bash .vscode/xcode/xc.sh "$@"; }

echo "bash: $BASH_VERSION"
xcodebuild -version
rm -rf "$WORK"

case "$MODE" in
  ios) FIXTURE=SampleApp; SRC=Sources/Greeter.swift ;;
  macos) FIXTURE=SampleMacApp; SRC=Sources/Greeter.swift ;;
  bazel|bazel-xcodeproj) FIXTURE=BazelApp; SRC=App/Sources/Greeter.swift ;;
  *) echo "unknown mode $MODE"; exit 2 ;;
esac
PLATFORM=ios; [ "$MODE" != macos ] || PLATFORM=macos
SETUP_ARGS=(--yes --no-open)
cp -R "$TOOL/test/fixtures/$FIXTURE" "$WORK"
cd "$WORK"
git init -q .
case "$MODE" in
  bazel*)
    bazel --version
    # Hosted macOS runners have 7 GB of RAM. Two Bazel servers (ours and the build server's own
    # output base) plus simulators ran the runner out of memory and took the job down with it.
    printf 'startup --host_jvm_args=-Xmx1g\nbuild --jobs=4\n' >> "$HOME/.bazelrc"
    ;;
esac
mem() { echo "memory: $(vm_stat | awk '/Pages free/ {f=$3} /Pages inactive/ {i=$3} END {printf "%d MB free+inactive", (f+i)*16384/1048576}')"; }

# Leave nothing running: background Bazel servers (including the build server's own output base),
# sourcekit-bazel-bsp and booted simulators can keep the runner from finishing the job.
cleanup() {
  set +e
  pkill -f sourcekit-bazel-bsp 2>/dev/null
  case "$MODE" in bazel*) (cd "$WORK" 2>/dev/null && with_timeout 60 bazel shutdown) >/dev/null 2>&1 ;; esac
  pkill -f 'bazel\(' 2>/dev/null; pkill -f 'A-server.jar' 2>/dev/null
  with_timeout 60 xcrun simctl shutdown all >/dev/null 2>&1
  return 0
}
trap cleanup EXIT

if [ "$MODE" = bazel-xcodeproj ]; then
  step "Generate the Xcode project with rules_xcodeproj"
  bazel run //:xcodeproj 2>&1 | tee "$LOGS/xcodeproj.log" | tail -n 40 || fail "bazel run //:xcodeproj failed"
  assert "BazelApp.xcodeproj not generated" test -d BazelApp.xcodeproj
  xcodebuild -list -project BazelApp.xcodeproj | tee "$LOGS/schemes.txt"
  # A standalone workspace next to the generated project: --xcodeproj must still pick the project.
  mkdir -p Legacy.xcworkspace
  printf '<?xml version="1.0" encoding="UTF-8"?>\n<Workspace version="1.0">\n  <FileRef location="group:BazelApp.xcodeproj"></FileRef>\n</Workspace>\n' \
    > Legacy.xcworkspace/contents.xcworkspacedata
  end_step
  SETUP_ARGS+=(--xcodeproj)
fi

# ─────────────────────────────────────────────────────────────────────────────
step "Setup, first run (installs tools, VS Code, extensions; builds)"
/bin/bash "$SETUP" "${SETUP_ARGS[@]}" 2>&1 | tee "$LOGS/setup-$MODE.log"
for f in .vscode/tasks.json .vscode/launch.json .vscode/settings.json .vscode/extensions.json; do
  assert "$f missing or not valid JSON" json_ok "$f"
done
assert "helper missing" test -x .vscode/xcode/xc.sh
assert ".gitignore not updated" grep -qxF ".vscode/xcode/config.env" .gitignore
# shellcheck source=/dev/null
. .vscode/xcode/config.env
echo "build system=$XC_BUILD_SYSTEM scheme=$XC_SCHEME target=$XC_BAZEL_TARGET platform=$XC_PLATFORM sim=$XC_SIM_NAME ($XC_SIM_UDID)"
case "$MODE" in
  bazel)
    assert "build system is '$XC_BUILD_SYSTEM', not bazel" test "$XC_BUILD_SYSTEM" = bazel
    assert "wrong Bazel target '$XC_BAZEL_TARGET'" test "$XC_BAZEL_TARGET" = //App:App
    assert "no 'Xcode: Select Bazel Target' task" grep -q '"Xcode: Select Bazel Target"' .vscode/tasks.json
    assert ".bsp/skbsp.json (code completion) missing; see .vscode/xcode/.state/skbsp-setup.log" test -f .bsp/skbsp.json
    assert ".sourcekit-lsp/config.json missing" test -f .sourcekit-lsp/config.json
    assert "sourcekit-bazel-bsp binary missing" test -x .bsp/sourcekit-bazel-bsp
    cat .bsp/skbsp.json .sourcekit-lsp/config.json
    ;;
  bazel-xcodeproj)
    assert "build system is '$XC_BUILD_SYSTEM', not xcode" test "$XC_BUILD_SYSTEM" = xcode
    assert "picked '${XC_WORKSPACE:-$XC_PROJECT}', not the rules_xcodeproj project" \
      test "$XC_PROJECT" = BazelApp.xcodeproj -a -z "$XC_WORKSPACE"
    assert "no scheme picked" test -n "$XC_SCHEME"
    ;;
  *)
    assert "buildServer.json missing" test -f buildServer.json
    assert "XcodeGen project not generated" test -d "$FIXTURE.xcodeproj"
    assert "wrong scheme '$XC_SCHEME'" test "$XC_SCHEME" = "$FIXTURE"
    ;;
esac
assert "wrong platform '$XC_PLATFORM'" test "$XC_PLATFORM" = "$PLATFORM"
[ "$PLATFORM" != ios ] || assert "no simulator picked" test -n "$XC_SIM_UDID"
LLDB_LIB="$(node -e 'console.log(JSON.parse(require("fs").readFileSync(".vscode/settings.json","utf8").replace(/^\/\/.*\n/,""))["lldb.library"]||"")')"
assert "lldb.library not set to an existing file ($LLDB_LIB)" test -f "$LLDB_LIB"
code --list-extensions | tee "$LOGS/extensions.txt"
assert "Swift extension not installed" grep -qi '^swiftlang.swift-vscode$' "$LOGS/extensions.txt"
assert "CodeLLDB not installed" grep -qi '^vadimcn.vscode-lldb$' "$LOGS/extensions.txt"
end_step

# ─────────────────────────────────────────────────────────────────────────────
step "Setup, second run changes nothing"
before="$(cat .vscode/*.json .vscode/xcode/config.env .gitignore | shasum)"
/bin/bash "$SETUP" "${SETUP_ARGS[@]}" --no-build > "$LOGS/setup-rerun-$MODE.log" 2>&1 || { cat "$LOGS/setup-rerun-$MODE.log"; fail "re-run failed"; }
after="$(cat .vscode/*.json .vscode/xcode/config.env .gitignore | shasum)"
assert "re-running changed the generated files" test "$before" = "$after"
end_step

# ─────────────────────────────────────────────────────────────────────────────
step "Build errors are picked up by the Problems panel matcher"
src="$SRC"
cp "$src" "$LOGS/original.swift"
printf '\nlet ciBrokenValue: Int = "not an int"\n' >> "$src"
if XC build > "$LOGS/broken-build.log" 2>&1; then cp "$LOGS/original.swift" "$src"; fail "build with a type error succeeded"; fi
cp "$LOGS/original.swift" "$src"
node -e '
const fs = require("fs");
const tasks = JSON.parse(fs.readFileSync(".vscode/tasks.json","utf8").replace(/^\/\/.*\n/,""));
const errs = tasks.tasks.find(t => t.label === "Xcode: Build").problemMatcher
  .filter(m => m.severity === "error").map(m => new RegExp(m.pattern.regexp));
const lines = fs.readFileSync(process.argv[1],"utf8").split("\n");
const hits = lines.flatMap(l => errs.map(re => l.match(re)).filter(Boolean));
hits.forEach(m => console.log("matched:", m[1] + ":" + m[2] + ":" + m[3], "-", m[4]));
if (!hits.some(m => m[1].endsWith(process.argv[2]))) { console.log(lines.join("\n")); process.exit(1); }
' "$LOGS/broken-build.log" "$src" || fail "the error matcher didn't find the error in $src"
XC build > "$LOGS/rebuild.log" 2>&1 || { cat "$LOGS/rebuild.log"; fail "rebuild after fixing failed"; }
end_step

STATE=.vscode/xcode/.state

if [ "$PLATFORM" = ios ]; then
  # ───────────────────────────────────────────────────────────────────────────
  step "Xcode: Run launches on the Simulator and streams output"
  XC run > "$LOGS/run.log" 2>&1 &
  run_pid=$!
  wait_for "hello-from-sample-app" "$LOGS/run.log" 300 || fail "app output never appeared"
  wait_for "tick 2" "$LOGS/run.log" 30 || fail "output stopped streaming"
  XC stop
  wait_exit "$run_pid" 20 || fail "run task didn't end after Stop App"
  end_step

  LINE="$(grep -n CI_BREAKPOINT "$SRC" | cut -d: -f1)"

  # ───────────────────────────────────────────────────────────────────────────
  step "F5 hand-off works with Xcode's LLDB (attach, breakpoint, variables)"
  XC debug-prepare > "$LOGS/prepare-lldb.log" 2>&1 &
  prep_pid=$!
  wait_for "XC_DEBUG_READY" "$LOGS/prepare-lldb.log" 300 || fail "debug-prepare never got ready"
  cat "$STATE/target.lldb" "$STATE/process.lldb" "$STATE/settings.env"
  [ ! -f "$STATE/bazel.lldbinit" ] || cat "$STATE/bazel.lldbinit"
  cat > "$LOGS/cmds.lldb" <<EOF
command source "$PWD/$STATE/target.lldb"
breakpoint set --file Greeter.swift --line $LINE
command source "$PWD/$STATE/process.lldb"
process continue
frame variable message
thread backtrace -c 3
process detach
EOF
  with_timeout 600 xcrun lldb --batch -s "$LOGS/cmds.lldb" > "$LOGS/lldb.log" 2>&1 || true
  cat "$LOGS/lldb.log"
  grep -q "stop reason = breakpoint" "$LOGS/lldb.log" || fail "breakpoint at Greeter.swift:$LINE was not hit"
  grep -q '"hello-from-sample-app"' "$LOGS/lldb.log" || fail "couldn't read the Swift local 'message'"
  wait_for "tick" "$LOGS/prepare-lldb.log" 30 || fail "app output didn't stream into the debug task"
  XC stop
  wait_exit "$prep_pid" 20 || fail "debug task didn't end after Stop App"
  end_step

  # ───────────────────────────────────────────────────────────────────────────
  step "F5 hand-off works with CodeLLDB (the VS Code debugger), driven over DAP"
  EXT_DIR="$(find "$HOME/.vscode/extensions" -maxdepth 1 -name 'vadimcn.vscode-lldb-*' 2>/dev/null | sort | tail -n 1)"
  assert "CodeLLDB extension folder not found" test -n "$EXT_DIR"
  ADAPTER="$(find "$EXT_DIR" -path '*/adapter/codelldb' -type f 2>/dev/null | head -n 1)"
  if [ -z "$ADAPTER" ]; then
    # Some CodeLLDB builds fetch their platform package (debug adapter) the first time VS Code
    # activates them, which can't happen headless. Fetch the same version's package directly.
    echo "No adapter in $EXT_DIR yet:"; find "$EXT_DIR" -maxdepth 2 | head -n 30
    ver="${EXT_DIR##*vadimcn.vscode-lldb-}"; ver="${ver%%-*}"
    case "$(uname -m)" in arm64) plat=darwin-arm64 ;; *) plat=darwin-x64 ;; esac
    curl -fsSL -o "$WORK.codelldb.vsix" "https://github.com/vadimcn/codelldb/releases/download/v$ver/codelldb-$plat.vsix" \
      || fail "couldn't download CodeLLDB $ver for $plat"
    mkdir -p "$WORK.codelldb" && (cd "$WORK.codelldb" && unzip -q -o "$WORK.codelldb.vsix")
    ADAPTER="$(find "$WORK.codelldb" -path '*/adapter/codelldb' -type f | head -n 1)"
    chmod +x "$ADAPTER" 2>/dev/null || true
  fi
  assert "CodeLLDB adapter binary not found" test -x "$ADAPTER"
  echo "adapter: $ADAPTER"
  XC debug-prepare > "$LOGS/prepare-dap.log" 2>&1 &
  prep_pid=$!
  wait_for "XC_DEBUG_READY" "$LOGS/prepare-dap.log" 300 || fail "debug-prepare never got ready"
  node "$HERE/dap-test.mjs" --adapter "$ADAPTER" --liblldb "$LLDB_LIB" --workspace "$PWD" \
    --file "$PWD/$SRC" --line "$LINE" --var "message=hello-from-sample-app" \
    --console "$STATE/console.log" --expect "hello-from-sample-app" 2>&1 | tee "$LOGS/dap.log" \
    || fail "CodeLLDB session failed (see log above)"
  XC stop
  wait_exit "$prep_pid" 20 || fail "debug task didn't end after Stop App"
  end_step
else
  # ───────────────────────────────────────────────────────────────────────────
  step "Xcode: Run launches the Mac app"
  XC run > "$LOGS/run-mac.log" 2>&1 &
  run_pid=$!
  wait_for "Running" "$LOGS/run-mac.log" 300 || fail "app didn't start"
  sleep 8
  kill -0 "$run_pid" 2>/dev/null || { cat "$LOGS/run-mac.log"; fail "app exited right away"; }
  XC stop
  wait_exit "$run_pid" 20 || fail "app still running after Stop App"
  end_step

  # ───────────────────────────────────────────────────────────────────────────
  step "F5 hand-off works with Xcode's LLDB (launch, stop in main)"
  XC debug-prepare > "$LOGS/prepare-mac.log" 2>&1 || { cat "$LOGS/prepare-mac.log"; fail "debug-prepare failed"; }
  grep -q XC_DEBUG_READY "$LOGS/prepare-mac.log" || fail "debug-prepare didn't signal ready"
  cat > "$LOGS/cmds.lldb" <<EOF
command source "$PWD/$STATE/target.lldb"
breakpoint set --name main
command source "$PWD/$STATE/process.lldb"
thread backtrace 1
process kill
EOF
  with_timeout 120 xcrun lldb --batch -s "$LOGS/cmds.lldb" > "$LOGS/lldb-mac.log" 2>&1 || true
  cat "$LOGS/lldb-mac.log"
  grep -q "stop reason = breakpoint" "$LOGS/lldb-mac.log" || fail "didn't stop in main"
  end_step
fi

if [ "$MODE" = bazel ] || [ "$MODE" = bazel-xcodeproj ]; then
  # ───────────────────────────────────────────────────────────────────────────
  step "Xcode: Test runs the unit tests"
  xcrun simctl shutdown all >/dev/null 2>&1 || true   # the test runner boots its own simulator
  mem
  with_timeout 1500 /bin/bash .vscode/xcode/xc.sh test > "$LOGS/test.log" 2>&1 \
    || { tail -n 80 "$LOGS/test.log"; fail "tests failed or took over 25 minutes"; }
  tail -n 15 "$LOGS/test.log"
  end_step
fi

if [ "$MODE" = bazel ]; then
  # ───────────────────────────────────────────────────────────────────────────
  step "Code completion: sourcekit-bazel-bsp answers SourceKit-LSP's requests"
  # The build server runs its own Bazel server; stop ours and the simulators to leave it the memory.
  bazel shutdown >/dev/null 2>&1 || true
  xcrun simctl shutdown all >/dev/null 2>&1 || true
  mem
  with_timeout 1200 node "$HERE/bsp-test.mjs" --workspace "$PWD" --file "$PWD/$SRC" 2>&1 | tee "$LOGS/bsp.log" \
    || fail "the Bazel build server didn't return compiler arguments for $SRC"
  end_step
fi

echo
echo "All $MODE checks passed."
