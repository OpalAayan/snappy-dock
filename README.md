# Snappy Dock

> This isnt  all good yet so try at your own risk

Snappy Dock is a small dock for Hyprland.

It has two parts:

- `snappydock-d`: a C daemon that talks to Hyprland, tracks windows, loads config, and launches apps.
- `shell/`: a QuickShell/QML frontend that draws the dock, icons, dots, and menus.

The dock is meant to stay simple: quick to build, easy to configure, and easy to debug.

## Features

- Shows running Hyprland windows as dock icons.
- Supports pinned apps.
- Left-click focuses a running app or launches a pinned app.
- Right-click opens a menu for focus, launch, pin, unpin, close, float, fullscreen, and move to workspace.
- Includes a launcher button. By default it runs `fuzzel`.
- Resolves app icons from desktop files and icon themes.
- Reads an INI config file from `~/.config/snappy-dock/config.ini`.

## Requirements

Runtime:

- Hyprland
- QuickShell 0.3 or newer
- `json-c`

Build tools:

- `meson`
- `ninja`
- A C compiler such as `gcc` or `clang`
- `json-c` development headers

Package names depend on your distro. Common names are:

- Arch: `meson`, `ninja`, `json-c`, `gcc`
- Debian/Ubuntu: `meson`, `ninja-build`, `libjson-c-dev`, `build-essential`
- Fedora: `meson`, `ninja-build`, `json-c-devel`, `gcc`

## Build

From the repo root:

```sh
meson setup build
meson compile -C build
```

If `build/` already exists, only run:

```sh
meson compile -C build
```

## Install

System install, usually to `/usr/local`:

```sh
sudo meson install -C build
```

This installs:

- `snappy-dock` wrapper script
- `snappydock-d` daemon
- QML shell files
- `config.ini.example`

To uninstall a Meson install:

```sh
sudo ninja uninstall -C build
```

## Run

Start the installed dock:

```sh
snappy-dock
```

Restart it after installing changes:

```sh
snappy-dock --restart
```

Useful wrapper commands:

```sh
snappy-dock --status
snappy-dock --kill
snappy-dock --config
snappy-dock --help
```

Run from the source tree without installing:

```sh
quickshell -p shell
```

## Configuration

Create your user config:

```sh
mkdir -p ~/.config/snappy-dock
cp config/config.ini.example ~/.config/snappy-dock/config.ini
```

If you are outside the source tree after installing system-wide, copy the installed example instead:

```sh
mkdir -p ~/.config/snappy-dock
cp /usr/local/share/snappy-dock/config.ini.example ~/.config/snappy-dock/config.ini
```

Edit it:

```sh
$EDITOR ~/.config/snappy-dock/config.ini
```

Restart after changing config:

```sh
snappy-dock --restart
```

You do not need to rebuild or reinstall after changing `~/.config/snappy-dock/config.ini`. A restart is enough.

You only need to reinstall after changing files in this repo, such as QML, C source, or `snappy-dock.sh`:

```sh
meson compile -C build
sudo meson install -C build
snappy-dock --restart
```

The daemon watches the config file and can send updates to the shell while running. A restart is still the clearest way to make sure every setting is applied.

See [config/config.ini.example](config/config.ini.example) for all settings and plain-language notes.

Common config keys:

| Key | What it controls |
| --- | --- |
| `Position` | Dock edge: `bottom`, `top`, `left`, or `right` |
| `Alignment` | Placement along the edge: `center`, `start`, or `end` |
| `[Icons] IconSize` | Icon size in pixels |
| `[Icons] Theme` | Qt icon theme name, for example `Tela-dracula` |
| `[Icons] Fallback` | Icon used when a themed app icon is missing |
| `Layer` | Wayland layer: `background`, `bottom`, `top`, or `overlay` |
| `ExclusiveZone` | Whether the dock reserves screen space |
| `AutoHide` | Whether the dock hides after the pointer leaves |
| `HotspotDelay` | Edge reveal sensitivity for auto-hide |
| `LauncherCmd` | Command run by the launcher button |
| `LauncherPos` | Launcher button position: `start`, `end`, or `none` |
| `WorkspaceCount` | Workspaces shown in the right-click move menu |
| `[Margins]` | Extra edge spacing |

## Pinned Apps

Pinned apps are stored here:

```sh
~/.config/snappy-dock/pinned
```

The file uses one app class name per line. You normally do not need to edit it by hand. Use the right-click menu on a dock icon and choose pin or unpin.

Example:

```txt
firefox
Alacritty
code
```

If an app does not launch from a pinned icon, check that the class name matches the app desktop file or the window class shown by Hyprland.

## Controls

| Input | Action |
| --- | --- |
| Left-click running app | Focus that app |
| Left-click pinned app with no running window | Launch it |
| Right-click icon | Open the app menu |
| Right-click menu: Pin/Unpin | Add or remove the app from pinned apps |
| Right-click menu: Move to workspace | Move a window to another workspace |

## File Layout

```txt
daemon/src/              C daemon source
shell/                   QuickShell/QML frontend
config/config.ini.example Example config file
snappy-dock.sh           Installed wrapper script
meson.build              Build and install rules
```

## Troubleshooting

### `snappy-dock: ERROR: quickshell not found in PATH`

Install QuickShell and make sure `quickshell` is available in your `PATH`.

### `snappy-dock: ERROR: snappydock-d not found in PATH`

Build and install again:

```sh
meson compile -C build
sudo meson install -C build
```

### QuickShell says `Failed to load configuration`

Run the shell directly to see the QML error:

```sh
quickshell -p shell
```

If you installed the dock, reinstall after changing QML files:

```sh
sudo meson install -C build
snappy-dock --restart
```

### Icons are missing

Make sure the app has a `.desktop` file in one of the normal application directories, such as:

```txt
~/.local/share/applications
/usr/share/applications
/usr/local/share/applications
```

Also check that your icon theme contains the icon named by the desktop file. You can set a theme in `~/.config/snappy-dock/config.ini`:

```ini
[Icons]
IconSize=48
Theme=Tela-dracula
Fallback=application-x-executable
```

Restart the dock after changing `Theme`; QuickShell reads the Qt icon theme when it starts.

### The dock does not react to Hyprland

Make sure Snappy Dock is started inside a Hyprland session. The daemon needs Hyprland IPC environment variables such as `HYPRLAND_INSTANCE_SIGNATURE`.

## License

MIT. See [LICENSE](LICENSE).
