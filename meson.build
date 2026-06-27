project(
  'snappy-dock',
  'c',
  version: '0.1.0',
  default_options: [
    'c_std=c11',
    'warning_level=3',
    'werror=false',
    'b_ndebug=if-release',
  ],
)

# ── Dependencies ─────────────────────────────────────────────────────
json_c = dependency('json-c', required: true)

# ── Daemon Sources ───────────────────────────────────────────────────
src = files(
  'daemon/src/main.c',
  'daemon/src/config.c',
  'daemon/src/config_watcher.c',
  'daemon/src/hypr_ipc.c',
  'daemon/src/hypr_events.c',
  'daemon/src/state.c',
  'daemon/src/icons.c',
  'daemon/src/launcher.c',
  'daemon/src/protocol.c',
)

# ── Debug build flag ─────────────────────────────────────────────────
if get_option('buildtype') == 'debug'
  add_project_arguments('-DSNAPPY_DEBUG', language: 'c')
endif

# ── Executable ───────────────────────────────────────────────────────
executable(
  'snappydock-d',
  src,
  dependencies: [json_c],
  install: true,
)

# ── Install Shell Wrapper ────────────────────────────────────────────
install_data(
  'snappy-dock.sh',
  rename: 'snappy-dock',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

# ── Install QML Shell Files ──────────────────────────────────────────
install_subdir(
  'shell',
  install_dir: get_option('datadir') / 'snappy-dock',
)

# ── Install Example Config ───────────────────────────────────────────
install_data(
  'config/config.ini.example',
  install_dir: get_option('datadir') / 'snappy-dock',
)
