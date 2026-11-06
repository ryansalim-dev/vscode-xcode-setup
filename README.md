# VS Code for Xcode projects, in one step

[![CI](https://github.com/ryansalim-dev/vscode-xcode-setup/actions/workflows/ci.yml/badge.svg)](https://github.com/ryansalim-dev/vscode-xcode-setup/actions/workflows/ci.yml)

`setup-vscode-xcode.sh` turns any `.xcodeproj` / `.xcworkspace` folder, or a **Bazel**
(rules_apple) workspace, into a VS Code project that can **build, run on the Simulator, test and
debug with breakpoints** without opening Xcode.
Xcode still has to be *installed* (it provides the compiler, SDKs and simulators); it just never
has to be launched.

**Contents**

1. [Requirements](#requirements)
2. [Step 1: Get the tool](#step-1-get-the-tool)
3. [Step 2: Set up your project](#step-2-set-up-your-project)
4. [Step 3: First launch in VS Code](#step-3-first-launch-in-vs-code)
5. [Everyday use](#everyday-use): [build](#build), [run](#run-without-the-debugger), [debug](#debug), [test](#test), [clean](#clean), [switch scheme or simulator](#switch-scheme-or-simulator), [code completion](#code-completion)
6. [Bazel projects](#bazel-projects)
7. [Optional: Xcode-style shortcuts](#optional-xcode-style-keyboard-shortcuts)
8. [Using it from the terminal](#using-it-from-the-terminal)
9. [Adding files, and what still needs Xcode](#adding-files-and-what-still-needs-xcode)
10. [Troubleshooting](#troubleshooting)
11. [What the setup changes in your project](#what-the-setup-changes-in-your-project)
12. [How it works](#how-it-works) and [developing the script](#developing-the-script)

## Requirements

- A Mac with **Xcode 15 or newer** installed (from the App Store or developer.apple.com).
  You don't have to open it.
- An app project: a folder with a `.xcodeproj` or `.xcworkspace`, or an XcodeGen (`project.yml`),
  Tuist or CocoaPods project, or a Bazel workspace with rules_apple apps (see
  [Bazel projects](#bazel-projects)).
- Everything else (Homebrew, VS Code, the command-line tools and the VS Code extensions) is
  installed for you if it's missing. The script asks before installing Homebrew or VS Code.

## Step 1: Get the tool

```bash
git clone https://github.com/ryansalim-dev/vscode-xcode-setup ~/vscode-xcode-setup
```

(Or download the repo as a zip from GitHub and unzip it to `~/vscode-xcode-setup`.)

**Optional, recommended:** install it as a command so you can run it in any project with one word. It's a link, so a `git pull` in `~/vscode-xcode-setup` keeps the command up to date:

```bash
ln -sf ~/vscode-xcode-setup/setup-vscode-xcode.sh "$(brew --prefix 2>/dev/null || echo /usr/local)/bin/xcode-vscode"
```

## Step 2: Set up your project

Pick whichever is easiest. All three do the same thing.

**A. Double-click (no terminal):**

1. In Finder, open `~/vscode-xcode-setup` and double-click **Setup VS Code for Xcode.command**.
2. Pick your project folder (the one containing the `.xcodeproj` / `.xcworkspace`).
3. A Terminal window shows the progress. Press any key to close it when it says **All set**.

If macOS refuses to open the file the first time, run this once and try again:
`chmod +x ~/vscode-xcode-setup/*.command ~/vscode-xcode-setup/*.sh && xattr -c ~/vscode-xcode-setup/*`
(or right-click the file, then **Open**).

**B. Terminal:**

```bash
cd ~/Code/MyApp                                   # your project folder
bash ~/vscode-xcode-setup/setup-vscode-xcode.sh   # or just: xcode-vscode
```

**C. Terminal, with choices made up front** (no questions asked):

```bash
xcode-vscode --scheme MyApp --simulator "iPhone 17 Pro" --yes
```

**What happens** (takes 1 to 5 minutes the first time, mostly downloads and the first build):

| Step | What it does |
|---|---|
| 1. Checking Xcode | Confirms Xcode is installed and selected, accepts the license / first-launch setup if needed (asks for your password), and offers to enable Developer Mode so the debugger doesn't ask for your password later. |
| 2. Command-line tools | Installs Homebrew if missing, then `xcode-build-server` (code completion for Xcode projects) and `xcbeautify` (readable build logs). Adds XcodeGen or CocoaPods only if your project uses them. |
| 3. VS Code | Installs VS Code if it's missing. |
| 4. Find the project | Generates the project first if needed (`xcodegen generate`, `tuist generate`, `pod install`), then picks the `.xcworkspace` (or `.xcodeproj`). Asks if there are several. |
| 5. Scheme and simulator | Picks the scheme named after your project; **asks** only when that's unclear. Picks the newest iPhone simulator (or the one already booted). |
| 6. VS Code files | Writes the build/run/debug tasks and settings into `.vscode/`. |
| 7. Extensions | Installs the **Swift** and **CodeLLDB** extensions. |
| 8. First build | Builds once so code completion works as soon as VS Code opens. A failing build here is fine; fix it in VS Code. |

VS Code then opens your project.

## Step 3: First launch in VS Code

1. If VS Code asks **"Do you trust the authors of the files in this folder?"**, choose **Yes, I trust
   the authors**. Tasks and debugging are disabled in untrusted folders.
2. Give the Swift extension a few seconds to start (watch the status bar). Open a `.swift` file
   and check that completion and **Cmd+click** (jump to definition) work.
3. Press **Shift+Cmd+B** to build, then **F5** to run it on the Simulator with the debugger. That's it.

## Everyday use

Every action below is a VS Code **task** whose name starts with `Xcode:`. To run any task:
**Cmd+Shift+P → "Tasks: Run Task" → pick it**. Each one opens its own terminal panel at the bottom.

### Build

1. Press **Shift+Cmd+B** (or run the task **Xcode: Build**).
2. The terminal shows a short, readable build log and ends with **Build succeeded** or **Build failed**.
3. Errors and warnings appear in the **Problems** panel (**Shift+Cmd+M**). Click one to jump to the line.

### Run (without the debugger)

1. Run the task **Xcode: Run**.
2. It builds, boots the simulator, installs the app and launches it. The **Simulator** app comes to the front.
3. Everything the app prints (`print`, `NSLog`) streams into that task's terminal.
4. To stop: press **Ctrl+C** in that terminal, or run **Xcode: Stop App**.

For a Mac app the binary is launched directly and its output shows in the same terminal.

### Debug

1. Set a breakpoint: click in the gutter left of a line number (a red dot appears).
2. Press **F5** (or open **Run and Debug** in the sidebar, choose **Xcode: Debug**, press the play button).
3. VS Code builds, installs and launches the app paused, then attaches the debugger. Breakpoints are
   hit even in early code like your `App.init` or `application(_:didFinishLaunchingWithOptions:)`.
4. While stopped:
   - **Variables** and **Call Stack** are in the Run and Debug sidebar. Hover over a variable in
     the editor to see its value.
   - Step with the toolbar or **F10** (step over), **F11** (step into), **Shift+F11** (step out),
     **F5** (continue).
   - Type LLDB commands in the **Debug Console** (**Shift+Cmd+Y**), for example `po someObject`,
     `p count`, `expr flag = true`, `bt`.
5. **Where's my app's output?** For iOS apps it streams in the terminal tab named
   **Xcode: Prepare Debug** (in the Terminal panel). For Mac apps it's in the Debug Console.
6. To stop: **Shift+F5** (or the red square). The app is terminated for you. Press **F5** again
   to rebuild and relaunch.

The first F5 after changing code rebuilds, so it takes as long as a build.

### Test

1. Run the task **Xcode: Test** (or **Cmd+Shift+P → "Tasks: Run Test Task"**).
2. It runs `xcodebuild test` for the scheme on the selected simulator and prints each test's result.
   Failures appear in the terminal with file and line.

The scheme needs a test action (in Xcode terms: the scheme's **Test** section includes your test target).

### Clean

Run the task **Xcode: Clean** when a build behaves oddly. It cleans the build products and the
cached app paths. The next build is a full one.

### Switch scheme or simulator

- **Xcode: Select Scheme**: lists the schemes in your project, type a number and press Enter. The
  platform (iOS, macOS, tvOS, watchOS, visionOS) is detected automatically and code completion is
  re-pointed at the new scheme. Run **Swift: Restart LSP Server** afterwards.
- **Xcode: Select Simulator**: lists every installed simulator for the scheme's platform, newest OS
  first. Type a number and press Enter.
- **Xcode: Open Simulator**: boots the selected simulator and brings Simulator.app forward without
  building anything.
- **Xcode: Show Info**: prints the current workspace, scheme, configuration, simulator, app path
  and bundle id.

Your choices are saved in `.vscode/xcode/config.env` and kept when you re-run the setup.

### Code completion

Completion, jump to definition, find references and inline errors come from the Swift extension
(SourceKit-LSP), which reads your Xcode project through `buildServer.json`.

- It needs at least one successful build. Build after pulling big changes.
- If completions look stale or a file shows bogus errors: **Cmd+Shift+P → "Swift: Restart LSP Server"**.
- After switching scheme, or if it stops working entirely: run the task
  **Xcode: Refresh Code Completion**, then build, then restart the LSP server.

## Bazel projects

Bazel workspaces (a folder with `MODULE.bazel` or `WORKSPACE`) are supported in two ways. Run the
setup from the **workspace root**, the same way as for any other project (Step 2).

### Route 1: Bazel directly (the default, recommended)

No Xcode project is needed. When the setup finds `MODULE.bazel` / `WORKSPACE`, it:

1. Installs Bazel (bazelisk, via Homebrew) if it isn't installed.
2. Finds your apps with `bazel query` (every `ios_application`, `macos_application`,
   `tvos_application`, `watchos_application` and `visionos_application`) and asks which one to use
   if there are several. To skip the question, pass the label:

   ```bash
   bash ~/vscode-xcode-setup/setup-vscode-xcode.sh --target //App:App
   ```
3. Sets up code completion (see below) and does a first `bazel build`.

After that, everything in [Everyday use](#everyday-use) works the same way:

| You do | What runs |
|---|---|
| **Shift+Cmd+B** (Xcode: Build) | `bazel build -c dbg --ios_multi_cpus=sim_arm64 //App:App` (the CPU flag matches the platform and your Mac) |
| **Xcode: Run** | Build, unpack the `.ipa`, install it on the simulator with `simctl`, launch, stream `print()` output |
| **F5** | Build, launch paused, attach Xcode's LLDB with breakpoints in your sources |
| **Xcode: Test** | `bazel test` on every `*_unit_test` / `*_ui_test` target, or on `XC_BAZEL_TEST_TARGETS` |
| **Xcode: Select Bazel Target** | Pick another app target (replaces *Select Scheme*) |
| **Xcode: Clean** | `bazel clean` |

Compiler errors show in the Problems panel, and so do Bazel's own errors in `BUILD` files.

Settings in `.vscode/xcode/config.env`:

| Setting | Meaning |
|---|---|
| `XC_BAZEL_TARGET` | The app target, e.g. `//App:App` |
| `XC_BAZEL_ARGS` | Extra flags for build and test, e.g. `"--config=sim"` |
| `XC_BAZEL_TEST_TARGETS` | Test targets for *Xcode: Test*, e.g. `"//App:AppTests //Core:CoreTests"` |
| `XC_CONFIGURATION` | `Debug` (`-c dbg`, the default) or `Release` (`-c opt`) |

Your `.bazelrc` is used as usual; the setup never edits `MODULE.bazel`, `WORKSPACE` or BUILD files.

**Code completion** comes from [sourcekit-bazel-bsp](https://github.com/spotify/sourcekit-bazel-bsp),
Spotify's build server that lets SourceKit-LSP (the Swift extension's language server) understand
Bazel targets. The setup downloads a pinned release and writes `.bsp/` and `.sourcekit-lsp/`
(both added to `.gitignore`), the same files its `setup_sourcekit_bsp` rule would write, so you
don't need to add it to `MODULE.bazel`. The first time you open a Swift file, indexing builds the
app's libraries in the background (progress shows in the status bar), so completion can take a
few minutes to appear on a large app. If your project already sets up sourcekit-bazel-bsp itself,
the setup leaves your `.bsp/skbsp.json` alone. Run **Xcode: Refresh Code Completion** after
switching targets if completion seems to be for the wrong app.

### Route 2: an Xcode project generated by rules_xcodeproj

If you already use [rules_xcodeproj](https://github.com/MobileNativeFoundation/rules_xcodeproj),
generate the project first and add `--xcodeproj`:

```bash
bazel run //:xcodeproj          # or whatever your xcodeproj target is called
bash ~/vscode-xcode-setup/setup-vscode-xcode.sh --xcodeproj
```

With `--xcodeproj` the generated project wins even if the folder also has a standalone
`.xcworkspace` (it's recognized by the `rules_xcodeproj/` folder inside it). To pick a specific one,
pass `--project path/To/App.xcodeproj` instead.

The generated project is then treated like any other Xcode project: builds go through
`xcodebuild` (which calls Bazel for you), and you pick schemes instead of targets. F5 loads the
project's lldbinit, so breakpoints resolve in Bazel-built code. Re-run `bazel run //:xcodeproj`
when you add targets or change BUILD files. Code completion goes through `xcode-build-server`,
which only sees what Xcode-style builds record, so for Bazel projects it's weaker than route 1.

**Which one?** Route 1 is faster (no project generation), has better code completion and works
with any rules_apple app. Route 2 is useful if your team already relies on the generated project
and its schemes.

## Optional: Xcode-style keyboard shortcuts

To get **Cmd+R** (run), **Cmd+U** (test), **Cmd+.** (stop) and **Shift+Cmd+K** (clean) like in Xcode,
open **Cmd+Shift+P → "Preferences: Open Keyboard Shortcuts (JSON)"** and add:

```jsonc
[
  { "key": "cmd+r",       "command": "workbench.action.tasks.runTask", "args": "Xcode: Run" },
  { "key": "cmd+u",       "command": "workbench.action.tasks.runTask", "args": "Xcode: Test" },
  { "key": "cmd+.",       "command": "workbench.action.tasks.runTask", "args": "Xcode: Stop App" },
  { "key": "shift+cmd+k", "command": "workbench.action.tasks.runTask", "args": "Xcode: Clean" }
]
```

These replace VS Code's own uses of those keys (for example Cmd+U is "cursor undo"). Build stays
**Shift+Cmd+B** and debug stays **F5**.

## Using it from the terminal

The same actions work from any terminal in the project folder (handy for scripts or a terminal
you already have open):

```bash
.vscode/xcode/xc.sh build            # build
.vscode/xcode/xc.sh run              # build, launch, stream output (Ctrl+C to stop)
.vscode/xcode/xc.sh test             # run tests
.vscode/xcode/xc.sh stop             # terminate the app
.vscode/xcode/xc.sh clean            # clean
.vscode/xcode/xc.sh select-scheme --prompt
.vscode/xcode/xc.sh select-sim --prompt
.vscode/xcode/xc.sh info             # what's selected, where the app is
.vscode/xcode/xc.sh logs             # follow the app output of the last debug session
.vscode/xcode/xc.sh help
```

Setup script options (`setup-vscode-xcode.sh --help`):

| Option | Meaning |
|---|---|
| `[project-folder]` | Folder to set up (default: the current folder). |
| `-s, --scheme NAME` | Scheme to build. |
| `-t, --target LABEL` | Bazel app target, e.g. `//App:App`. |
| `--xcodeproj` | In a Bazel workspace, use the rules_xcodeproj-generated project instead of calling Bazel. |
| `-p, --project PATH` | Use this `.xcodeproj`, e.g. when the folder also has a `.xcworkspace`. |
| `-w, --workspace PATH` | Use this `.xcworkspace`. |
| `-d, --simulator NAME` | Simulator to run on, e.g. `"iPhone 17 Pro"`. |
| `-c, --configuration NAME` | Build configuration (default `Debug`). |
| `-y, --yes` | Never ask; accept every default. |
| `--skip-deps` | Don't install Homebrew, VS Code, tools or extensions. |
| `--no-build` | Skip the first build. |
| `--no-open` | Don't open VS Code at the end. |

## Adding files, and what still needs Xcode

**New Swift files:**

- **XcodeGen / Tuist projects:** create the file, run `xcodegen generate` (or `tuist generate`),
  then build. Re-running this setup also regenerates XcodeGen projects that are missing.
- **Projects using Xcode 16 folders** (the default for projects created in Xcode 16+, shown as
  blue folders in Xcode): new files in those folders are picked up automatically. Just build.
- **Older projects with groups** (yellow folders): new files must be added to the `.xcodeproj`.
  Do that once in Xcode, or convert the group to a folder in Xcode (right-click the group,
  **Convert to Folder**), after which VS Code alone is enough.

**Things VS Code can't do, so you still need Xcode occasionally:** SwiftUI Previews, storyboards
and XIBs (Interface Builder), editing asset catalogs visually, the signing & capabilities editor,
Instruments, and running on a **physical device** (signing plus device debugging). For devices,
the [SweetPad](https://marketplace.visualstudio.com/items?itemName=sweetpad.sweetpad) extension
works alongside this setup.

## Troubleshooting

| Problem | Fix |
|---|---|
| Tasks or F5 do nothing | The folder isn't trusted. **Cmd+Shift+P → "Workspaces: Manage Workspace Trust" → Trust**. |
| No completion, or stale errors in the editor | Build once, then **Swift: Restart LSP Server**. Still broken: run **Xcode: Refresh Code Completion**, build, restart again. |
| Build fails with signing errors for a Mac app | Pick a team once in Xcode (Signing & Capabilities), or sign to run locally by adding `XC_EXTRA_BUILD_ARGS="CODE_SIGN_IDENTITY=-"` to `.vscode/xcode/config.env`. |
| Wrong app launches (scheme builds several apps, e.g. app + watch app) | Set `XC_TARGET=YourAppTarget` in `.vscode/xcode/config.env`. |
| It uses the wrong `.xcworkspace` / `.xcodeproj` | Re-run with `--project path/App.xcodeproj` or `--workspace path/App.xcworkspace`. The choice is saved for later runs. |
| `Unknown option` for a flag in this README | Your installed `xcode-vscode` is an older copy. `git pull` the repo and link it instead of copying: `ln -sf ~/vscode-xcode-setup/setup-vscode-xcode.sh "$(brew --prefix)/bin/xcode-vscode"`. |
| Need extra `xcodebuild` flags | Set `XC_EXTRA_BUILD_ARGS="..."` in `.vscode/xcode/config.env`. |
| "No iOS simulators are installed" | Let the script download the runtime, or run `xcodebuild -downloadPlatform iOS`. |
| The simulator you used is gone after an Xcode update | Nothing to do: the next build picks the same model on the new OS, or the newest iPhone. |
| Debugger asks for your password | `sudo DevToolsSecurity -enable` |
| F5 says the pre-launch task failed | Open the **Xcode: Prepare Debug** terminal for the build error, fix it, press F5 again. |
| Variables show as raw memory or `<unavailable>` | Make sure `lldb.library` in `.vscode/settings.json` points at Xcode's LLDB (re-run the setup to fix it after moving or renaming Xcode). |
| Bazel: "No ios_application/... targets found" | Run the setup from the workspace root (where `MODULE.bazel` is), or pass `--target //path:App`. |
| Bazel: build uses the wrong flags | Put them in `XC_BAZEL_ARGS` in `.vscode/xcode/config.env`, e.g. `"--config=debug"`. |
| Bazel: no completion | Open the Output panel's **SourceKit Language Server** channel. Run **Xcode: Refresh Code Completion**, then **Swift: Restart LSP Server**. Builds with whole-module optimization don't index; use `Debug`. |
| Anything else odd | Re-run the setup. It's safe and fixes most configuration drift. |

## What the setup changes in your project

| File | Purpose | Commit it? |
|---|---|---|
| `.vscode/tasks.json` | The `Xcode: …` tasks | Yes, if you like |
| `.vscode/launch.json` | The `Xcode: Debug` configuration (F5) | Yes, if you like |
| `.vscode/settings.json` | Points CodeLLDB at Xcode's LLDB, hides DerivedData from search | Yes, if you like |
| `.vscode/extensions.json` | Recommends the Swift and CodeLLDB extensions | Yes |
| `.vscode/xcode/xc.sh` | The helper every task calls | Yes, if you commit the tasks |
| `.vscode/xcode/config.env` | Your scheme and simulator | No (added to `.gitignore`) |
| `.vscode/xcode/.state/` | Cached paths, debugger hand-off files | No (added to `.gitignore`) |
| `buildServer.json` | Tells SourceKit-LSP about the Xcode project | No (added to `.gitignore`) |
| `.bsp/`, `.sourcekit-lsp/` | Bazel only: sourcekit-bazel-bsp config and binary | No (added to `.gitignore`) |

**Safe to re-run:** re-running keeps your project/workspace, scheme and simulator choices and anything you added
yourself. Only tasks and launch configs named `Xcode: …` and a handful of settings keys are
rewritten. The first time it changes a file you already had, it saves the original as
`*.before-xcode-setup`. Teammates who pull your committed `.vscode` files just run the setup once.

## How it works

- **Builds** call `xcodebuild` with your workspace/project, scheme, configuration and the selected
  simulator, piped through `xcbeautify`. A VS Code problem matcher turns its errors and warnings
  into Problems entries.
- **Bazel builds** call `bazel build` with `-c dbg` and the simulator CPU flag for the target's
  platform, then find the `.ipa`/`.zip` with `bazel cquery --output=files` and unpack it into
  `.vscode/xcode/.state/app`. From there, install, launch and debugging are the same as for Xcode
  builds. Bazel writes debug paths relative to the workspace (`-debug-prefix-map`), so the LLDB
  hand-off adds `target.source-map` entries that map them back to your folder and external repos.
- **Code completion**: `xcode-build-server` writes `buildServer.json`, which lets SourceKit-LSP
  (used by the Swift extension) read the compiler flags from your last build.
- **Debugging**: F5 runs the *Xcode: Prepare Debug* task, which builds, installs and starts the
  app with `simctl launch --console-pty --wait-for-debugger`, so it sits paused before `main` and
  its output streams through a terminal. The task writes the app's path and process id to two small
  LLDB command files, and the `Xcode: Debug` launch configuration (a CodeLLDB `custom` request)
  sources them to `target create` and `process attach --pid`. CodeLLDB uses **Xcode's own LLDB**,
  because the one it bundles can't read Swift types. Mac apps are launched by LLDB directly.

## Developing the script

Edit the pieces in `src/` (`setup.sh.in`, the `xc.sh` helper, the `gen_vscode.py` generator), then
run `python3 build.py` to rebuild the single-file `setup-vscode-xcode.sh`. CI
(`.github/workflows/ci.yml`) checks the bundle is up to date, runs shellcheck, and on macOS runners
runs `test/ci-test.sh`, which does a real setup with the stock `/bin/bash` 3.2 and then:

- **iOS** (`test/fixtures/SampleApp`, an XcodeGen project): builds, checks a type error lands in
  the Problems matcher, runs on a Simulator with live output, hits a breakpoint and reads a Swift
  local through Xcode's LLDB, and does the same through the CodeLLDB adapter over the Debug
  Adapter Protocol (`test/dap-test.mjs`), which is what VS Code does on F5.
- **macOS** (`test/fixtures/SampleMacApp`): the same setup, run, and a breakpoint in `main`.
- **Bazel** (`test/fixtures/BazelApp`, a rules_apple iOS app): everything the iOS job checks, plus
  `bazel test`, and a check that sourcekit-bazel-bsp returns compiler arguments for a source file
  (`test/bsp-test.mjs`, the requests SourceKit-LSP makes).
- **Bazel through rules_xcodeproj**: the same app via the generated project and `--xcodeproj`.
