/*
 * Copyright (C) 2005  Justin Karneges
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#ifndef APPPLATFORM_H
#define APPPLATFORM_H

#ifdef __cplusplus
extern "C" {
#endif

// return 1 or 0
int platform_needs_main_thread();

// initialize.  called just once.
void platform_init();

// deinitialize.  called just once.  platform_start is not running when
// it is called
void platform_deinit();

// run the platform.  this function does not return until the platform
// is stopped, or there is an error.  call the platform_ready() callback
// when there is a platform instance pointer ready to use.  returning
// before invoking the callback is considered an error, returning after
// invoking the callback is considered a shutdown.
void platform_start(int argc, char **argv, void (*platform_ready)(void *i));

// stop the platform, causing platform_start() to return.  this
// function is called from an outside thread, so it must be thread
// safe.
void platform_stop();

#ifdef __cplusplus
}
#endif

#endif
