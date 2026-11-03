# VS Code for Xcode projects, in one step

[![CI](https://github.com/ryansalim-dev/vscode-xcode-setup/actions/workflows/ci.yml/badge.svg)](https://github.com/ryansalim-dev/vscode-xcode-setup/actions/workflows/ci.yml)

`setup-vscode-xcode.sh` turns any `.xcodeproj` / `.xcworkspace` folder into a VS Code project
that can **build, run on the Simulator, test and debug with breakpoints** without opening Xcode.
Xcode still has to be *installed* (it provides the compiler, SDKs and simulators); it just never
has to be launched.

**Contents**

1. [Requirements](#requirements)
2. [Step 1: Get the tool](#step-1-get-the-tool)
3. [Step 2: Set up your project](#step-2-set-up-your-project)
4. [Step 3: First launch in VS Code](#step-3-first-launch-in-vs-code)
5. [Everyday use](#everyday-use): [build](#build), [run](#run-without-the-debugger), [debug](#debug), [test](#test), [clean](#clean), [switch scheme or simulator](#switch-scheme-or-simulator), [code completion](#code-completion)
6. [Optional: Xcode-style shortcuts](#optional-xcode-style-keyboard-shortcuts)
7. [Using it from the terminal](#using-it-from-the-terminal)
8. [Adding files, and what still needs Xcode](#adding-files-and-what-still-needs-xcode)
9. [Troubleshooting](#troubleshooting)
10. [What the setup changes in your project](#what-the-setup-changes-in-your-project)
11. [How it works](#how-it-works) and [developing the script](#developing-the-script)

## Requirements

- A Mac with **Xcode 15 or newer** installed (from the App Store or developer.apple.com).
  You don't have to open it.
- An app project: a folder with a `.xcodeproj` or `.xcworkspace`, or an XcodeGen (`project.yml`),
  Tuist or CocoaPods project.
- Everything else (Homebrew, VS Code, the command-line tools and the VS Code extensions) is
  installed for you if it's missing. The script asks before installing Homebrew or VS Code.

## Step 1: Get the tool

```bash
git clone https://github.com/ryansalim-dev/vscode-xcode-setup ~/vscode-xcode-setup
```

(Or download the repo as a zip from GitHub and unzip it to `~/vscode-xcode-setup`.)

**Optional, recommended:** install it as a command so you can run it in any project with one word:

```bash
install -m 755 ~/vscode-xcode-setup/setup-vscode-xcode.sh "$(brew --prefix 2>/dev/null || echo /usr/local)/bin/xcode-vscode"
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
| Need extra `xcodebuild` flags | Set `XC_EXTRA_BUILD_ARGS="..."` in `.vscode/xcode/config.env`. |
| "No iOS simulators are installed" | Let the script download the runtime, or run `xcodebuild -downloadPlatform iOS`. |
| The simulator you used is gone after an Xcode update | Nothing to do: the next build picks the same model on the new OS, or the newest iPhone. |
| Debugger asks for your password | `sudo DevToolsSecurity -enable` |
| F5 says the pre-launch task failed | Open the **Xcode: Prepare Debug** terminal for the build error, fix it, press F5 again. |
| Variables show as raw memory or `<unavailable>` | Make sure `lldb.library` in `.vscode/settings.json` points at Xcode's LLDB (re-run the setup to fix it after moving or renaming Xcode). |
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

**Safe to re-run:** re-running keeps your scheme and simulator choices and anything you added
yourself. Only tasks and launch configs named `Xcode: …` and a handful of settings keys are
rewritten. The first time it changes a file you already had, it saves the original as
`*.before-xcode-setup`. Teammates who pull your committed `.vscode` files just run the setup once.

## How it works

- **Builds** call `xcodebuild` with your workspace/project, scheme, configuration and the selected
  simulator, piped through `xcbeautify`. A VS Code problem matcher turns its errors and warnings
  into Problems entries.
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
