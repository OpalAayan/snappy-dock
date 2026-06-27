#ifndef CONFIG_WATCHER_H
#define CONFIG_WATCHER_H

int config_watcher_init(const char *config_path);
void config_watcher_handle(int fd);
void config_watcher_cleanup(int fd);

#endif
