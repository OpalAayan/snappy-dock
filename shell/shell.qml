/*  shell.qml  —  QuickShell entry point for Snappy Dock.
 *
 *  Launch:  quickshell -p /path/to/snappy-dock/shell
 *
 *  Pragmas:
 *    IgnoreSystemSettings — prevents Qt/GTK theme leakage
 */
//@ pragma IgnoreSystemSettings

import Quickshell

ShellRoot {
    Dock {}
}
