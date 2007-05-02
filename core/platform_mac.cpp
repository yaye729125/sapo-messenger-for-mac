#include "appplatform.h"

extern "C" {

int mac_platform_needs_main_thread();
void mac_platform_init();
void mac_platform_deinit();
void mac_platform_start(int argc, char **argv, void (*platform_ready)(void *i));
void mac_platform_stop();

}

int platform_needs_main_thread()
{
	return mac_platform_needs_main_thread();
}

void platform_init()
{
	mac_platform_init();
}

void platform_deinit()
{
	mac_platform_deinit();
}

void platform_start(int argc, char **argv, void (*platform_ready)(void *i))
{
	mac_platform_start(argc, argv, platform_ready);
}

void platform_stop()
{
	mac_platform_stop();
}
