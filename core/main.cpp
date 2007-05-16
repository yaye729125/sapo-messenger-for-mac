#include <QtCore>
#include <QtGui>
#include <QtCrypto>
//#include <QtDebug>

Q_IMPORT_PLUGIN(qca_openssl)

#include "im.h"
#include "xmpp_tasks.h"

#include "appmain.h"
#include "leapfrog_platform.h"
#include "lfp_call.h"
#include "lfp_api.h"
#include "psi-helpers/avatars.h"
#include "psi-core/src/capsmanager.h"
#include "psi-helpers/vcardfactory.h"
#include "sapo/audibles.h"
#include "sapo/liveupdate.h"
#include "sapo/server_items_info.h"
#include "sapo/server_vars.h"
#include "sapo/sapo_agents.h"
#include "sapo/sapo_debug.h"
#include "sapo/sapo_photo.h"
#include "sapo/sapo_remote_options.h"
#include "sapo/sms.h"
#include "sapo/transport_registration.h"
#include "filetransfer.h"
#include "s5b.h"
#include "bsocket.h"

#include "lfversion.h"

leapfrog_platform_t *g_instance;
LfpApi *g_api;

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

/*static QString resultToString(int result)
{
	QString s;
	switch(result) {
		case QCA::TLS::NoCert:
			s = QObject::tr("No certificate presented.");
			break;
		case QCA::TLS::Valid:
			break;
		case QCA::TLS::HostMismatch:
			s = QObject::tr("Hostname mismatch.");
			break;
		case QCA::TLS::Rejected:
			s = QObject::tr("Root CA rejects the specified purpose.");
			break;
		case QCA::TLS::Untrusted:
			s = QObject::tr("Not trusted for the specified purpose.");
			break;
		case QCA::TLS::SignatureFailed:
			s = QObject::tr("Invalid signature.");
			break;
		case QCA::TLS::InvalidCA:
			s = QObject::tr("Invalid CA certificate.");
			break;
		case QCA::TLS::InvalidPurpose:
			s = QObject::tr("Invalid certificate purpose.");
			break;
		case QCA::TLS::SelfSigned:
			s = QObject::tr("Certificate is self-signed.");
			break;
		case QCA::TLS::Revoked:
			s = QObject::tr("Certificate has been revoked.");
			break;
		case QCA::TLS::PathLengthExceeded:
			s = QObject::tr("Maximum cert chain length exceeded.");
			break;
		case QCA::TLS::Expired:
			s = QObject::tr("Certificate has expired.");
			break;
		case QCA::TLS::Unknown:
		default:
			s = QObject::tr("General validation error.");
			break;
	}
	return s;
}*/

void setcallbacks(struct leapfrog_callbacks *cb);

enum ShowType
{
	Offline,
	Online,
	Away,
	ExtendedAway,
	DoNotDisturb,
	Invisible
};

void getAccount_ret(const QString &jid, const QString &host, const QString &pass, bool use_ssl);
void statusUpdated(ShowType show, const QString &status, const QString &message);
void updateContact(const QString &jid, const QString &name, const QString &group);
void removeContact(const QString &jid);
void receiveMessage(const QString &jid_from, const QString &body);
void grantRequest(const QString &jid);

void updatePresence(const QString &jid, const QString &resource, ShowType show, const QString &status);
void contactIsTyping(const QString &jid);
void contactIsNotTyping(const QString &jid);
void groupchatJoined(const QString &roomjid);
void groupchatError(const QString &roomjid, const QString &errorMessage);
void groupchatPresence(const QString &roomjid, const QString &nick, ShowType show, const QString &status);
void groupchatReceiveMessage(const QString &roomjid, const QString &nick, const QString &body);
void groupchatSystemMessage(const QString &roomjid, const QString &body);
void accountXmlIO(int id, bool inbound, const QString &xml);

ShowType str2show(const QString &str)
{
	if(str == "Offline")
		return Offline;
	else if(str == "Online")
		return Online;
	else if(str == "Away")
		return Away;
	else if(str == "ExtendedAway")
		return ExtendedAway;
	else if(str == "Invisible")
		return Invisible;
	else //if(str == "DoNotDisturb")
		return DoNotDisturb;
}

QString show2str(ShowType status)
{
	if(status == Offline)
		return "Offline";
	else if(status == Online)
		return "Online";
	else if(status == Away)
		return "Away";
	else if(status == ExtendedAway)
		return "ExtendedAway";
	else if(status == Invisible)
		return "Invisible";
	else //if(str == DoNotDisturb)
		return "DoNotDisturb";
}

using namespace XMPP;

class App;
static App *app = 0;

class App : public QObject
{
	Q_OBJECT

protected:
	bool avail, logged_in;

	Client				*client;
	AdvancedConnector	*conn;
	QCA::TLS			*tls;
	XMPP::QCATLSHandler	*tlsHandler;
	ClientStream		*stream;
	S5BServer			*s5bServer;
	
	Jid			jid;
	QString		host;
	QString		pass;
	QString		resource;
	bool		use_ssl;
	
	ShowType	req_show;
	QString		req_status;
	
	ServerItemsInfo	*_serverItemsInfo;
	SapoAgents		*_sapoAgents;
	QTimer			*_sapoAgentsTimer;
	
	CapsManager		*_capsManager;
	AvatarFactory	*_avatarFactory;
	SapoSMSCreditManager *_smsCreditManager;
	SapoRemoteOptionsMgr *_remoteOptionsMgr;
	
	JT_PushSapoAudible *_sapoAudibleListener;
	
