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

# ── Unit Tests ───────────────────────────────────────────────────────

# Common include path for test headers
daemon_inc = include_directories('daemon/src')

# Stub sources (replace hypr_ipc, icons, launcher with no-ops)
test_stubs = files('daemon/src/test_stubs.c')

# test_config: config.c only (no IPC/icons deps)
test_config_exe = executable(
  'test_config',
  files('daemon/src/test_config.c', 'daemon/src/config.c'),
  include_directories: daemon_inc,
  dependencies: [json_c],
  build_by_default: false,
)
test('config', test_config_exe)

# test_state: state.c + stubs (state calls hypr_ipc/icons internally)
test_state_exe = executable(
  'test_state',
  files('daemon/src/test_state.c', 'daemon/src/state.c') + test_stubs,
  include_directories: daemon_inc,
  dependencies: [json_c],
  build_by_default: false,
)
test('state', test_state_exe)

# test_protocol: protocol.c + config.c + state.c + stubs
test_protocol_exe = executable(
  'test_protocol',
  files(
    'daemon/src/test_protocol.c',
    'daemon/src/protocol.c',
    'daemon/src/config.c',
    'daemon/src/state.c',
  ) + test_stubs,
  include_directories: daemon_inc,
  dependencies: [json_c],
  build_by_default: false,
)
test('protocol', test_protocol_exe)

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

# ── Install Config GUI Files ─────────────────────────────────────────
install_subdir(
  'config-gui',
  install_dir: get_option('datadir') / 'snappy-dock',
)

# ── Install Example Config ───────────────────────────────────────────
install_data(
  'config/config.ini.example',
  install_dir: get_option('datadir') / 'snappy-dock',
)
