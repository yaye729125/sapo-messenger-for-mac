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

#include "appplatform.h"

#include <QtCore>

static QMutex *m = 0;
static bool active = false;
static int loop_quit = 0;

int platform_needs_main_thread()
{
	return 1;
}

void platform_init()
{
	m = new QMutex;
}

void platform_deinit()
{
	delete m;
	m = 0;
}

void platform_start(int argc, char **argv, void (*platform_ready)(void *i))
{
	bool exitearly = false;
	for(int n = 1; n < argc; ++n)
	{
		if(!qstrcmp(argv[n], "--exitearly"))
		{
			exitearly = true;
			break;
		}
	}
	if(exitearly)
		printf("using exitearly mode\n");

	printf("simulating 2-second platform startup time\n");
	sleep(2);
	active = true;
	platform_ready((void *)1);
	while(1)
	{
		printf("platform loop\n");

		m->lock();
		if(loop_quit)
		{
			m->unlock();
			break;
		}
		m->unlock();

		sleep(1);

		if(exitearly)
			break;
	}
	m->lock();
	active = false;
	loop_quit = 0;
	printf("platform stopped\n");
	m->unlock();
}

void platform_stop()
{
	m->lock();
	if(active)
		loop_quit = 1;
	m->unlock();
}