	// Map containing the hostnames of transport agents received from sapo:agents
	QMap<QString, TransportRegistrationManager *>	_transportHostsRegManagers;

public:
	CapsManager		*capsManager()		{ return _capsManager;		}
	AvatarFactory	*avatarFactory()	{ return _avatarFactory;	}
	
public:
	App()
		: _serverItemsInfo(0), _sapoAgents(0), _sapoAgentsTimer(0)
	{
		app = this;
		//printf("app: created\n");

		avail = false;
		logged_in = false;

		jid = "psitest@jabber.org";
		host = "jabber.org";
		pass = "psitest";
		use_ssl = false;
		
		tls = 0;
		tlsHandler = 0;

		client = new Client;
		
		connect(client, SIGNAL(activated()), SLOT(client_activated()));
		connect(client, SIGNAL(rosterRequestFinished(bool, int, const QString &)), SLOT(client_rosterRequestFinished(bool, int, const QString &)));
		connect(client, SIGNAL(rosterItemAdded(const RosterItem &)), SLOT(client_rosterItemAdded(const RosterItem &)));
		connect(client, SIGNAL(rosterItemAdded(const RosterItem &)), SLOT(client_rosterItemUpdated(const RosterItem &)));
		connect(client, SIGNAL(rosterItemUpdated(const RosterItem &)), SLOT(client_rosterItemUpdated(const RosterItem &)));
		connect(client, SIGNAL(rosterItemRemoved(const RosterItem &)), SLOT(client_rosterItemRemoved(const RosterItem &)));
		connect(client, SIGNAL(resourceAvailable(const Jid &, const Resource &)), SLOT(client_resourceAvailable(const Jid &, const Resource &)));
		connect(client, SIGNAL(resourceUnavailable(const Jid &, const Resource &)), SLOT(client_resourceUnavailable(const Jid &, const Resource &)));
		connect(client, SIGNAL(presenceError(const Jid &, int, const QString &)), SLOT(client_presenceError(const Jid &, int, const QString &)));
		connect(client, SIGNAL(messageReceived(const Message &)), SLOT(client_messageReceived(const Message &)));
		connect(client, SIGNAL(subscription(const Jid &, const QString &, const QString &)), SLOT(client_subscription(const Jid &, const QString &, const QString &)));
		connect(client, SIGNAL(xmlIncoming(const QString &)), SLOT(client_xmlIncoming(const QString &)));
		connect(client, SIGNAL(xmlOutgoing(const QString &)), SLOT(client_xmlOutgoing(const QString &)));
		connect(client, SIGNAL(groupChatJoined(const Jid &)), SLOT(client_groupChatJoined(const Jid &)));
		connect(client, SIGNAL(groupChatLeft(const Jid &)), SLOT(client_groupChatLeft(const Jid &)));
		connect(client, SIGNAL(groupChatPresence(const Jid &, const Status &)), SLOT(client_groupChatPresence(const Jid &, const Status &)));
		connect(client, SIGNAL(groupChatError(const Jid &, int, const QString &)), SLOT(client_groupChatError(const Jid &, int, const QString &)));
		
		// Capabilities Manager
		_capsManager = new CapsManager(client);
		_capsManager->setEnabled(true);
		
		// Avatars
		_avatarFactory = new AvatarFactory(client);
		connect(_avatarFactory,	SIGNAL(selfAvatarHashValuesChanged()), SLOT(avatarFactory_selfAvatarHashValuesChanged()));
		
		// vCards
		VCardFactory::instance()->setClient(client);
		
		// Bridge API
		g_api = new LfpApi(client, _capsManager, _avatarFactory);
		connect(g_api, SIGNAL(call_quit()), SLOT(frog_quit()));
		connect(g_api, SIGNAL(call_setAccount(const QString &, const QString &, const QString &, const QString &, bool)), SLOT(frog_setAccount(const QString &, const QString &, const QString &, const QString &, bool)));
		connect(g_api, SIGNAL(call_accountSendXml(int, const QString &)), SLOT(frog_accountSendXml(int, const QString &)));
		connect(g_api, SIGNAL(call_setStatus(const QString &, const QString &, bool)), SLOT(frog_setStatus(const QString &, const QString &, bool)));
		connect(g_api, SIGNAL(call_transportRegister(const QString &, const QString &, const QString &)), SLOT(frog_transportRegister(const QString &, const QString &, const QString &)));
		connect(g_api, SIGNAL(call_transportUnregister(const QString &)), SLOT(frog_transportUnregister(const QString &)));
		
		// Audibles
		g_api->addCapsFeature("sapo:audible");
		_sapoAudibleListener = new JT_PushSapoAudible(client->rootTask());
		connect(_sapoAudibleListener, SIGNAL(audibleReceived(const Jid &, const QString &)), g_api, SLOT(audible_received(const Jid &, const QString &)));
		
		// SMS Credit Manager
		_smsCreditManager = new SapoSMSCreditManager(client);
		connect(_smsCreditManager, SIGNAL(creditUpdated(const QVariantMap &)), g_api, SLOT(smsCreditManager_updated(const QVariantMap &)));
		
		// Sapo Remote Options Manager
		_remoteOptionsMgr = new SapoRemoteOptionsMgr(client);
		connect(_remoteOptionsMgr, SIGNAL(remoteOptionsUpdated()), SLOT(remoteOptionsManager_updated()));
		
		// File Transfers
		client->setFileTransferEnabled(true);
		connect(client->fileTransferManager(), SIGNAL(incomingReady()), g_api, SLOT(fileTransferMgr_incomingFileTransfer()));
		
		// S5B Server
		s5bServer = new S5BServer;
		client->s5bManager()->setServer(s5bServer);
		// Don't start the server. For now, we will always use the _dataTransferProxy for every transfer.
		// s5bServer->start(0 /* server port: let the class decide */ );
		
		
		callList = new QList<LfpCall>;
		callLock = new QMutex;
	}

