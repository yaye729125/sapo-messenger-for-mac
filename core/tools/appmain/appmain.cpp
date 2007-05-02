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

#include "appmain.h"

#include <QtCore>
#include "appplatform.h"

class Platform;
static Platform *g_platform = 0;

class Platform
{
public:
	QMutex *m;
	QWaitCondition *w;
	void *instance;
	bool got_ready;
	bool req_quit;
	bool req_stop;
	QMutex stoplock;
	QWaitCondition stopcond;
	bool in_start;

	Platform(QMutex *_m, QWaitCondition *_w)
	{
		m = _m;
		w = _w;
		g_platform = this;
		instance = 0;
	}

	~Platform()
	{
		g_platform = 0;
	}

	static void platform_ready(void *instance)
	{
		Platform *self = g_platform;
		self->got_ready = true;
		self->instance = instance;
		self->w->wakeOne();
		self->m->unlock();
	}

	// 'm' must be locked before calling exec.  'm' will be unlocked
	// when the Platform object is ready to accept requests.  For
	// consistency, 'm' will be in a locked state when exec returns.
	//
	// expected usage of this function is to set a waitcondition on
	// 'm' in one thread, then in another thread lock 'm', wake the
	// waitcondition, then call exec.
	void exec(int argc, char **argv)
	{
		platform_init();
		req_quit = false;
		while(1)
		{
			// thread sleeps until appmain requests something
			w->wait(m);

			if(req_quit)
				break;

			got_ready = false;
			req_stop = false;
			in_start = true;

			platform_start(argc, argv, platform_ready);

			stoplock.lock();

			bool error = !got_ready;
			bool stopped = got_ready && req_stop;

			// need to relock if platform_ready unlocks
			if(got_ready)
				m->lock();
			else
				instance = 0;

			// tell start() or stop() to stop blocking
			if(error)
				w->wakeOne();
			else if(stopped)
				stopcond.wakeOne();

			in_start = false;
			stoplock.unlock();
		}
		platform_deinit();
	}

	// tell exec to return (Platform must be stopped first!)
	// note: this unlocks 'm' !
	void quit()
	{
		req_quit = true;
		w->wakeOne();
		m->unlock();
	}

	// invoke platform_start, block until ready or error
	void start()
	{
		// wake up the thread to invoke the platform
		w->wakeOne();

		// wait until ready or error
		w->wait(m);
		m->unlock();
	}

	// invoke platform_stop, block until done
	void stop()
	{
		stoplock.lock();
		if(!in_start)
		{
			stoplock.unlock();
			m->lock();
			return;
		}

		req_stop = true;

		// stop the platform
		platform_stop();

		// block until the platform is stopped
		stopcond.wait(&stoplock);
		stoplock.unlock();
		m->lock();
	}
};

class AltThread : public QThread
{
	Q_OBJECT
public:
	QMutex *m;
	QWaitCondition *w;
	int argc;
	char **argv;
	Platform *p;
	int ret;
	bool altapp;

	AltThread(Platform *_p, int _argc, char **_argv, QMutex *_m, QWaitCondition *_w)
	{
		// copy args
		int tablesize = sizeof(char *) * _argc;
		int datasize = 0;
		for(int n = 0; n < _argc; ++n)
			datasize += (strlen(_argv[n]) + 1);
		argc = _argc;
		argv = (char **)malloc(tablesize + datasize);
		char *at = ((char *)argv) + tablesize;
		for(int n = 0; n < argc; ++n)
		{
			argv[n] = at;
			int len = strlen(_argv[n]) + 1;
			memcpy(at, _argv[n], len);
			at += len;
		}

		p = _p;
		m = _m;
		w = _w;
	}

	~AltThread()
	{
		stop();
		free(argv);
	}

	void startAppMain()
	{
		altapp = true;
		start();
	}

	void startPlatform()
	{
		altapp = false;
		start();
	}

	void stop()
	{
		if(!isRunning())
			return;
		wait();
	}

	int returnCode() const
	{
		return ret;
	}

protected:
	virtual void run()
	{
		m->lock();
		// at this point the main thread is waiting

		if(altapp)
		{
			ret = appmain(argc, argv);

			// cancel platform exec
			p->quit();
		}
		else
		{
			// wake up main thread and sleep
			w->wakeOne();
			p->exec(argc, argv);
			m->unlock();
		}
	}
};

#include "appmain.moc"

int main(int argc, char **argv)
{
	QMutex m;
	QWaitCondition w;
	Platform p(&m, &w);
	AltThread alt(&p, argc, argv, &m, &w);
	int ret;

	bool force_main = false;
	bool force_alt = false;
	for(int n = 1; n < argc; ++n)
	{
		if(!qstrcmp(argv[n], "--appmain-main"))
			force_main = true;
		else if(!qstrcmp(argv[n], "--appmain-alt"))
		{
			if(!force_main)
				force_alt = true;
		}
	}

	if(force_alt || (platform_needs_main_thread() && !force_main))
	{
		// start alt thread
		m.lock();
		alt.startAppMain();

		// main thread sleeps until appmain invokes the platform
		p.exec(argc, argv);
		m.unlock();

		// wait for alt thread to finish
		alt.stop();
		ret = alt.returnCode();
	}
	else
	{
		// start alt thread
		m.lock();
		alt.startPlatform();

		// main thread sleeps until alt thread is initialized
		w.wait(&m);

		// now alt thread is asleep.  platform not started yet.

		// run appmain.  alt thread sleeps until appmain invokes
		// platform.
		ret = appmain(argc, argv);

		// cancel platform exec
		p.quit();

		// wait for alt thread to finish
		alt.stop();
	}

	return ret;
}

void *loadPlatform()
{
	g_platform->start();
	return g_platform->instance;
}

void unloadPlatform()
{
	g_platform->stop();
}
