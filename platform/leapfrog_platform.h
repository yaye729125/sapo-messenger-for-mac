#ifndef LEAPFROG_PLATFORM_H
#define LEAPFROG_PLATFORM_H

#ifndef LFP_EXPORT
# define LFP_EXPORT __attribute__ ((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct leapfrog_platform leapfrog_platform_t;

typedef struct leapfrog_args
{
	int size;
	unsigned char *data;
} leapfrog_args_t;

struct leapfrog_callbacks
{
	int (*invokeMethod)(leapfrog_platform_t *instance, const char *method, const leapfrog_args_t *args);
	int (*checkMethod)(leapfrog_platform_t *instance, const char *method, const leapfrog_args_t *args);
};

LFP_EXPORT void leapfrog_platform_init(leapfrog_platform_t *instance, struct leapfrog_callbacks *callbacks);
LFP_EXPORT int leapfrog_platform_invokeMethod(leapfrog_platform_t *instance, const char *method, const leapfrog_args_t *args);
LFP_EXPORT int leapfrog_platform_checkMethod(leapfrog_platform_t *instance, const char *method, const leapfrog_args_t *args);

#ifdef __cplusplus
}
#endif

#endif