	~App()
	{
		delete client;
		delete _capsManager;
		delete _avatarFactory;
		delete _smsCreditManager;
		delete s5bServer;

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

signals:
	void quit();

private:
	void setClientStatus(const ShowType show_type, const QString &status, bool saveToServer)
	{
		// cache it
		req_show = show_type;
		req_status = status;
		
		if (logged_in) {
			
			Status s;
			
			if (show_type == Invisible)
				s.setIsInvisible(true);
			else if(show_type == Away)
				s.setShow("away");
			else if(show_type == ExtendedAway)
				s.setShow("xa");
			else if(show_type == DoNotDisturb)
				s.setShow("dnd");
			
			s.setStatus(status);
			
			// Add entity capabilities information
			if (capsManager()->isEnabled()) {
				s.setCapsNode(client->capsNode());
				s.setCapsVersion(client->capsVersion());
				s.setCapsExt(client->capsExt());
			}
			
			// Add sapo:photo info
			if (!avatarFactory()->selfSapoPhotoHash().isEmpty()) {
				s.setSapoPhotoHash(avatarFactory()->selfSapoPhotoHash());
			}
			// Add VCard photo info
			if (!avatarFactory()->selfVCardPhotoHash().isEmpty()) {
				s.setPhotoHash(avatarFactory()->selfVCardPhotoHash());
			}
			
			client->setPresence(s);
			g_api->notify_statusUpdated(show2str(show_type), status);
			
			// Save on the server
			if (saveToServer)
				_remoteOptionsMgr->setStatusAndMessage(s.show(), s.status());
		}
	}
	
public slots:
	void frog_quit()
	{
		emit quit();
	}

	void frog_setAccount(const QString &jid, const QString &host, const QString &pass, const QString &resource, bool use_ssl)
	{
		this->jid = jid;
		this->host = host;
		this->pass = pass;
		this->resource = resource;
		this->use_ssl = use_ssl;
	}

	void frog_getAccount()
	{
		//getAccount_ret(jid.full(), host, pass, use_ssl);
	}

	void frog_setStatus(const QString &_show, const QString &status, bool saveToServer)
	{
		ShowType show = (ShowType)str2show(_show);

		if(avail) {
			if(show == Offline) {
				printf("Logging out...\n");
				
				client->setPresence(Status("", "Logged out", 0, false));
				
				// Safe cleanup/delete
				QTimer::singleShot(0, this, SLOT(cleanup()));
			}
			else {
				setClientStatus(show, status, saveToServer);
			}
		}
		else {
			if(show == Offline)
				return;
			
			printf("Logging in...\n");
			
			req_show = show;
			req_status = status;
			
			conn = new AdvancedConnector;
			
			Jid fullJID = jid.withResource(resource);
			
			// Is there a custom host & port defined?
			if (host.isEmpty()) {
				// Automatic server hostname and TLS probing mode.
				QString domain = fullJID.domain();
				QStringList sapoDomains;
				sapoDomains << "sapo.pt" << "netcabo.pt" << "mail.telepac.pt" << "net.sapo.pt"
					<< "netbi.pt" << "mail.sporting.pt" << "mail.slbenfica.pt"
					<< "mail.fcporto.pt" << "mail.sitepac.pt";
				
				if (sapoDomains.contains(domain, Qt::CaseInsensitive)) {
					// Force the sapo server
					conn->setOptHostPort("clientes.im.sapo.pt", 5222);
					conn->setOptSSL(false);
				}
				else {
					// If it's empty then we don't set the conn->setOptHostPort() stuff. The core will then
					// use DNS SRV to get the hostname of the server.
					conn->setOptProbe(true);
				}
			}
			else {
				// The server hostname was specified by the user. Force stuff, don't probe.
				if(use_ssl) {
					conn->setOptHostPort(host, 5223);
					conn->setOptSSL(true);
				}
				else {
					conn->setOptHostPort(host, 5222);
					conn->setOptSSL(false);
				}
			}
			
			/*
			 * Don't allow TLS connections if we're in "manual mode", i.e., the server name was specified
			 * by the user and use_ssl is false (also specified by the user).
			 */
			if (host.isEmpty() || use_ssl) {
				if(QCA::isSupported("tls")) {
					tls = new QCA::TLS;
					//tls->setTrustedCertificates(CertUtil::allCertificates());
					tlsHandler = new QCATLSHandler(tls);
					//tlsHandler->setXMPPCertCheck(true);
					connect(tlsHandler, SIGNAL(tlsHandshaken()), SLOT(tls_handshaken()));
				}
				else {
					printf("Can't enable the security layer because SAPO Messenger wasn't compiled with TLS support!\n");
				}
			}
			
			stream = new ClientStream(conn, tlsHandler);
			//stream->setRequireMutualAuth(true);
			//stream->setSSFRange(0, 256);
			//d->stream->setCompress(d->acc.opt_compress);
			stream->setAllowPlain(ClientStream::AllowPlain);
			stream->setLang("en");			
			stream->setOldOnly(false);
			stream->setNoopTime(55000);
			connect(stream, SIGNAL(connected()), SLOT(cs_connected()));
			connect(stream, SIGNAL(securityLayerActivated(int)), SLOT(cs_securityLayerActivated(int)));
			connect(stream, SIGNAL(needAuthParams(bool, bool, bool)), SLOT(cs_needAuthParams(bool, bool, bool)));
			connect(stream, SIGNAL(authenticated()), SLOT(cs_authenticated()));
			connect(stream, SIGNAL(connectionClosed()), SLOT(cs_connectionClosed()));
			connect(stream, SIGNAL(delayedCloseFinished()), SLOT(cs_delayedCloseFinished()));
			connect(stream, SIGNAL(warning(int)), SLOT(cs_warning(int)));
			connect(stream, SIGNAL(error(int)), SLOT(cs_error(int)));

			avail = true;

			client->connectToServer(stream, fullJID);
		}
	}

	void frog_sendMessage(const QString &jid_to, const QString &body)
	{
		Message m;
		m.setTo(jid_to);
		m.setType("chat");
		m.setBody(body);
		client->sendMessage(m);
	}

	void frog_rosterAddContact(const QString &jid, const QString &name, const QString &group)
	{
		QStringList groups;
		if(!group.isEmpty())
			groups += group;

		JT_Roster *r = new JT_Roster(client->rootTask());
		r->set(jid, name, groups);
		r->go(true);
		client->sendSubscription(jid, "subscribe");
	}

	void frog_rosterUpdateContact(const QString &jid, const QString &name, const QString &group)
	{
		QStringList groups;
		if(!group.isEmpty())
			groups += group;

		//const LiveRoster &lr = client->roster();
		//LiveRoster::ConstIterator it = lr.find(jid);
		//if(it == lr.end())
		//	return;
		//QStringList groups = (*it).groups();

		JT_Roster *r = new JT_Roster(client->rootTask());
		r->set(jid, name, groups);
		r->go(true);
	}

	void frog_rosterRemoveContact(const QString &jid)
	{
		JT_Roster *r = new JT_Roster(client->rootTask());
		r->remove(jid);
		r->go(true);
	}

	void frog_rosterGrantAuth(const QString &jid)
	{
		client->sendSubscription(jid, "subscribed");
	}
	
	void frog_transportRegister(const QString &host, const QString &username, const QString &password)
	{
		if (_transportHostsRegManagers.contains(host)) {
			_transportHostsRegManagers[host]->registerTransport(username, password);
		}
	}
	
	void frog_transportUnregister(const QString &host)
	{
		if (_transportHostsRegManagers.contains(host)) {
			_transportHostsRegManagers[host]->unregisterTransport();
		}
	}
	
	void frog_userIsTyping(const QString &jid_to)
	{
		// TODO
		Q_UNUSED(jid_to);
	}

	void frog_userIsNotTyping(const QString &jid_to)
	{
		// TODO
		Q_UNUSED(jid_to);
	}

	void frog_groupchatJoin(const QString &roomjid)
	{
		// TODO
		Q_UNUSED(roomjid);
	}

	void frog_groupchatSendMessage(const QString &roomjid, const QString &body)
	{
		// TODO
		Q_UNUSED(roomjid);
		Q_UNUSED(body);
	}

	void frog_accountSendXml(int id, const QString &xml)
	{
		// TODO
		Q_UNUSED(id);

		client->send(xml);
	}

	void cleanup()
	{
		g_api->takeAllContactsOffline();
		
		avail = false;
		logged_in = false;

		client->close();

		delete stream;
		stream = 0;
		
		if (tls) {
			delete tls; // this destroys the TLSHandler also
		}
		tls = 0;
		tlsHandler = 0;
		
		delete conn;
		conn = 0;
		
		if (_sapoAgentsTimer) {
			delete _sapoAgentsTimer;
			_sapoAgentsTimer = 0;
		}
		
		delete _sapoAgents;
		_sapoAgents = 0;
		
		delete _serverItemsInfo;
		_serverItemsInfo = 0;
		
		// Clean up the transport agents registration state
		foreach (QString agentHost, _transportHostsRegManagers.keys()) {
			QMetaObject::invokeMethod(g_api, "notify_transportRegistrationStatusUpdated", Qt::QueuedConnection,
									  Q_ARG(QString, agentHost), Q_ARG(bool, false), Q_ARG(QString, ""));
			QMetaObject::invokeMethod(g_api, "notify_transportLoggedInStatusUpdated", Qt::QueuedConnection,
									  Q_ARG(QString, agentHost), Q_ARG(bool, false));
			
			delete _transportHostsRegManagers[agentHost];
			_transportHostsRegManagers[agentHost] = NULL;
		}
		_transportHostsRegManagers.clear();
		client->clearRosterSubsyncAllowedDomainsSet();
	}

	void tls_handshaken()
	{
		QCA::Certificate cert = tls->peerCertificateChain().primary();
		int vr = tls->peerCertificateValidity();

		printf("SAPO Messenger: Successful TLS handshake.\n");
		if(vr == QCA::TLS::Valid) {
			;//printf("Valid certificate.\n");
		}
		else {
			;//printf("%s\n", qPrintable(QString("Invalid certificate: %1").arg(vr)));
			;//printf("Continuing anyway\n");
		}

		tlsHandler->continueAfterHandshake();
	}

	void cs_connected()
	{
		//printf("App: connected\n");
		
		// get the IP address on our end
		QHostAddress	localAddress;
		ByteStream		*bs = conn->stream();
		
		if(bs->inherits("BSocket") || bs->inherits("XMPP::BSocket")) {
			localAddress = ((BSocket *)bs)->address();
			
			// pass the address to our S5B server
			QStringList slist;
			slist += localAddress.toString();
			
			// set up the server
			s5bServer->setHostList(slist);
			
			
			QMetaObject::invokeMethod(g_api, "notify_accountConnectedToServerHost", Qt::QueuedConnection,
									  Q_ARG(int, 0), Q_ARG(QString, ((BSocket *)bs)->peerAddress().toString()));
		}
	}

	void cs_securityLayerActivated(int type)
	{
		printf("SAPO Messenger: %s\n",
			   qPrintable(QString("Security layer activated (%1)").arg((type == XMPP::ClientStream::LayerTLS) ?
																	   "TLS": "SASL")));
	}

	void cs_needAuthParams(bool need_user, bool need_pass, bool need_realm)
	{
		//printf("App: need auth params\n");
		
		if(need_user)
			stream->setUsername(jid.user());
		
		if(need_pass)
			stream->setPassword(pass);
		
		if (need_realm)
			stream->setRealm(jid.domain());
		
		stream->continueAfterParams();
	}

	void cs_authenticated()
	{
		//printf("App: authenticated\n");
		
		// Update our jid and resource if necessary (they may have been modified by the server)
		if (!stream->jid().isEmpty()) {
			jid = stream->jid().bare();
			resource = stream->jid().resource();
		}
		
		// Initiate the session
		if (!stream->old()) {
			JT_Session *j = new JT_Session(client->rootTask());
			connect(j, SIGNAL(finished()), SLOT(sessionStart_finished()));
			j->go(true);
		}
		else {
			sessionStarted();
		}
	}
	
	void sessionStart_finished()
	{
		JT_Session *j = (JT_Session*)sender();
		if ( j->success() ) {
			sessionStarted();
		}
		else {
			cs_error(-1);
		}
	}
	
	void sessionStarted()
	{
		// Server Items Info
		if (_serverItemsInfo) delete _serverItemsInfo;
		_serverItemsInfo = new ServerItemsInfo(jid.host(), client->rootTask());
		
		connect(_serverItemsInfo, SIGNAL(serverItemsUpdated(const QVariantList &)),
				g_api,            SLOT(notify_serverItemsUpdated(const QVariantList &)));
		connect(_serverItemsInfo, SIGNAL(serverItemFeaturesUpdated(const QString &, const QVariantList &)),
				g_api,            SLOT(notify_serverItemFeaturesUpdated(const QString &, const QVariantList &)));
		connect(_serverItemsInfo, SIGNAL(serverItemFeaturesUpdated(const QString &, const QVariantList &)),
				SLOT(serverItemFeaturesUpdated(const QString &, const QVariantList &)));
		
		// Sapo Agents
		if (_sapoAgents) delete _sapoAgents;
		_sapoAgents = new SapoAgents(_serverItemsInfo, client->rootTask());
		
		connect(_sapoAgents, SIGNAL(sapoAgentsUpdated(const QVariantMap &)),
				g_api,       SLOT(notify_sapoAgentsUpdated(const QVariantMap &)));
		connect(_sapoAgents, SIGNAL(sapoAgentsUpdated(const QVariantMap &)),
				SLOT(sapoAgentsUpdated(const QVariantMap &)));
		
		// Sapo Agents Timer
		if (_sapoAgentsTimer) delete _sapoAgentsTimer;
		_sapoAgentsTimer = new QTimer(this);
		
		connect(_sapoAgentsTimer, SIGNAL(timeout()), SLOT(finishConnectAndGetRoster()));
		_sapoAgentsTimer->setSingleShot(true);
		_sapoAgentsTimer->start(5000);
		
		
		_serverItemsInfo->getServerItemsInfo();
	}
	
	void cs_connectionClosed()
	{
		printf("SAPO Messenger: connection closed\n");
		
		g_api->notify_statusUpdated(show2str((ShowType)Offline), QString());
		g_api->notify_connectionError(QString("ConnectionClosed"), 0, 0);
		
		// Safe cleanup/delete
		QTimer::singleShot(0, this, SLOT(cleanup()));
	}

	void cs_delayedCloseFinished()
	{
	}

	void cs_warning(int x)
	{
		Q_UNUSED(x);
		;//printf("App: ClientStream warning [%d]\n", x);
		stream->continueAfterWarning();
	}
	
	char *stream_error_name_from_error_codes(int error_kind, int *ret_error_nr, ClientStream *cs, AdvancedConnector *conn)
	{
		char *error_textID = NULL;
		
		// Return the specific error code if the caller provided a ret_error_nr pointer
		if (ret_error_nr != NULL) {
			*ret_error_nr = ( (error_kind == ClientStream::ErrConnection) ?
							  conn->errorCode() :
							  cs->errorCondition() );
		}
		
		switch (error_kind) {
			case Stream::ErrParse:
			case Stream::ErrProtocol:
			case Stream::ErrStream:
				//	enum StreamCond {
				//		GenericStreamError,
				//		Conflict,
				//		ConnectionTimeout,
				//		InternalServerError,
				//		InvalidFrom,
				//		InvalidXml,
				//		PolicyViolation,
				//		ResourceConstraint,
				//		SystemShutdown
				//	};
				
				switch (cs->errorCondition()) {
					case Stream::Conflict:
						error_textID = "StreamConflict";
						break;
					case Stream::ConnectionTimeout:
						error_textID = "ConnectionTimeout";
						break;
					case Stream::InternalServerError:
						error_textID = "InternalServerError";
						break;
					case Stream::SystemShutdown:
						error_textID = "SystemShutdown";
						break;
					default:
						error_textID = "GenericStreamError";
				}
				break;
				
			case ClientStream::ErrConnection:
				// Connection error, ask Connector-subclass what's up
				// AdvancedConnector:
				// enum Error { ErrConnectionRefused, ErrHostNotFound, ErrProxyConnect, ErrProxyNeg, ErrProxyAuth, ErrStream };
				
				switch (conn->errorCode()) {
					case AdvancedConnector::ErrConnectionRefused:
						error_textID = "ConnectionRefused";
						break;
					case AdvancedConnector::ErrHostNotFound:
						error_textID = "HostNotFound";
						break;
					case AdvancedConnector::ErrProxyConnect:
					case AdvancedConnector::ErrProxyNeg:
						error_textID = "ProxyConnectionError";
						break;
					case AdvancedConnector::ErrProxyAuth:
						error_textID = "ProxyAuthenticationError";
						break;
					default:
						error_textID = "GenericStreamError";
				}
				break;
				
			case ClientStream::ErrNeg:
				// Negotiation error, see condition
				//	enum NegCond {
				//		HostGone,                   // host no longer hosted
				//		HostUnknown,                // unknown host
				//		RemoteConnectionFailed,     // unable to connect to a required remote resource
				//		SeeOtherHost,               // a 'redirect', see errorText() for other host
				//		UnsupportedVersion          // unsupported XMPP version
				//	};
				
				switch (cs->errorCondition()) {
					case ClientStream::HostGone:
					case ClientStream::HostUnknown:
						error_textID = "UnknownHost";
						break;
					default:
						error_textID = "NegotiationError";
				}
				break;
				
			case ClientStream::ErrTLS:
				// TLS error, see condition
				//	enum TLSCond {
				//		TLSStart,                   // server rejected STARTTLS
				//		TLSFail                     // TLS failed, ask TLSHandler-subclass what's up
				//	};
				
				error_textID = "TLSError";
				break;
				
			case ClientStream::ErrAuth:
				// Auth error, see condition
				//	enum AuthCond {
				//		GenericAuthError,           // all-purpose "can't login" error
				//		NoMech,                     // No appropriate auth mech available
				//		BadProto,                   // Bad SASL auth protocol
				//		BadServ,                    // Server failed mutual auth
				//		EncryptionRequired,         // can't use mech without TLS
				//		InvalidAuthzid,             // bad input JID
				//		InvalidMech,                // bad mechanism
				//		InvalidRealm,               // bad realm
				//		MechTooWeak,                // can't use mech with this authzid
				//		NotAuthorized,              // bad user, bad password, bad creditials
				//		TemporaryAuthFailure        // please try again later!
				//	};
				
				switch (cs->errorCondition()) {
					case ClientStream::TemporaryAuthFailure:
						error_textID = "TemporaryAuthenticationFailure";
						break;
					default:
						error_textID = "AuthenticationError";
				}
				break;
				
			case ClientStream::ErrSecurityLayer:
				// broken SASL security layer
				//	enum SecurityLayer {
				//		LayerTLS,
				//		LayerSASL
				//	};
				
				error_textID = "SecurityLayerError";
				break;
				
			case ClientStream::ErrBind:
				// Resource binding error
				//	enum BindCond {
				//		BindNotAllowed,             // not allowed to bind a resource
				//		BindConflict                // resource in-use
				//	};
				
				error_textID = "ResourceBindingError";
				break;
				
			default:
				error_textID = "GenericStreamError";
		}
		
		return error_textID;
	}
	
	void cs_error(int error_kind)
	{
		ClientStream *stream = (ClientStream *)sender();
		int error_code = 0;
		
		char *error_name = stream_error_name_from_error_codes(error_kind, &error_code, stream, conn);
		
		g_api->notify_statusUpdated(show2str((ShowType)Offline), QString());
		g_api->notify_connectionError(QString(error_name), error_kind, error_code);
		
		// Safe cleanup/delete
		QTimer::singleShot(0, this, SLOT(cleanup()));
	}
	
	void avatarFactory_selfAvatarHashValuesChanged()
	{
		if (client->isActive()) {
			// Send a new presence to announce the change
			setClientStatus(req_show, req_status, false);
		}
	}
	
	void sapoAgentsUpdated(const QVariantMap &agentsMap)
	{
		Q_UNUSED(agentsMap);
		
		// Save the list of transport agents so that we can check up on their presence changes
		foreach (QString agentHost, agentsMap.keys()) {
			if (agentsMap[agentHost].toMap().contains("transport")) {
				_transportHostsRegManagers[agentHost] = new TransportRegistrationManager(client, agentHost);
				
				connect(_transportHostsRegManagers[agentHost], SIGNAL(registrationStatusChanged(bool, QString)), SLOT(transportRegistrationStatusChanged(bool, QString)));
				connect(_transportHostsRegManagers[agentHost], SIGNAL(unregistrationFinished()), SLOT(transportUnRegistrationFinished()));
				
				client->addRosterSubsyncAllowedDomain(agentHost);
				
				
				_transportHostsRegManagers[agentHost]->checkRegistrationState();
			}
		}
		
		if (_sapoAgentsTimer && _sapoAgentsTimer->isActive()) {
			_sapoAgentsTimer->stop();
			finishConnectAndGetRoster();
		}
	}
	
	void serverItemFeaturesUpdated(const QString &item, const QVariantList &features)
	{
		// DATA TRANSFER PROXY
		if (features.contains("http://jabber.org/protocol/bytestreams")) {
			g_api->setAutoDataTransferProxy(item);
		}
		
		// SAPO:SMS
		const Jid &smsCreditDestJid = _smsCreditManager->destinationJid();
		if (features.contains("sapo:sms") && (!smsCreditDestJid.isValid() || !(smsCreditDestJid.compare(Jid(item), false)))) {
			_smsCreditManager->setDestinationJid(Jid(item));
		}
		
		// SAPO:LIVEUPDATE
		if (features.contains("sapo:liveupdate")) {
			QString ourJidStr(jid.bare());
			Jid jidForLiveupdate(ourJidStr.replace("@", "%") + "@" + item);
			
			JT_SapoLiveUpdate *liveupdateTask = new JT_SapoLiveUpdate(client->rootTask(), jidForLiveupdate);
			connect(liveupdateTask, SIGNAL(finished()), SLOT(sapoLiveUpdateFinished()));
			liveupdateTask->go(true);
		}
		
		// SERVER-VARS
		if (features.contains("http://messenger.sapo.pt/protocols/server-vars")) {
			QString ourJidStr(jid.bare());
			Jid jidForServerVars(ourJidStr.replace("@", "%") + "@" + item);
			
			JT_ServerVars *serverVarsTask = new JT_ServerVars(client->rootTask(), jidForServerVars);
			connect(serverVarsTask, SIGNAL(finished()), SLOT(serverVarsFinished()));
			serverVarsTask->go(true);
		}
		
		// SAPO:DEBUG
		if (features.contains("sapo:debug")) {
			QString ourJidStr(jid.bare());
			Jid jidForSapoDebug(ourJidStr.replace("@", "%") + "@" + item);
			
			JT_SapoDebug *sapoDebugTask = new JT_SapoDebug(client->rootTask());
			connect(sapoDebugTask, SIGNAL(finished()), SLOT(sapoDebugFinished()));
			sapoDebugTask->getDebuggerStatus(jidForSapoDebug);
			sapoDebugTask->go(true);
		}
	}
	
	void sapoLiveUpdateFinished(void)
	{
		JT_SapoLiveUpdate *liveupdateTask = (JT_SapoLiveUpdate *)sender();
		
		if (liveupdateTask->success()) {
			QMetaObject::invokeMethod(g_api, "notify_liveUpdateURLReceived", Qt::QueuedConnection, Q_ARG(QString, liveupdateTask->url()));
		}
	}
	
	void serverVarsFinished(void)
	{
		JT_ServerVars *serverVarsTask = (JT_ServerVars *)sender();
		
		if (serverVarsTask->success()) {
			QMetaObject::invokeMethod(g_api, "notify_serverVarsReceived", Qt::QueuedConnection, Q_ARG(QVariantMap, serverVarsTask->variablesValues()));
		}
	}
	
	void sapoDebugFinished(void)
	{
		JT_SapoDebug *sapoDebugTask = (JT_SapoDebug *)sender();
		
		if (sapoDebugTask->success()) {
			QMetaObject::invokeMethod(g_api, "notify_debuggerStatusChanged", Qt::QueuedConnection,
									  Q_ARG(bool, sapoDebugTask->isDebugger()));
		}
	}
	
	void finishConnectAndGetRoster()
	{
		client->start(jid.host(), jid.user(), pass, resource);
		client->rosterRequest();
	}
	
	void transportRegistrationStatusChanged(bool newRegStatus, const QString &registeredUsername)
	{
		TransportRegistrationManager *manager = (TransportRegistrationManager *)sender();
		
		QMetaObject::invokeMethod(g_api, "notify_transportRegistrationStatusUpdated", Qt::QueuedConnection,
								  Q_ARG(QString, manager->transportHost()),
								  Q_ARG(bool, newRegStatus),
								  Q_ARG(QString, registeredUsername));
	}
	
	void transportUnRegistrationFinished(void)
	{
		TransportRegistrationManager *manager = (TransportRegistrationManager *)sender();
		
		g_api->removeAllContactsForTransport(manager->transportHost());
	}
	
	void remoteOptionsManager_updated(void)
	{
		QString statusMsg = _remoteOptionsMgr->statusMessage();
		QString show = _remoteOptionsMgr->status();
		
		ShowType show_type;
		
		/* TODO: Save the invisible status in the server cache. */
		if (req_show == Invisible)
			show_type = Invisible;
		else if(show == "away")
			show_type = Away;
		else if(show == "xa")
			show_type = ExtendedAway;
		else if(show == "dnd")
			show_type = DoNotDisturb;
		else
			show_type = Online;
		
		setClientStatus(show_type, statusMsg, false);
	}
	
	void client_activated()
	{
		// Reset (and, consequently, refetch) our vCard from the server as it is needed for lots of stuff
		// (including the fullname for the account, the avatar stored in the server, etc)
		VCardFactory *vcf = VCardFactory::instance();
		vcf->resetSelfVCard();
	}
	
	void client_rosterRequestFinished(bool b, int, const QString &)
	{
		g_api->deleteEmptyGroups();
		
		if(!b)
		{
			;//printf("App: roster retrieve error\n");
			return;
		}

		;//printf("App: roster retrieve success\n");

		logged_in = true;
		setClientStatus(req_show, req_status, false);
	}

	void client_rosterItemAdded(const RosterItem &i)
	{
		//updateContact(i.jid().full(), i.name(), Offline);
		//updateContact(i.jid().full(), i.name(), QString());
		
		// Is it a transport agent?
		if (_transportHostsRegManagers.contains(i.jid().bare())) {
			if (i.subscription().type() == Subscription::None || i.subscription().type() == Subscription::From) {
				// Auto-subscribe
				client->sendSubscription(i.jid().bare(), "subscribe");
			}
		}
		
		g_api->client_rosterItemAdded(i);
	}

	void client_rosterItemUpdated(const RosterItem &i)
	{
		g_api->client_rosterItemUpdated(i);

		/*const LiveRoster &lr = client->roster();
		LiveRoster::ConstIterator it = lr.find(i.jid());
		ShowType status = Offline;
		if(it == lr.end())
		{
			// stay offline? not sure if this can actually happen
		}
		else
		{
			ResourceList::ConstIterator rit = (*it).priority();
			if(rit != (*it).resourceList().end())
			{
				status = Online;
				QString show = (*rit).status().show();
				if(show == "away")
					status = Away;
				else if(show == "xa")
					status = ExtendedAway;
				else if(show == "dnd")
					status = DoNotDisturb;
			}
		}
		//updateContact(i.jid().full(), i.name(), status);
		QString group;
		if(!i.groups().isEmpty())
			group = i.groups().first();
		updateContact(i.jid().full(), i.name(), group);*/
	}

	void client_rosterItemRemoved(const RosterItem &i)
	{
		g_api->client_rosterItemRemoved(i);
		//removeContact(i.jid().full());
	}

	void client_resourceAvailable(const Jid &j, const Resource &r)
	{
		g_api->client_resourceAvailable(j, r);
		
		// Is it a transport agent?
		if (_transportHostsRegManagers.contains(j.bare())) {
			_transportHostsRegManagers[j.bare()]->checkRegistrationState();
			
			QMetaObject::invokeMethod(g_api, "notify_transportLoggedInStatusUpdated", Qt::QueuedConnection,
									  Q_ARG(QString, j.bare()), Q_ARG(bool, true));
		}
		
		
		/*const LiveRoster &lr = client->roster();
		LiveRoster::ConstIterator it = lr.find(j.withResource(QString()));
		if(it == lr.end())
			return;

		QString show = r.status().show();
		ShowType status = Online;
		if(show == "away")
			status = Away;
		else if(show == "xa")
			status = ExtendedAway;
		else if(show == "dnd")
			status = DoNotDisturb;
		//updateContact(j.withResource(r.name()).full(), (*it).name(), status);
		updatePresence(j.full(), r.name(), status, r.status().status());*/
		
		
		// Update entity capabilities.
		// CAPABILITIES UPDATES ARE PERFORMED IN g_api->client_resourceAvailable(j, r) (see above)
		
		// This has to happen after the userlist item has been created.
		//		if (!r.status().capsNode().isEmpty()) {
		//			
		//			// qDebug() << "AVAILABLE: " << j.full() << " " << r.status().capsNode() << " " << r.status().capsVersion() << " " << r.status().capsExt();
		//			
		//			capsManager()->updateCaps(j.withResource(r.name()),
		//									  r.status().capsNode(),
		//									  r.status().capsVersion(),
		//									  r.status().capsExt());
		
		//			// Update the client version
		//			foreach (UserListItem* u, findRelevant(j)) {
		//				UserResourceList::Iterator rit = u->userResourceList().find(j.resource());
		//				if (rit != u->userResourceList().end()) {
		//					(*rit).setClient(capsManager()->clientName(j), capsManager()->clientVersion(j), "");
		//				}
		//			}
		//		}
	}

	void client_resourceUnavailable(const Jid &j, const Resource &r)
	{
		g_api->client_resourceUnavailable(j, r);
		
		// Is it a transport agent?
		if (_transportHostsRegManagers.contains(j.bare())) {
			const LiveRoster &lr = client->roster();
			LiveRoster::ConstIterator it = lr.find(j.withResource(QString()));
			
			if(it != lr.end()) {
				const ResourceList &resList = it->resourceList();
				
				// Was this the last available resource for this JID?
				if (!it->isAvailable() || (resList.count() == 1 && resList.priority()->name() == r.name())) {
					_transportHostsRegManagers[j.bare()]->checkRegistrationState();
					
					QMetaObject::invokeMethod(g_api, "notify_transportLoggedInStatusUpdated", Qt::QueuedConnection,
											  Q_ARG(QString, j.bare()), Q_ARG(bool, false));
					
				}
			}
		}
		
		// qDebug() << "UNAVAILABLE: " << j.full() << " " << r.status().capsNode() << " " << r.status().capsVersion() << " " << r.status().capsExt();
		// Update entity capabilities.
		// CAPABILITIES UPDATES ARE PERFORMED IN g_api->client_resourceUnavailable(j, r) (see above)
		//		capsManager()->disableCaps(j.withResource(r.name()));
		
		/*const LiveRoster &lr = client->roster();
		LiveRoster::ConstIterator it = lr.find(j.withResource(QString()));
		if(it == lr.end())
			return;

		//updateContact(j.withResource(r.name()).full(), (*it).name(), Offline);
		updatePresence(j.full(), r.name(), Offline, QString());*/
	}

	void client_presenceError(const Jid &, int, const QString &)
	{
	}

	void client_messageReceived(const Message &m)
	{
		g_api->client_messageReceived(m);
	}

	void client_subscription(const Jid &jid, const QString &type, const QString &nick)
	{
		// Is it a transport agent?
		if (_transportHostsRegManagers.contains(jid.bare())) {
			if (type == "subscribe") {
				// Auto-accept
				client->sendSubscription(jid, "subscribed");
			}
		}
		else {
			g_api->client_subscription(jid, type, nick);
		}

		//if(type == "subscribe")
		//	grantRequest(jid.full());
	}

	void client_xmlIncoming(const QString &xml)
	{
		// TODO
		g_api->notify_accountXmlIO(0, true, xml);
	}

	void client_xmlOutgoing(const QString &xml)
	{
		// TODO
		g_api->notify_accountXmlIO(0, false, xml);
	}

	void client_groupChatJoined(const Jid &)
	{
		// TODO
	}

	void client_groupChatLeft(const Jid &)
	{
		// TODO
	}

	void client_groupChatPresence(const Jid &, const Status &)
	{
		// TODO
	}

	void client_groupChatError(const Jid &, int, const QString &)
	{
		// TODO
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
};

void quit()
{
	QMetaObject::invokeMethod(app, "frog_quit", Qt::QueuedConnection);
}

void setAccount(const QString &jid, const QString &host, const QString &pass, const QString &resource, bool use_ssl)
{
	QMetaObject::invokeMethod(app, "frog_setAccount", Qt::QueuedConnection, Q_ARG(QString, jid), Q_ARG(QString, host), Q_ARG(QString, pass), Q_ARG(QString, resource), Q_ARG(bool, use_ssl));
}

void getAccount()
{
	QMetaObject::invokeMethod(app, "frog_getAccount", Qt::QueuedConnection);
}

void setStatus(ShowType show, const QString &status)
{
	int x = (int)show;
	QMetaObject::invokeMethod(app, "frog_setStatus", Qt::QueuedConnection, Q_ARG(int, x), Q_ARG(QString, status));
}

void sendMessage(const QString &jid_to, const QString &body)
{
	QMetaObject::invokeMethod(app, "frog_sendMessage", Qt::QueuedConnection, Q_ARG(QString, jid_to), Q_ARG(QString, body));
}

void rosterAddContact(const QString &jid, const QString &name, const QString &group)
{
	QMetaObject::invokeMethod(app, "frog_rosterAddContact", Qt::QueuedConnection, Q_ARG(QString, jid), Q_ARG(QString, name), Q_ARG(QString, group));
}

void rosterUpdateContact(const QString &jid, const QString &name, const QString &group)
{
	QMetaObject::invokeMethod(app, "frog_rosterUpdateContact", Qt::QueuedConnection, Q_ARG(QString, jid), Q_ARG(QString, name), Q_ARG(QString, group));
}

void rosterRemoveContact(const QString &jid)
{
	QMetaObject::invokeMethod(app, "frog_rosterRemoveContact", Qt::QueuedConnection, Q_ARG(QString, jid));
}

void rosterGrantAuth(const QString &jid)
{
	QMetaObject::invokeMethod(app, "frog_rosterGrantAuth", Qt::QueuedConnection, Q_ARG(QString, jid));
}

void userIsTyping(const QString &jid_to)
{
	QMetaObject::invokeMethod(app, "frog_userIsTyping", Qt::QueuedConnection, Q_ARG(QString, jid_to));
}

void userIsNotTyping(const QString &jid_to)
{
	QMetaObject::invokeMethod(app, "frog_userIsNotTyping", Qt::QueuedConnection, Q_ARG(QString, jid_to));
}

void groupchatJoin(const QString &roomjid)
{
	QMetaObject::invokeMethod(app, "frog_groupchatJoin", Qt::QueuedConnection, Q_ARG(QString, roomjid));
}

void groupchatSendMessage(const QString &roomjid, const QString &body)
{
	QMetaObject::invokeMethod(app, "frog_groupchatSendMessage", Qt::QueuedConnection, Q_ARG(QString, roomjid), Q_ARG(QString, body));
}

void accountSendXml(int id, const QString &xml)
{
	QMetaObject::invokeMethod(app, "frog_accountSendXml", Qt::QueuedConnection, Q_ARG(int, id), Q_ARG(QString, xml));
}

int frog_invokeMethod(leapfrog_platform_t *g_instance, const char *method, const leapfrog_args_t *args);
int frog_checkMethod(leapfrog_platform_t *g_instance, const char *method, const leapfrog_args_t *args);

void setcallbacks(struct leapfrog_callbacks *cb)
{
	cb->invokeMethod = frog_invokeMethod;
	cb->checkMethod = frog_checkMethod;
}

/*QString arg_get_string(const leapfrog_arg_item_t *a)
{
	QByteArray buf((char *)a->data, a->size);
	return QString::fromUtf8(buf);
}

bool arg_get_bool(const leapfrog_arg_item_t *a)
{
	if(((const char *)a->data)[0] == 0)
		return false;
	return true;
}*/

/*leapfrog_args_t *leapfrog_args_new()
{
	leapfrog_args_t *args = (leapfrog_args_t *)malloc(sizeof(leapfrog_args_t));
	args->count = 0;
	args->item = 0;
	return args;
}

void leapfrog_args_add_item(leapfrog_args_t *args, const char *type, const char *data, int size)
{
	if(!args->item)
		args->item = (leapfrog_arg_item_t *)malloc(sizeof(leapfrog_arg_item_t));
	else
		args->item = (leapfrog_arg_item_t *)realloc(args->item, sizeof(leapfrog_arg_item_t) * (args->count + 1));

	leapfrog_arg_item_t *arg = &args->item[args->count];
	arg->type = strdup(type);
	arg->size = size;
	arg->data = malloc(size);
	memcpy(arg->data, data, size);
	++args->count;
}

void leapfrog_args_delete(leapfrog_args_t *args)
{
	if(!args)
		return;
	for(int n = 0; n < args->count; ++n)
	{
		free(args->item[n].type);
		free(args->item[n].data);
	}
	free(args->item);
	free(args);
}

void add_string(leapfrog_args_t *args, const QString &str)
{
	QByteArray buf = str.toUtf8();
	leapfrog_args_add_item(args, "string", buf.data(), buf.size());
}

void add_bool(leapfrog_args_t *args, bool b)
{
	QByteArray buf(1, 0);
	buf[0] = b ? 1 : 0;
	leapfrog_args_add_item(args, "bool", buf.data(), buf.size());
}

void add_int(leapfrog_args_t *args, int i)
{
	QByteArray buf(4, 0);
	memcpy(buf.data(), &i, 4); // FIXME: shouldn't assume 4 bytes
	leapfrog_args_add_item(args, "int", buf.data(), buf.size());
}*/

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

	QMetaObject::invokeMethod(app, "doCalls", Qt::QueuedConnection);
	return 1;

	/*QString method = _method;
	if(method == "systemQuit")
	{
		quit();
	}
	else if(method == "setAccount")
	{
		QString jid = args[0].value.toString();
		QString host = args[1].value.toString();
		QString pass = args[2].value.toString();
		bool use_ssl = args[3].value.toBool();
		setAccount(jid, host, pass, use_ssl);
	}
	else if(method == "getAccount")
	{
		getAccount();
	}
	else if(method == "setStatus")
	{
		QString str = args[0].value.toString();
		QString status = args[1].value.toString();
		setStatus(str2show(str), status);
	}
	else if(method == "sendMessage")
	{
		QString jid_to = args[0].value.toString();
		QString body = args[1].value.toString();
		sendMessage(jid_to, body);
	}
	else if(method == "rosterAddContact")
	{
		QString jid = args[0].value.toString();
		QString name = args[1].value.toString();
		QString group = args[2].value.toString();
		rosterAddContact(jid, name, group);
	}
	else if(method == "rosterUpdateContact")
	{
		QString jid = args[0].value.toString();
		QString name = args[0].value.toString();
		QString group = args[0].value.toString();
		rosterUpdateContact(jid, name, group);
	}
	else if(method == "rosterRemoveContact")
	{
		QString jid = args[0].value.toString();
		rosterRemoveContact(jid);
	}
	else if(method == "rosterGrantAuth")
	{
		QString jid = args[0].value.toString();
		rosterGrantAuth(jid);
	}
	else if(method == "userIsTyping")
	{
		QString jid_to = args[0].value.toString();
		userIsTyping(jid_to);
	}
	else if(method == "userIsNotTyping")
	{
		QString jid_to = args[0].value.toString();
		userIsNotTyping(jid_to);
	}
	else if(method == "groupchatJoin")
	{
		QString roomjid = args[0].value.toString();
		groupchatJoin(roomjid);
	}
	else if(method == "groupchatSendMessage")
	{
		QString roomjid = args[0].value.toString();
		QString body = args[1].value.toString();
		groupchatSendMessage(roomjid, body);
	}
	else if(method == "accountSendXml")
	{
		int id = args[0].value.toInt();
		Q_UNUSED(id);
		QString xml = args[1].value.toString();
		accountSendXml(0, xml);
	}
	else
		return 0;
	return 1;*/
}

int frog_checkMethod(leapfrog_platform_t *g_instance, const char *method, const leapfrog_args_t *lfp_args)
{
	Q_UNUSED(g_instance);
	QByteArray argData = QByteArray::fromRawData((const char *)lfp_args->data, lfp_args->size);
	LfpArgumentList args = LfpArgumentList::fromArray(argData);
	return g_api->checkOurMethod(method, args) ? 1 : 0;
}

/*void getAccount_ret(const QString &jid, const QString &host, const QString &pass, bool use_ssl)
{
	LfpArgumentList args;
	args += LfpArgument("jid", jid);
	args += LfpArgument("host", host);
	args += LfpArgument("pass", pass);
	args += LfpArgument("use_ssl", use_ssl);
	do_invokeMethod("getAccount_ret", args);
}

void statusUpdated(ShowType show, const QString &status, const QString &message)
{
	LfpArgumentList args;
	args += LfpArgument("show", show2str(show));
	args += LfpArgument("status", status);
	args += LfpArgument("message", message);
	do_invokeMethod("statusUpdated", args);
}

void updateContact(const QString &jid, const QString &name, const QString &group)
{
	LfpArgumentList args;
	args += LfpArgument("jid", jid);
	args += LfpArgument("name", name);
	args += LfpArgument("group", group);
	do_invokeMethod("updateContact", args);
}

void removeContact(const QString &jid)
{
	LfpArgumentList args;
	args += LfpArgument("jid", jid);
	do_invokeMethod("removeContact", args);
}

void receiveMessage(const QString &jid_from, const QString &body)
{
	LfpArgumentList args;
	args += LfpArgument("jid_from", jid_from);
	args += LfpArgument("body", body);
	do_invokeMethod("receiveMessage", args);
}

void grantRequest(const QString &jid)
{
	LfpArgumentList args;
	args += LfpArgument("jid", jid);
	do_invokeMethod("grantRequest", args);
}

void updatePresence(const QString &jid, const QString &resource, ShowType show, const QString &status)
{
	LfpArgumentList args;
	args += LfpArgument("jid", jid);
	args += LfpArgument("resource", resource);
	args += LfpArgument("show", show2str(show));
	args += LfpArgument("status", status);
	do_invokeMethod("updatePresence", args);
}

void contactIsTyping(const QString &jid)
{
	LfpArgumentList args;
	args += LfpArgument("jid", jid);
	do_invokeMethod("contactIsTyping", args);
}

void contactIsNotTyping(const QString &jid)
{
	LfpArgumentList args;
	args += LfpArgument("jid", jid);
	do_invokeMethod("contactIsNotTyping", args);
}

void groupchatJoined(const QString &roomjid)
{
	LfpArgumentList args;
	args += LfpArgument("roomjid", roomjid);
	do_invokeMethod("groupchatJoined", args);
}

void groupchatError(const QString &roomjid, const QString &errorMessage)
{
	LfpArgumentList args;
	args += LfpArgument("roomjid", roomjid);
	args += LfpArgument("errorMessage", errorMessage);
	do_invokeMethod("groupchatError", args);
}

void groupchatPresence(const QString &roomjid, const QString &nick, ShowType show, const QString &status)
{
	LfpArgumentList args;
	args += LfpArgument("roomjid", roomjid);
	args += LfpArgument("nick", nick);
	args += LfpArgument("show", show2str(show));
	args += LfpArgument("status", status);
	do_invokeMethod("groupchatPresence", args);
}

void groupchatReceiveMessage(const QString &roomjid, const QString &nick, const QString &body)
{
	LfpArgumentList args;
	args += LfpArgument("roomjid", roomjid);
	args += LfpArgument("nick", nick);
	args += LfpArgument("body", body);
	do_invokeMethod("groupchatReceiveMessage", args);
}

void groupchatSystemMessage(const QString &roomjid, const QString &body)
{
	LfpArgumentList args;
	args += LfpArgument("roomjid", roomjid);
	args += LfpArgument("body", body);
	do_invokeMethod("groupchatSystemMessage", args);
}

void accountXmlIO(int id, bool inbound, const QString &xml)
{
	LfpArgumentList args;
	args += LfpArgument("id", id);
	args += LfpArgument("inbound", inbound);
	args += LfpArgument("xml", xml);
	do_invokeMethod("accountXmlIO", args);
}*/

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

