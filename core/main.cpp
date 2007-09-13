#include <QtCore>
//#include <QtGui>
//#include <QtCrypto>
//#include <QtDebug>

Q_IMPORT_PLUGIN(qca_openssl)

#include "im.h"
#include "xmpp_tasks.h"

#include "appmain.h"
#include "leapfrog_platform.h"
#include "lfp_call.h"
#include "lfp_api.h"

#include "account.h"

//#include "psi-helpers/avatars.h"
//#include "psi-core/src/capsmanager.h"
//#include "psi-helpers/vcardfactory.h"
//#include "sapo/audibles.h"
//#include "sapo/liveupdate.h"
//#include "sapo/chat_rooms_browser.h"
//#include "sapo/chat_order.h"
//#include "sapo/ping.h"
//#include "sapo/server_items_info.h"
//#include "sapo/server_vars.h"
//#include "sapo/sapo_agents.h"
//#include "sapo/sapo_debug.h"
//#include "sapo/sapo_photo.h"
//#include "sapo/sapo_remote_options.h"
//#include "sapo/sms.h"
//#include "sapo/transport_registration.h"
//#include "filetransfer.h"
//#include "s5b.h"
//#include "bsocket.h"

#include "lfversion.h"


#pragma mark Leapfrog Platform

leapfrog_platform_t		*g_instance = NULL;
LfpApi					*g_api = NULL;


// To send return values to the other side of the bridge
static void do_invokeMethod(const char *method, const LfpArgumentList &args)
{
	QByteArray buf = args.toArray();
	leapfrog_args_t lfp_args;
	lfp_args.data = (unsigned char *)buf.data();
	lfp_args.size = buf.size();
	leapfrog_platform_invokeMethod(g_instance, method, &lfp_args);
}

static QList<LfpCall> *callList = 0;
static QMutex *callLock = 0;


void setcallbacks(struct leapfrog_callbacks *cb);


#pragma mark App


using namespace XMPP;


class App;
static App *s_app = 0;

class App : public QObject
{
	Q_OBJECT

public:
	App() {
		s_app = this;
		//printf("app: created\n");
		
		g_api = new LfpApi;
		connect(g_api, SIGNAL(call_quit()), SLOT(frog_quit()));
		
		callList = new QList<LfpCall>;
		callLock = new QMutex;
	}
	
	~App() {
		if(g_instance)
			unloadPlatform();

		delete g_api;
		delete callList;
		delete callLock;
		//printf("app: destroyed\n");
	}

public slots:
	void start()
	{
		g_instance = (leapfrog_platform_t *)loadPlatform();
		if(!g_instance)
		{
			//printf("error initializing FrogUI\n");
			emit quit();
			return;
		}

		struct leapfrog_callbacks cb;
		setcallbacks(&cb);
		leapfrog_platform_init(g_instance, &cb);

		if(!g_api->checkApi())
		{
			emit quit();
			return;
		}
	}
	
	void frog_quit()
	{
		emit quit();
	}

	void doCalls()
	{
		while(1)
		{
			callLock->lock();
			if(callList->isEmpty())
			{
				callLock->unlock();
				break;
			}

			LfpCall call = callList->takeFirst();
			callLock->unlock();

			doCall(call);
		}
	}

