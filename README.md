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

# Applications

Launch apps

```js @code
CALENDAR = "Google Calendar"
EDITOR = "Code"
EMACS = "Emacs"
FINDER = "Finder"
FIREFOX = "Firefox"
GITHUB = "GitHub"
ITERM = "iTerm2"
JPB = "JPB"
MESSAGES = "Messages"
ROAM = "Roam"
SLACK = "Slack"
STRANGELOVE = "strangelove"
```


Switch to or launch apps - fix these up to use whatever Apps you want on speed dial.

```js @code
bind_key('1', 'Show App Name', smash, showAppName)

bind_key('f1', 'Launch ??? ', mash, focusAppAndShowName(() => App.focusOrStart(ROAM)));
bind_key('f2', 'Launch Messages', mash, focusAppAndShowName(() => App.focusOrStart(MESSAGES)));
bind_key('f3', 'Launch Slack', mash, focusAppAndShowName(() => App.focusOrStart(SLACK)));
bind_key('f4', 'Launch Browser', mash, focusAppAndShowName(() => App.focusOrStart(FIREFOX)));
bind_key('f5', 'Launch gCal', mash, focusAppAndShowName(() => App.focusOrStart(CALENDAR)));
bind_key('f6', 'Launch JPB', mash, focusAppAndShowName(() => App.focusOrStart(JPB)));
bind_key('f7', 'Launch Strangelove', mash, focusAppAndShowName(() => App.focusOrStart(STRANGELOVE)));
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

All done...

```js @code
Phoenix.notify("All ok.")
```
