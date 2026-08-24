# ─────────────────────────────────────────────────────────────────────────────
# snappy-dock Makefile
# ─────────────────────────────────────────────────────────────────────────────

# Compiler and Flags
CC ?= gcc
CFLAGS ?= -O2
CFLAGS += -std=c11 -Wall -Wextra
LDFLAGS ?=

# Dependencies
PKG_CONFIG ?= pkg-config
DEPS = json-c
CFLAGS += $(shell $(PKG_CONFIG) --cflags $(DEPS))
LDFLAGS += $(shell $(PKG_CONFIG) --libs $(DEPS))

# Installation Directories
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
DATADIR ?= $(PREFIX)/share
APP_DATADIR ?= $(DATADIR)/snappy-dock

# Source Files
SRC_DIR = daemon/src
SRCS = $(SRC_DIR)/main.c \
       $(SRC_DIR)/config.c \
       $(SRC_DIR)/config_watcher.c \
       $(SRC_DIR)/hypr_ipc.c \
       $(SRC_DIR)/hypr_events.c \
       $(SRC_DIR)/state.c \
       $(SRC_DIR)/icons.c \
       $(SRC_DIR)/launcher.c \
       $(SRC_DIR)/protocol.c

OBJS = $(SRCS:.c=.o)
DAEMON = snappydock-d
WRAPPER = snappy-dock.sh
WRAPPER_BIN = snappy-dock

# Shell and Config
SHELL_DIR = shell
CONFIG_GUI_DIR = config-gui
CONFIG_EXAMPLE = config/config.ini.example

.PHONY: all clean install uninstall

all: $(DAEMON)

$(DAEMON): $(OBJS)
	@echo "Linking $@"
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

%.o: %.c
	@echo "Compiling $<"
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	@echo "Cleaning build files..."
	rm -f $(OBJS) $(DAEMON)

install: all
	@echo "Installing executable to $(DESTDIR)$(BINDIR)..."
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 $(DAEMON) $(DESTDIR)$(BINDIR)/$(DAEMON)
	install -m 755 $(WRAPPER) $(DESTDIR)$(BINDIR)/$(WRAPPER_BIN)
	
	@echo "Installing shell files and example config to $(DESTDIR)$(APP_DATADIR)..."
	install -d $(DESTDIR)$(APP_DATADIR)
	cp -r $(SHELL_DIR) $(DESTDIR)$(APP_DATADIR)/
	find $(DESTDIR)$(APP_DATADIR)/$(SHELL_DIR) -type d -exec chmod 755 {} +
	find $(DESTDIR)$(APP_DATADIR)/$(SHELL_DIR) -type f -exec chmod 644 {} +
	
	cp -r $(CONFIG_GUI_DIR) $(DESTDIR)$(APP_DATADIR)/
	find $(DESTDIR)$(APP_DATADIR)/$(CONFIG_GUI_DIR) -type d -exec chmod 755 {} +
	find $(DESTDIR)$(APP_DATADIR)/$(CONFIG_GUI_DIR) -type f -exec chmod 644 {} +
	
	install -m 644 $(CONFIG_EXAMPLE) $(DESTDIR)$(APP_DATADIR)/
	@echo ""
	@echo "Installation complete!"
	@echo "You can now run 'snappy-dock' from your terminal."

uninstall:
	@echo "Uninstalling executable from $(DESTDIR)$(BINDIR)..."
	rm -f $(DESTDIR)$(BINDIR)/$(DAEMON)
	rm -f $(DESTDIR)$(BINDIR)/$(WRAPPER_BIN)
	
	@echo "Uninstalling shell files and data from $(DESTDIR)$(APP_DATADIR)..."
	rm -rf $(DESTDIR)$(APP_DATADIR)
	
	@echo ""
	@echo "User configuration in ~/.config/snappy-dock is safe and has not been touched."
	@echo "Uninstall and graceful cleanup complete!"