	void doCall(const LfpCall &call)
	{
		QByteArray methodbuf = call.method.toLatin1();
		const char *method = methodbuf.constData();

		QGenericArgument arg[10];
		QGenericReturnArgument ret;
		QVariant arg_value[10];
		for(int n = 0; n < call.arguments.count(); ++n)
		{
			//QVariant v = call.arguments[n].value;
			arg_value[n] = call.arguments[n].value;
			arg[n] = QGenericArgument(arg_value[n].typeName(), arg_value[n].constData());
		}
		QByteArray retType = g_api->getRetType(method);
		bool r_bool;
		int r_int;
		QString r_string;
		QByteArray r_bytearray;
		QVariantList r_vlist;
		QVariantMap r_vmap;
		if(!retType.isEmpty())
		{
			if(retType == "bool")
				ret = Q_RETURN_ARG(bool, r_bool);
			else if(retType == "int")
				ret = Q_RETURN_ARG(int, r_int);
			else if(retType == "QString")
				ret = Q_RETURN_ARG(QString, r_string);
			else if(retType == "QByteArray")
				ret = Q_RETURN_ARG(QByteArray, r_bytearray);
			else if(retType == "QVariantList")
				ret = Q_RETURN_ARG(QVariantList, r_vlist);
			else if(retType == "QVariantMap")
				ret = Q_RETURN_ARG(QVariantMap, r_vmap);
		}
		if(!QMetaObject::invokeMethod(g_api, method, Qt::DirectConnection, ret, arg[0], arg[1], arg[2], arg[3], arg[4], arg[5], arg[6], arg[7], arg[8], arg[9]))
		{
			printf("app: error invoking method: [%s]\n", method);
			return;
		}

		QVariant v;
		if(!retType.isEmpty())
		{
			if(retType == "bool")
				v = r_bool;
			else if(retType == "int")
				v = r_int;
			else if(retType == "QString")
				v = r_string;
			else if(retType == "QByteArray")
				v = r_bytearray;
			else if(retType == "QVariantList")
				v = r_vlist;
			else if(retType == "QVariantMap")
				v = r_vmap;
		}
		
		// handle return value
		if(!retType.isEmpty())
		{
			QByteArray retmethod = methodbuf + "_ret";
			LfpArgumentList retargs;
			if(!v.isNull())
				retargs += LfpArgument("ret", v);
			if(retmethod == "rosterGroupGetProps_ret")
			{
				QVariantMap v = retargs[0].value.toMap();
				//printf("  rosterGroupGetProps_ret: [%s] [%s] [%d]\n",
				//	qPrintable(v["type"].toString()),
				//	qPrintable(v["name"].toString()),
				//	v["pos"].toInt());
			}
			do_invokeMethod(retmethod.data(), retargs);
		}
	}
	
signals:
	void quit();
};


int frog_invokeMethod(leapfrog_platform_t *g_instance, const char *method, const leapfrog_args_t *args);
int frog_checkMethod(leapfrog_platform_t *g_instance, const char *method, const leapfrog_args_t *args);

void setcallbacks(struct leapfrog_callbacks *cb)
{
	cb->invokeMethod = frog_invokeMethod;
	cb->checkMethod = frog_checkMethod;
}

int frog_invokeMethod(leapfrog_platform_t *g_instance, const char *_method, const leapfrog_args_t *lfp_args)
{
	Q_UNUSED(g_instance);
	QByteArray argData = QByteArray::fromRawData((const char *)lfp_args->data, lfp_args->size);
	LfpArgumentList args = LfpArgumentList::fromArray(argData);

	if(!g_api->checkOurMethod(_method, args))
		return 0;

	LfpCall call;
	call.method = QString(_method);
	call.arguments = args;

	if(call.method == "rosterGroupGetProps")
	{
		QVariant v = call.arguments[0].value;
		//printf("  invokeMethod: rosterGroupGetProps: [%s] %d\n", v.typeName(), v.toInt());
	}
	callLock->lock();
	(*callList) += call;
	callLock->unlock();

	QMetaObject::invokeMethod(s_app, "doCalls", Qt::QueuedConnection);
	return 1;
}

int frog_checkMethod(leapfrog_platform_t *g_instance, const char *method, const leapfrog_args_t *lfp_args)
{
	Q_UNUSED(g_instance);
	QByteArray argData = QByteArray::fromRawData((const char *)lfp_args->data, lfp_args->size);
	LfpArgumentList args = LfpArgumentList::fromArray(argData);
	return g_api->checkOurMethod(method, args) ? 1 : 0;
}


#include "main.moc"

int appmain(int argc, char **argv)
{
	QCoreApplication a(argc, argv);
	
	QCA::init();
	
	App app;
	QObject::connect(&app, SIGNAL(quit()), &a, SLOT(quit()));
	QTimer::singleShot(0, &app, SLOT(start()));
	a.exec();
	return 0;
}

