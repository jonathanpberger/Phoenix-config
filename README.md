# Phoenix config
### Tested with Phoenix 4.0.0

This is a literate (JS) config for [Phoenix](https://github.com/kasper/phoenix/)
a lightweight scriptable OS X window manager.

Primary feature here is grid based window control and layout. Move and size
windows around the grid. Resize grid. Snap window or windows to grid.

## Clone and Install

```bash
cd
git clone git@github.com:jasonm23/Phoenix-config
cd Phoenix-config
make
```

# Code

## Helpers

```js @code
Phoenix.notify("Phoenix config loading")

Phoenix.set({
  daemon: false,
  openAtLogin: true
})
```

Logging

```js @code
let log = function (o, label = "obj: ") {
  Phoenix.log(`${(new Date()).toISOString()}:: ${label} =>`)
  Phoenix.log(JSON.stringify(o))
}
```

Add `_.flatmap` to `lodash`.

```js @code
_.mixin({
  flatmap(list, iteratee, context) {
    return _.flatten(_.map(list, iteratee, context))
  }
})
```

- - -

## Window Grid

Initial grid settings

```js @code
MARGIN_X = 0
MARGIN_Y = 0
GRID_WIDTH = 16
GRID_HEIGHT = 9
```

Shortcuts for `focused` and `visible`

```js @code
focused = () => Window.focused()

function visible() {
  return Window.all().filter( w => {
    if (w != undefined) {
      return w.isVisible()
    } else {
      return false
    }
  })
}

Window.prototype.screenFrame = function(screen) {
  return (screen != null ? screen.flippedVisibleFrame() : void 0) || this.screen().flippedVisibleFrame()
}

Window.prototype.fullGridFrame = function() {
  return this.calculateGrid({y: 0, x: 0, width: 1, height: 1})
}
```

Snap all windows to grid layout

```js @code
function snapAllToGrid() { _.map(visible(), win => win.snapToGrid()) }
```

Change grid width or height

```js @code
changeGridWidth = n => {
  GRID_WIDTH = Math.max(1, GRID_WIDTH + n)
  Phoenix.notify(`grid is ${GRID_WIDTH} tiles wide`)
  snapAllToGrid()
  return GRID_WIDTH
}

changeGridHeight = n => {
  GRID_HEIGHT = Math.max(1, GRID_HEIGHT + n)
  Phoenix.notify(`grid is ${GRID_HEIGHT} tiles high`)
  snapAllToGrid()
  return GRID_HEIGHT
}
```

Get the grid box size

```js @code
Window.prototype.getBoxSize = function() {
  return [this.screenFrame().width / GRID_WIDTH,
          this.screenFrame().height / GRID_HEIGHT]
}
```

Get the current window `grid` as `rect`:

```js
// rectangle
{x: float, y: float, width: float, height: float}
```

```js @code
Window.prototype.getGrid = function() {
  let frame = this.frame()
  let [boxHeight, boxWidth] = this.getBoxSize()
  let grid = {
    y: Math.round((frame.y - this.screenFrame().y) / boxHeight),
    x: Math.round((frame.x - this.screenFrame().x) / boxWidth),
    width: Math.max(1, Math.round(frame.width / boxWidth)),
    height: Math.max(1, Math.round(frame.height / boxHeight))
  }
  log(`Window grid: ${grid}`)
  return grid
}
```

Set the current grid from  `rectangle`

```js @code
Window.prototype.setGrid = function({y, x, width, height}, screen) {
  let gridHeight, gridWidth
  screen = screen || focused().screen()
  gridWidth = this.screenFrame().width / GRID_WIDTH
  gridHeight = this.screenFrame().height / GRID_HEIGHT
  return this.setFrame({
    y: ((y * gridHeight) + this.screenFrame(screen).y) + MARGIN_Y,
    x: ((x * gridWidth) + this.screenFrame(screen).x) + MARGIN_X,
    width: (width * gridWidth) - (MARGIN_X * 2.0),
    height: (height * gridHeight) - (MARGIN_Y * 2.0)
  })
}
```

Snap the current window to the grid

```js @code
Window.prototype.snapToGrid = function() {
  if (this.isNormal()) {
    return this.setGrid(this.getGrid())
  }
}
```

Calculate the grid based on the parameters, `x`, `y`, `width`, `height`, (returning an object `rectangle`)

```js @code
Window.prototype.calculateGrid = function({x, y, width, height}) {
  return {
    y: Math.round(y * this.screenFrame().height) + MARGIN_Y + this.screenFrame().y,
    x: Math.round(x * this.screenFrame().width) + MARGIN_X + this.screenFrame().x,
    width: Math.round(width * this.screenFrame().width) - 2.0 * MARGIN_X,
    height: Math.round(height * this.screenFrame().height) - 2.0 * MARGIN_Y
  }
}
```

Window proportion width

```js @code
Window.prototype.proportionWidth = function() {
  let s_w, w_w
  s_w = this.screenFrame().width
  w_w = this.frame().width
  return Math.round((w_w / s_w) * 10) / 10
}
```

Window to grid

```js @code
Window.prototype.toGrid = function({x, y, width, height}) {
  let rect = this.calculateGrid({x, y, width, height})
  return this.setFrame(rect)
}
```

Window top right point

```js @code
Window.prototype.topRight = function() {
  return {
    x: this.frame().x + this.frame().width,
    y: this.frame().y
  }
}
```

Windows on the left of the current window.

```js @code
Window.prototype.toLeft = function() {
  return _.filter(this.neighbors('west'), function(win) {
    return win.topLeft().x < this.topLeft().x - 10
  })
}
```

Windows on the right of the current window.

```js @code
Window.prototype.toRight = function() {
  return _.filter(this.neighbors('east'), function(win) {
    return win.topRight().x > this.topRight().x + 10
  })
}

```

Window information

```js @code
Window.prototype.info = function() {
  let f = this.frame()
  return `[${this.app().processIdentifier()}] ${this.app().name()} : ${this.title()}\n{x:${f.x}, y:${f.y}, width:${f.width}, height:${f.height}}\n`
}
```

## Window moving and sizing

Temporary storage for frames

```js @code
lastFrames = {}
```

Toggle a window to full screen or revert to it's former frame size.

```js @code
Window.prototype.toFullScreen = function(toggle = true) {
  if (!_.isEqual(this.frame(), this.fullGridFrame())) {
    this.rememberFrame()
    return this.toGrid({y: 0, x: 0, width: 1, height: 1})
  } else if (toggle && lastFrames[this.uid()]) {
    this.setFrame(lastFrames[this.uid()])
    return this.forgetFrame()
  }
}
```

Remember and forget frames

```js @code
Window.prototype.uid = function() {
  return `${this.app().name()}::${this.title()}`
}

Window.prototype.rememberFrame = function() {
  return lastFrames[this.uid()] = this.frame()
}

Window.prototype.forgetFrame = function() {
  return delete lastFrames[this.uid()]
}
```

<a name="toggling-width"/>
Toggle window width 80%, 50%, 30%

```js @code
Window.prototype.togglingWidth = function() {
  switch (this.proportionWidth()) {
    case 0.8:
      return 0.5
    case 0.5:
      return 0.3
    default:
      return 0.8
  }
}
```

<a name="toggling-height"/>
Toggle window height 80%, 50%, 30%

```js @code
Window.prototype.togglingHeight = function() {
  let s_h = this.screenFrame().height;  // Screen height
  let w_h = this.frame().height;        // Window height
  let proportion = w_h / s_h;           // Current height proportion

  Phoenix.log(`Screen height: ${s_h}, Window height: ${w_h}, Proportion: ${proportion}`);

  if (proportion >= 0.65 && proportion < 0.85) {
    Phoenix.log("Toggling height to 33%");
    return 0.33;
  } else if (proportion >= 0.45 && proportion < 0.65) {
    Phoenix.log("Toggling height to 67%");
    return 0.67;
  } else {
    Phoenix.log("Toggling height to 50%");
    return 0.5;  // Default to 50% if not in the other ranges
  }
};
```

#### Screen halves

``` text
┌───────────────────────┐
│                       │
│                       │
│                       │
├───────────────────────┤
│                       │
│                       │
│                       │
└───────────────────────┘
┌───────────┬───────────┐
│           │           │
│           │           │
│           │           │
│           │           │
│           │           │
│           │           │
│           │           │
└───────────┴───────────┘
```


```js @code
Window.prototype.toTopHalf = function() {
  return this.toGrid({x: 0, y: 0, width: 1, height: 0.5})
}

Window.prototype.toBottomHalf = function() {
  return this.toGrid({x: 0, y: 0.5, width: 1, height: 0.5})
}

Window.prototype.toLeftHalf = function() {
  return this.toGrid({x: 0, y: 0, width: 0.5, height: 1})
}

Window.prototype.toRightHalf = function() {
  return this.toGrid({x: 0.5, y: 0, width: 0.5, height: 1})
}

Window.prototype.toCenterThird = function() {
  return this.toGrid({x: 0.33, y: 0, width: 0.33, height: 1})
}

```

#### Left/Right Sides with [toggling width](#toggling-width).

``` text
┌──────┬────────────────┐
│      │                │
│      │                │
│      │                │
│      │                │
│      │                │
│      │                │
│      │                │
└──────┴────────────────┘
┌───────────┬───────────┐
│           │           │
│           │           │
│           │           │
│           │           │
│           │           │
│           │           │
│           │           │
└───────────┴───────────┘
┌────────────────┬──────┐
│                │      │
│                │      │
│                │      │
│                │      │
│                │      │
│                │      │
│                │      │
└────────────────┴──────┘
```

```js @code
Window.prototype.toLeftToggle = function() {
  return this.toGrid({
    x: 0,
    y: 0,
    width: this.togglingWidth(),
    height: 1
  })
}

Window.prototype.toRightToggle = function() {
  return this.toGrid({
    x: 1 - this.togglingWidth(),
    y: 0,
    width: this.togglingWidth(),
    height: 1
  })
}
```

```js @code
Window.prototype.toTopToggle = function() {
  let heightProportion = this.togglingHeight();
  Phoenix.log(`Setting top toggle height to ${heightProportion * 100}% of screen`);

  let result = this.toGrid({
    x: 0,
    y: 0,  // Keep y coordinate at 0 for the top of the screen
    width: 1,
    height: heightProportion  // Adjust height proportionally
  });

  Phoenix.log(`toTopToggle set frame: ${JSON.stringify(result.frame())}`);
  return result;
};
Window.prototype.toBottomToggle = function() {
  let heightProportion = this.togglingHeight();
  Phoenix.log(`Setting bottom toggle height to ${heightProportion * 100}% of screen`);

  let result = this.toGrid({
    x: 0,
    y: 1 - heightProportion,  // Set y coordinate based on the remaining space
    width: 1,
    height: heightProportion
  });

  Phoenix.log(`toBottomToggle set frame: ${JSON.stringify(result.frame())}`);
  return result;
};
```

#### To screen corners

``` text
┌───────────┬───────────┐
│           │           │
│           │           │
│           │           │
├───────────┘           │
│                       │
│                       │
│                       │
└───────────────────────┘
┌───────────┬───────────┐
│           │           │
│           │           │
│           │           │
│           └───────────┤
│                       │
│                       │
│                       │
└───────────────────────┘
┌───────────────────────┐
│                       │
│                       │
│                       │
├───────────┐           │
│           │           │
│           │           │
│           │           │
└───────────┴───────────┘
┌───────────────────────┐
│                       │
│                       │
│                       │
│           ┌───────────┤
│           │           │
│           │           │
│           │           │
└───────────┴───────────┘
```


```js @code
Window.prototype.toTopRight = function() {
  return this.toGrid({x: 0.5, y: 0, width: 0.5, height: 0.5})
}

Window.prototype.toBottomRight = function() {
  return this.toGrid({x: 0.5, y: 0.5, width: 0.5, height: 0.5})
}

Window.prototype.toTopLeft = function() {
  return this.toGrid({x: 0, y: 0, width: 0.5, height: 0.5})
}

Window.prototype.toBottomLeft = function() {
  return this.toGrid({x: 0, y: 0.5, width: 0.5, height: 0.5})
}
```

To the center of the screen with a grid border.

``` text
┌───────────────────────┐
│                       │
│   ┌───────────────┐   │
│   │               │   │
│   │               │   │
│   │               │   │
│   │               │   │
│   └───────────────┘   │
│                       │
└───────────────────────┘
```

```js @code
Window.prototype.toCenterWithBorder = function(border = 1) {
  let [boxWidth, boxHeight] = this.getBoxSize()
  let rect = {
               x: border,
               y: border,
               width: GRID_WIDTH - (border * 2),
               height: GRID_HEIGHT - (border * 2)
             }
  this.setGrid(rect)
}
```

### Move the current window around the grid

```js @code
windowLeftOneColumn = () => {
  let frame = focused().getGrid()
  frame.x = Math.max(frame.x - 1, 0)
  return focused().setGrid(frame)
}

windowDownOneRow = () => {
  let frame = focused().getGrid()
  frame.y = Math.min(Math.floor(frame.y + 1), GRID_HEIGHT - 1)
  return focused().setGrid(frame)
}

windowUpOneRow = () => {
  let frame = focused().getGrid()
  frame.y = Math.max(Math.floor(frame.y - 1), 0)
  return focused().setGrid(frame)
}

windowRightOneColumn = () => {
  let frame = focused().getGrid()
  frame.x = Math.min(frame.x + 1, GRID_WIDTH - frame.width)
  return focused().setGrid(frame)
}
```

Resize the current window on the grid

```js @code
windowGrowOneGridColumn = () => {
  let frame = focused().getGrid()
  frame.width = Math.min(frame.width + 1, GRID_WIDTH - frame.x)
  return focused().setGrid(frame)
}

windowShrinkOneGridColumn = () => {
  let frame = focused().getGrid()
  frame.width = Math.max(frame.width - 1, 1)
  return focused().setGrid(frame)
}

windowGrowOneGridRow = () => {
  let frame = focused().getGrid()
  frame.height = Math.min(frame.height + 1, GRID_HEIGHT)
  return focused().setGrid(frame)
}

windowShrinkOneGridRow = () => {
  let frame = focused().getGrid()
  frame.height = Math.max(frame.height - 1, 1)
  return focused().setGrid(frame)
}
```

Expand the current window's height to vertically fill the screen

```js @code
windowToFullHeight = () => {
  let frame = focused().getGrid()
  frame.y = 0
  frame.height = GRID_HEIGHT
  return focused().setGrid(frame)
}
```

Expand the current window's width to horizontally fill the screen

```js @code
windowToFullWidth = () => {
  let frame = focused().getGrid()
  frame.x = 0
  frame.width = GRID_WIDTH
  return focused().setGrid(frame)
}
```

## Multi-screen  helpers...

Move the current window to the next / previous screen

```js @code
moveWindowToNextScreen = () => focused().setGrid(focused().getGrid(), focused().screen().next())
moveWindowToPreviousScreen = () => focused().setGrid(focused().getGrid(), focused().screen().previous())
```

## Applications

Select the first window for an app

```js @code
App.prototype.firstWindow = function() {
  return this.all({
    visible: true
  })[0]
}
```

Find an app by it's `name` - this is problematic when the App window
has no title bar. Fair warning.

Find all apps with `name`

```js @code
App.allWithName = name => _.filter(App.all(), a => a.name() === name)

App.byName = name => {
  let app = _.first(App.allWithName(name))
  app.show()
  return app
}
```

Focus or start an app with `name`

```js @code
App.focusOrStart = name => {
  let apps = App.allWithName(name)

  if (_.isEmpty(apps)) {
    App.launch(name)
  }

  let windows = _.flatmap(apps, x => x.windows())
  let activeWindows = _.reject(windows, win => win.isMinimized())

  if (_.isEmpty(activeWindows)) {
    App.launch(name)
  }

  return _.each(activeWindows, win => win.focus())
}
```

### App Name Modal

Show App name.  To be honest, I just added this to see the modal feature in Phoenix.

```js @code
let showAppName = () => {
  let name = focused().app().name()
  let frame = focused().screenFrame()
  let modal = Modal.build({
    duration: 2,
    text: `App: ${name}`
  })
  modal.origin = {
    x: (frame.width / 2) - modal.frame().width / 2,
    y: frame.height - 100
  }
  modal.show()
}

// Helper function to combine app focus/start and showing the app name
function focusAppAndShowName(appFunction) {
    return () => {
        appFunction();
        Timer.after(0.1, showAppName); // Adding a slight delay for the app to focus
    };
}

```

(It's  pretty cool, but it's clearly a bezel ;)

### Binding alias

Alias `Phoenix.bind` as `bind_key`, to make the binding table extra
readable.

```js @code
keys = []
```

The `bind_key` method includes the unused `description` parameter,
This is to allow future functionality i.e. help mechanisms, describe bindings etc.

```js @code
const bind_key = (key, description, modifier, fn) => keys.push(Key.on(key, modifier, fn))
```

## Bindings

Mash is <kbd>Cmd</kbd> + <kbd>Alt/Opt</kbd> + <kbd>Ctrl</kbd> pressed together.

```js @code
const mash = 'cmd-alt-ctrl'.split('-')
```

Smash is Mash + <kbd>shift</kbd>

```js @code
const smash = 'cmd-alt-ctrl-shift'.split('-')
```

Move the current window to the top / bottom / left / right half of the screen
and fill it.

```js @code
bind_key('up', 'Top Half', mash, () => focused().toTopHalf())
bind_key('down', 'Bottom Half', mash, () => focused().toBottomHalf())
bind_key('left', 'Left Half', mash, () => focused().toLeftHalf())
bind_key('right', 'Right Half', mash, () => focused().toRightHalf())
```

Toggle through 1/3, 1/2, and 2/3rd of screen with SMASH.

```js @code
bind_key('up', 'Top Half', smash, () => focused().toTopToggle())
bind_key('down', 'Bottom Half', smash, () => focused().toBottomToggle())
bind_key('left', 'Left side toggle', smash, () => focused().toLeftToggle())
bind_key('right', 'Right side toggle', smash, () => focused().toRightToggle())
```

Move to the center third of the screen, full height.(Usually for use w/ left- and right-toggle at 1/3rd.)

```js @code
bind_key('C', 'Center third', smash, () => focused().toCenterThird())
```

<!--
Move to the center of the screen as a square

```js @code
// bind_key('C', 'Center with border', mash, () => focused().toCenterWithBorder(1))
```
-->

Move to the corners of the screen

```js @code
bind_key('9', 'Top Left', smash, () => {
  const focusedApp = focused();
  Phoenix.log('Moving to Top Left');
  focusedApp.toTopLeft();
});

bind_key('r', 'Bottom Left', smash, () => {
  const focusedApp = focused();
  Phoenix.log('Moving to Bottom Left');
  focusedApp.toBottomLeft();
});

bind_key('0', 'Top Right', smash, () => {
  const focusedApp = focused();
  Phoenix.log('Moving to Top Right');
  focusedApp.toTopRight();
});

bind_key('l', 'Bottom Right', smash, () => {
  const focusedApp = focused();
  Phoenix.log('Moving to Bottom Right');
  focusedApp.toBottomRight();
});
```

Toggle maximize for the current window

```js @code
bind_key('m', 'Maximize Window', mash, () => focused().toFullScreen())
// bind_key('return', 'Maximize Window', mash, () => focused().toFullScreen())
```

# Launch Applications

Launch apps

```js @code
CALENDAR = "Google Calendar"
EDITOR = "Code"
CURSOR = "Cursor"
FINDER = "Finder"
FIREFOX = "Firefox"
GITHUB = "GitHub"
ITERM = "iTerm2"
JPB = "JPB"
MESSAGES = "Messages"
ROAM = "Roam"
SLACK = "Slack"
DW = "DiscoW"
WHATSAPP = "WhatsApp"
GMAIL = "Gmail"
```


Switch to or launch apps - fix these up to use whatever Apps you want on speed dial.

```js @code
bind_key('1', 'Show App Name', smash, showAppName)

bind_key('f1', 'Launch ??? ', mash, focusAppAndShowName(() => App.focusOrStart(CURSOR)));
bind_key('f2', 'Launch Messages', mash, focusAppAndShowName(() => App.focusOrStart(MESSAGES)));
bind_key('f3', 'Launch Slack', mash, focusAppAndShowName(() => App.focusOrStart(SLACK)));
bind_key('f4', 'Launch Browser', mash, focusAppAndShowName(() => App.focusOrStart(FIREFOX)));
bind_key('f5', 'Launch gCal', mash, focusAppAndShowName(() => App.focusOrStart(CALENDAR)));
bind_key('f6', 'Launch JPB', mash, focusAppAndShowName(() => App.focusOrStart(JPB)));
bind_key('f7', 'Launch DW', mash, focusAppAndShowName(() => App.focusOrStart(DW)));
bind_key('f8', 'Launch Github', mash, focusAppAndShowName(() => App.focusOrStart(GITHUB)));
bind_key('f9', 'Launch Editor', mash, focusAppAndShowName(() => App.focusOrStart(EDITOR)));
bind_key('f10', 'Launch iTerm2', mash, focusAppAndShowName(() => App.focusOrStart(ITERM)));

```

Move window between screens

```js @code
bind_key('N', 'To Next Screen', mash, moveWindowToNextScreen)
// bind_key('P', 'To Previous Screen', mash, moveWindowToPreviousScreen)
```

Setting the grid size

```js @code
// bind_key('=', 'Increase Grid Columns', mash, () => changeGridWidth(+1))
// bind_key('-', 'Reduce Grid Columns', mash, () => changeGridWidth(-1))
// bind_key(']', 'Increase Grid Rows', mash, () => changeGridHeight(+1))
// bind_key('[', 'Reduce Grid Rows', mash, () => changeGridHeight(-1))
```

Snap current window or all windows to the grid

```js @code
bind_key(';', 'Snap focused to grid', smash, () => focused().snapToGrid())
bind_key("'", 'Snap all to grid', smash, function(){ visible().map(win => win.snapToGrid()) })
```

Move the current window around the grid

```js @code
// bind_key('H', 'Move Grid Left', smash, windowLeftOneColumn)
// bind_key('J', 'Move Grid Down', smash, windowDownOneRow)
// bind_key('K', 'Move Grid Up', smash, windowUpOneRow)
// bind_key('L', 'Move Grid Right', smash, windowRightOneColumn)
// bind_key('6', 'Move Grid Left', smash, windowLeftOneColumn)
// bind_key('7', 'Move Grid Down', smash, windowDownOneRow)
// bind_key('8', 'Move Grid Up', smash, windowUpOneRow)
// bind_key('9', 'Move Grid Right', smash, windowRightOneColumn)
```

Size the current window on the grid

```js @code
// bind_key('U', 'Window Full Height', smash, windowToFullHeight)
// bind_key('Y', 'Window Full Height', smash, windowToFullWidth)
// bind_key('I', 'Shrink by One Column', smash, windowShrinkOneGridColumn)
// bind_key('O', 'Grow by One Column', smash, windowGrowOneGridColumn)
// bind_key(',', 'Shrink by One Row', smash, windowShrinkOneGridRow)
// bind_key('.', 'Grow by One Row', smash, windowGrowOneGridRow)
```

### Markdown editing layout.

Place Firefox and Emacs windows side-by-side.

```js @code
// bind_key('M', 'Markdown Editing', smash, () => {
  // App.focusOrStart(FIREFOX)
  // focused().toRightHalf()
  // App.focusOrStart(EMACS)
  // App.focusOrStart(VS Code)
  // focused().toLeftHalf()
// })

// bind_key('M', 'Exit Markdown Editing', smash, () => {
//   App.focusOrStart(FIREFOX)
//   focused().toFullScreen(false)
//   App.focusOrStart(EMACS)
//   App.focusOrStart(VS Code)
//   focused().toFullScreen(false)
// })
```

# Custom Layouts

```js @code
// Layout Management System
// Define layouts as data objects for easy creation and modification

// Layout registry - stores all defined layouts
const LAYOUTS = {}

// Screen identification helpers
const SCREENS = {
  // Get screens by position
  PRIMARY: () => Screen.main(),
  LAPTOP: () => Screen.main(),
  LEFT: () => _.find(Screen.all(), s => s.frame().x < Screen.main().frame().x),
  RIGHT: () => _.find(Screen.all(), s => s.frame().x > Screen.main().frame().x),
  TOP: () => _.find(Screen.all(), s => s.frame().y < Screen.main().frame().y),
  BOTTOM: () => _.find(Screen.all(), s => s.frame().y > Screen.main().frame().y),

  // Get screen by index (0-based)
  at: (index) => {
    const screens = Screen.all();
    return index >= 0 && index < screens.length ? screens[index] : Screen.main();
  },

  // Log info about all screens for debugging
  logAll: () => {
    const screens = Screen.all();
    screens.forEach((screen, i) => {
      const frame = screen.frame();
      Phoenix.log(`Screen ${i}: x=${frame.x}, y=${frame.y}, width=${frame.width}, height=${frame.height}, isMain=${screen === Screen.main()}`);
    });
  }
}

// Layout positions - preset positions that can be used in layouts
const POSITIONS = {
  FULL: { x: 0, y: 0, width: 1, height: 1 },
  LEFT_HALF: { x: 0, y: 0, width: 0.5, height: 1 },
  RIGHT_HALF: { x: 0.5, y: 0, width: 0.5, height: 1 },
  TOP_HALF: { x: 0, y: 0, width: 1, height: 0.5 },
  BOTTOM_HALF: { x: 0, y: 0.5, width: 1, height: 0.5 },
  TOP_LEFT: { x: 0, y: 0, width: 0.5, height: 0.5 },
  TOP_RIGHT: { x: 0.5, y: 0, width: 0.5, height: 0.5 },
  BOTTOM_LEFT: { x: 0, y: 0.5, width: 0.5, height: 0.5 },
  BOTTOM_RIGHT: { x: 0.5, y: 0.5, width: 0.5, height: 0.5 },

  // Add quarter screen positions with descriptive names
  TOP_LEFT_QUARTER: { x: 0, y: 0, width: 0.5, height: 0.5 },
  TOP_RIGHT_QUARTER: { x: 0.5, y: 0, width: 0.5, height: 0.5 },
  BOTTOM_LEFT_QUARTER: { x: 0, y: 0.5, width: 0.5, height: 0.5 },
  BOTTOM_RIGHT_QUARTER: { x: 0.5, y: 0.5, width: 0.5, height: 0.5 },

  // Full width halves (top/bottom)
  TOP: { x: 0, y: 0, width: 1, height: 0.5 },
  BOTTOM: { x: 0, y: 0.5, width: 1, height: 0.5 },

  CENTER_THIRD: { x: 0.33, y: 0, width: 0.33, height: 1 },
  LEFT_THIRD: { x: 0, y: 0, width: 0.33, height: 1 },
  RIGHT_THIRD: { x: 0.67, y: 0, width: 0.33, height: 1 },
  TOP_THIRD: { x: 0, y: 0, width: 1, height: 0.33 },
  MIDDLE_THIRD: { x: 0, y: 0.33, width: 1, height: 0.33 },
  BOTTOM_THIRD: { x: 0, y: 0.67, width: 1, height: 0.33 },
  // Add a position for chat apps like Pivotal (small floating window)
  CHAT_WINDOW: { x: 0.1, y: 0.1, width: 0.3, height: 0.7 },
  CONSOLE_WINDOW: { x: 0.05, y: 0.1, width: 0.9, height: 0.8 }
}

// Enhanced window positioning helper that ensures proper fullscreen
Window.prototype.fullScreenApp = function(screen) {
  screen = screen || this.screen();
  const screenFrame = screen.flippedVisibleFrame();

  this.setFrame({
    x: screenFrame.x,
    y: screenFrame.y,
    width: screenFrame.width,
    height: screenFrame.height
  });

  Phoenix.log(`Positioned ${this.app().name()} to full screen: ${JSON.stringify(this.frame())}`);
  return this;
}

// Detect the current monitor configuration
function detectScreenConfiguration() {
  const screens = Screen.all();

  if (screens.length === 1) {
    return "SINGLE";
  }

  if (screens.length === 2) {
    // Check if there's a screen above (vertical arrangement)
    if (SCREENS.TOP()) {
      return "VERTICAL";
    }
    // Check if there's a screen to the left or right (monoduo)
    if (SCREENS.LEFT() || SCREENS.RIGHT()) {
      return "MONODUO";
    }
  }

  if (screens.length >= 3) {
    if (SCREENS.LEFT() && SCREENS.RIGHT()) {
      return "TRIPLE";
    }
  }

  // Default fallback
  return "SINGLE";
}

// Log current screen configuration
function logScreenConfig() {
  const config = detectScreenConfiguration();
  Phoenix.notify(`Current screen configuration: ${config}`);
  SCREENS.logAll();
}
bind_key('8', 'Log Screen Config', smash, logScreenConfig);

// Adaptive layout registry
const ADAPTIVE_LAYOUTS = {};

// Register an adaptive layout for multiple screen configurations
function registerAdaptiveLayout(name, configLayouts) {
  ADAPTIVE_LAYOUTS[name] = configLayouts;
  Phoenix.log(`Adaptive layout registered: ${name}`);

  // Create individual layouts for each configuration
  Object.keys(configLayouts).forEach(config => {
    const layoutName = `${name.toLowerCase()}_${config.toLowerCase()}`;
    registerLayout(layoutName, configLayouts[config]);
    Phoenix.log(`  - Variant registered: ${layoutName}`);
  });

  return ADAPTIVE_LAYOUTS[name];
}

// Apply the appropriate layout based on current screen configuration
function applyAdaptiveLayout(layoutName) {
  const configLayouts = ADAPTIVE_LAYOUTS[layoutName];
  if (!configLayouts) {
    Phoenix.notify(`Adaptive layout "${layoutName}" not found`);
    return;
  }

  const currentConfig = detectScreenConfiguration();
  Phoenix.log(`Detected screen configuration: ${currentConfig}`);

  // Find the best layout for current configuration
  let layout = configLayouts[currentConfig];

  // If no exact match, try to fall back to SINGLE
  if (!layout && currentConfig !== "SINGLE" && configLayouts["SINGLE"]) {
    Phoenix.notify(`No layout for ${currentConfig}, falling back to SINGLE`);
    layout = configLayouts["SINGLE"];
  }

  if (!layout) {
    Phoenix.notify(`No suitable layout found for "${layoutName}" in ${currentConfig} configuration`);
    return;
  }

  // Launch all apps first to speed up the process
  layout.forEach(item => App.launch(item.app));

  // Position all windows after a short delay
  Timer.after(0.1, () => {
    layout.forEach(item => {
      const apps = App.allWithName(item.app);
      if (!_.isEmpty(apps)) {
        const windows = _.flatmap(apps, app => app.windows());
        if (!_.isEmpty(windows)) {
          // Get the window to position (first or specific one by title)
          let window = _.first(windows);
          if (item.title) {
            const matchedWindow = _.find(windows, win => win.title().includes(item.title));
            if (matchedWindow) window = matchedWindow;
          }

          // Determine which screen to use
          let targetScreen = Screen.main();
          if (item.screen) {
            if (typeof item.screen === 'function') {
              targetScreen = item.screen() || Screen.main();
            } else if (typeof item.screen === 'number') {
              targetScreen = SCREENS.at(item.screen) || Screen.main();
            }
          }

          // Apply the position on the target screen
          // Use direct full screen method for FULL position
          if (_.isEqual(item.position, POSITIONS.FULL)) {
            window.fullScreenApp(targetScreen);
          } else {
            window.setGrid(item.position, targetScreen);
          }
        }
      }
    });

    Phoenix.notify(`Adaptive layout "${layoutName}" applied for ${currentConfig}`);
  });
}

// Bind an adaptive layout to a key
function bindAdaptiveLayout(key, layoutName, modifiers = smash) {
  bind_key(key, `Apply ${layoutName} Layout`, modifiers, () => applyAdaptiveLayout(layoutName));
  Phoenix.log(`Adaptive layout "${layoutName}" bound to key "${key}"`);
}

// Define adaptive layouts for different contexts

// COMMUNICATION - Chat and messaging apps
registerAdaptiveLayout("COMMUNICATION", {
  // Single monitor setup
  "SINGLE": [
    { app: "Slack", position: POSITIONS.TOP },
    { app: "Messages", position: POSITIONS.BOTTOM_LEFT_QUARTER },
    { app: "WhatsApp", position: POSITIONS.BOTTOM_RIGHT_QUARTER }
  ],

  // Vertical setup (monitor above laptop)
  "VERTICAL": [
    { app: "Slack", position: POSITIONS.TOP_LEFT_QUARTER, screen: SCREENS.TOP },
    { app: "Messages", position: POSITIONS.TOP_RIGHT_QUARTER, screen: SCREENS.TOP },
    { app: EDITOR, position: POSITIONS.FULL, screen: SCREENS.PRIMARY }
  ],

  // Monoduo setup (external monitors on sides)
  "MONODUO": [
    { app: "WhatsApp", position: POSITIONS.RIGHT_HALF, screen: SCREENS.LEFT },
    { app: "Slack", position: POSITIONS.LEFT_HALF, screen: SCREENS.LEFT },
    { app: "Messages", position: POSITIONS.LEFT_HALF, screen: SCREENS.RIGHT },
    { app: "Gmail", position: POSITIONS.RIGHT_HALF, screen: SCREENS.RIGHT }
  ]
});

// DEVELOPMENT - Coding environment
registerAdaptiveLayout("DEVELOPMENT", {
  // Single monitor setup
  "SINGLE": [
    { app: EDITOR, position: POSITIONS.LEFT_HALF },
    { app: FIREFOX, position: POSITIONS.RIGHT_HALF },
    { app: ITERM, position: POSITIONS.BOTTOM_HALF }
  ],

  // Vertical setup (monitor above laptop)
  "VERTICAL": [
    { app: EDITOR, position: POSITIONS.FULL, screen: SCREENS.PRIMARY },
    { app: FIREFOX, position: POSITIONS.FULL, screen: SCREENS.TOP },
    { app: ITERM, position: POSITIONS.BOTTOM_HALF, screen: SCREENS.PRIMARY }
  ],

  // Monoduo setup (external monitors on sides)
  "MONODUO": [
    { app: EDITOR, position: POSITIONS.FULL, screen: SCREENS.PRIMARY },
    { app: FIREFOX, position: POSITIONS.FULL, screen: SCREENS.RIGHT },
    { app: ITERM, position: POSITIONS.FULL, screen: SCREENS.LEFT }
  ],

  // Triple monitor setup
  "TRIPLE": [
    { app: EDITOR, position: POSITIONS.FULL, screen: SCREENS.PRIMARY },
    { app: FIREFOX, position: POSITIONS.FULL, screen: SCREENS.RIGHT },
    { app: ITERM, position: POSITIONS.FULL, screen: SCREENS.LEFT }
  ]
});

// PRESENTATION - For meetings and demos
registerAdaptiveLayout("PRESENTATION", {
  // Single monitor setup
  "SINGLE": [
    { app: FIREFOX, position: POSITIONS.FULL }
  ],

  // Vertical setup (monitor above laptop)
  "VERTICAL": [
    { app: FIREFOX, position: POSITIONS.FULL, screen: SCREENS.TOP },
    { app: SLACK, position: POSITIONS.CHAT_WINDOW, screen: SCREENS.PRIMARY }
  ],

  // Monoduo setup (external monitors on sides)
  "MONODUO": [
    { app: FIREFOX, position: POSITIONS.FULL, screen: SCREENS.RIGHT },
    { app: SLACK, position: POSITIONS.CHAT_WINDOW, screen: SCREENS.PRIMARY }
  ]
});

// Bind adaptive layouts to keys
bindAdaptiveLayout('1', 'COMMUNICATION');
bindAdaptiveLayout('2', 'DEVELOPMENT');
bindAdaptiveLayout('3', 'PRESENTATION');

// Function to register a new layout (original function kept for compatibility)
function registerLayout(name, windows) {
  LAYOUTS[name] = windows
  Phoenix.log(`Layout registered: ${name}`)
  return LAYOUTS[name]
}

// Function to apply a registered layout (original function kept for compatibility)
function applyLayout(layoutName) {
  const layout = LAYOUTS[layoutName]
  if (!layout) {
    Phoenix.notify(`Layout "${layoutName}" not found`)
    return
  }

  // Launch all apps first to speed up the process
  layout.forEach(item => App.launch(item.app))

  // Position all windows after a short delay
  Timer.after(0.1, () => {
    layout.forEach(item => {
      const apps = App.allWithName(item.app)
      if (!_.isEmpty(apps)) {
        const windows = _.flatmap(apps, app => app.windows())
        if (!_.isEmpty(windows)) {
          // Get the window to position (first or specific one by title)
          let window = _.first(windows)
          if (item.title) {
            const matchedWindow = _.find(windows, win => win.title().includes(item.title))
            if (matchedWindow) window = matchedWindow
          }

          // Determine which screen to use
          let targetScreen = Screen.main()
          if (item.screen) {
            if (typeof item.screen === 'function') {
              targetScreen = item.screen() || Screen.main()
            } else if (typeof item.screen === 'number') {
              targetScreen = SCREENS.at(item.screen) || Screen.main()
            }
          }

          // Apply the position on the target screen
          // Use direct full screen method for FULL position
          if (_.isEqual(item.position, POSITIONS.FULL)) {
            window.fullScreenApp(targetScreen);
          } else {
            window.setGrid(item.position, targetScreen);
          }
        }
      }
    })

    Phoenix.notify(`Layout "${layoutName}" applied`)
  })
}

// Function to bind a layout to a key (original function kept for compatibility)
function bindLayout(key, layoutName, modifiers = smash) {
  bind_key(key, `Apply ${layoutName} Layout`, modifiers, () => applyLayout(layoutName))
  Phoenix.log(`Layout "${layoutName}" bound to key "${key}"`)
}

// Helper to log screen information (useful for setup)
function logScreenInfo() {
  SCREENS.logAll()
  Phoenix.notify("Screen info logged to console")
}
bind_key('0', 'Log Screen Info', smash, logScreenInfo)

// Restore quarter-screen key combos
bind_key('9', 'Top Left Quarter', smash, () => {
  const focusedApp = focused();
  Phoenix.log('Moving to Top Left Quarter');
  focusedApp.toTopLeft();
});

bind_key('0', 'Top Right Quarter', smash, () => {
  const focusedApp = focused();
  Phoenix.log('Moving to Top Right Quarter');
  focusedApp.toTopRight();
});

bind_key('r', 'Bottom Left Quarter', smash, () => {
  const focusedApp = focused();
  Phoenix.log('Moving to Bottom Left Quarter');
  focusedApp.toBottomLeft();
});

bind_key('l', 'Bottom Right Quarter', smash, () => {
  const focusedApp = focused();
  Phoenix.log('Moving to Bottom Right Quarter');
  focusedApp.toBottomRight();
});

// Add a test function to verify app names and window management
function testMoveWindow(appName, position) {
  Phoenix.notify(`Testing ${appName} positioning to ${JSON.stringify(position)}...`);

  let apps = App.allWithName(appName);
  Phoenix.log(`Found ${apps.length} instances of ${appName}`);

  if (!_.isEmpty(apps)) {
    let windows = _.flatmap(apps, app => app.windows());
    Phoenix.log(`Found ${windows.length} windows for ${appName}`);

    if (!_.isEmpty(windows)) {
      let window = _.first(windows);
      Phoenix.log(`Positioning ${appName} window: ${window.title()}`);
      window.setGrid(position);
      Phoenix.notify(`Positioned ${appName} to ${JSON.stringify(position)}`);
    } else {
      Phoenix.notify(`No windows found for ${appName}`);
    }
  } else {
    Phoenix.notify(`App ${appName} not found`);
  }
}

// Add a testing key for individual app positioning
bind_key('t', 'Test Slack Positioning', smash, () => testMoveWindow("Slack", POSITIONS.TOP));
bind_key('y', 'Test WhatsApp Positioning', smash, () => testMoveWindow("WhatsApp", POSITIONS.BOTTOM_RIGHT_QUARTER));
bind_key('u', 'Test Messages Positioning', smash, () => testMoveWindow("Messages", POSITIONS.BOTTOM_LEFT_QUARTER));
```

All done...

```js @code
Phoenix.notify("All ok.")
```
