/*
 *  account.cpp
 *
 *	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jppavao@criticalsoftware.com>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informações sobre o licenciamento, leia o ficheiro README.
 */

#include "account.h"

#include <QtCore>
//#include <QtGui>
//#include <QtCrypto>
////#include <QtDebug>
//
//Q_IMPORT_PLUGIN(qca_openssl)
//
#include "im.h"
#include "xmpp_tasks.h"
//
//#include "appmain.h"
//#include "leapfrog_platform.h"
//#include "lfp_call.h"
#include "lfp_api.h"
#include "psi-helpers/avatars.h"
#include "psi-core/src/capsmanager.h"
#include "psi-core/src/capsregistry.h"
#include "psi-helpers/vcardfactory.h"
#include "sapo/audibles.h"
#include "sapo/liveupdate.h"
#include "sapo/chat_rooms_browser.h"
#include "sapo/chat_order.h"
#include "sapo/ping.h"
#include "sapo/server_items_info.h"
#include "sapo/server_vars.h"
#include "sapo/sapo_agents.h"
#include "sapo/sapo_debug.h"
#include "sapo/sapo_photo.h"
#include "sapo/sapo_remote_options.h"
#include "sapo/sms.h"
#include "sapo/transport_registration.h"
//#include "filetransfer.h"
#include "s5b.h"
#include "bsocket.h"
//
//#include "lfversion.h"


#warning Check later if we can remove this reference from here
extern LfpApi *g_api;


static ShowType str2show(const QString &str)
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

static QString show2str(ShowType status)
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


#pragma mark -


using namespace XMPP;


#pragma mark Static variables for the static methods

static QList<Account *> s_accounts;

static QString	s_client_name;
static QString	s_client_version;
static QString	s_os_name;
static QString	s_caps_node;
static QString	s_caps_version;

static QString	s_tz_name;
static int		s_tz_offset;

static QString	s_support_data_folder;

static XMPP::Features s_features;


Account::Account(const QString &theUUID)
: _serverItemsInfo(0), _sapoAgents(0), _sapoAgentsTimer(0), _chatRoomsBrowser(0)
{
	_avail = false;
	_logged_in = false;
	
	_uuid = theUUID;
	_jid = "psitest@jabber.org";
	_host = "jabber.org";
	_pass = "psitest";
	_use_ssl = false;
	
	_tls = 0;
	_tlsHandler = 0;
	
	_client = new Client;
	
	
	// Initial setup of the features list (if necessary)
	if (s_features.list().isEmpty()) {
		s_features = _client->features();
		s_features.addFeature("http://jabber.org/protocol/muc");
		s_features.addFeature("sapo:audible");
		s_features.addFeature("urn:xmpp:ping");
	}
	
	s_accounts << this;
	setClientInfo(s_client_name, s_client_version, s_os_name, s_caps_node, s_caps_version);
	setTimeZoneInfo(s_tz_name, s_tz_offset);
	setCapsFeatures(s_features);
	
	
	connect(_client, SIGNAL(activated()), SLOT(client_activated()));
	connect(_client, SIGNAL(rosterRequestFinished(bool, int, const QString &)), SLOT(client_rosterRequestFinished(bool, int, const QString &)));
	connect(_client, SIGNAL(rosterItemAdded(const RosterItem &)), SLOT(client_rosterItemAdded(const RosterItem &)));
	connect(_client, SIGNAL(rosterItemAdded(const RosterItem &)), SLOT(client_rosterItemUpdated(const RosterItem &)));
	connect(_client, SIGNAL(rosterItemUpdated(const RosterItem &)), SLOT(client_rosterItemUpdated(const RosterItem &)));
	connect(_client, SIGNAL(rosterItemRemoved(const RosterItem &)), SLOT(client_rosterItemRemoved(const RosterItem &)));
	connect(_client, SIGNAL(resourceAvailable(const Jid &, const Resource &)), SLOT(client_resourceAvailable(const Jid &, const Resource &)));
	connect(_client, SIGNAL(resourceUnavailable(const Jid &, const Resource &)), SLOT(client_resourceUnavailable(const Jid &, const Resource &)));
	connect(_client, SIGNAL(presenceError(const Jid &, int, const QString &)), SLOT(client_presenceError(const Jid &, int, const QString &)));
	connect(_client, SIGNAL(messageReceived(const Message &)), SLOT(client_messageReceived(const Message &)));
	connect(_client, SIGNAL(subscription(const Jid &, const QString &, const QString &, const QString &)), SLOT(client_subscription(const Jid &, const QString &, const QString &, const QString &)));
	connect(_client, SIGNAL(xmlIncoming(const QString &)), SLOT(client_xmlIncoming(const QString &)));
	connect(_client, SIGNAL(xmlOutgoing(const QString &)), SLOT(client_xmlOutgoing(const QString &)));
	
	// MUC
	connect(_client, SIGNAL(groupChatJoined(const Jid &)), SLOT(client_groupChatJoined(const Jid &)));
	connect(_client, SIGNAL(groupChatLeft(const Jid &)), SLOT(client_groupChatLeft(const Jid &)));
	connect(_client, SIGNAL(groupChatPresence(const Jid &, const Status &)), SLOT(client_groupChatPresence(const Jid &, const Status &)));
	connect(_client, SIGNAL(groupChatError(const Jid &, int, const QString &)), SLOT(client_groupChatError(const Jid &, int, const QString &)));
	
	
	// Capabilities Manager
	_capsManager = new CapsManager(_client);
	_capsManager->setEnabled(true);
	connect(_capsManager, SIGNAL(capsChanged(const Jid&)), SLOT(capsManager_capsChanged(const Jid&)));
	
	// vCards
	_vCardFactory = new VCardFactory(_client);
	connect(_vCardFactory, SIGNAL(selfVCardChanged()), SLOT(vCardFactory_selfVCardChanged()));
	
	// Avatars
	_avatarFactory = new AvatarFactory(_client, _vCardFactory);
	connect(_avatarFactory,	SIGNAL(selfAvatarHashValuesChanged()),			SLOT(avatarFactory_selfAvatarHashValuesChanged()));
	connect(_avatarFactory, SIGNAL(avatarChanged(const Jid&)),				SLOT(avatarFactory_avatarChanged(const Jid&)));
	connect(_avatarFactory, SIGNAL(selfAvatarChanged(const QByteArray&)),	SLOT(avatarFactory_selfAvatarChanged(const QByteArray&)));
	
	
	// Bridge API
//	g_api = new LfpApi(client, _capsManager, _avatarFactory);
//	connect(g_api, SIGNAL(call_quit()), SLOT(frog_quit()));
//	connect(g_api, SIGNAL(call_setAccount(const QString &, const QString &, const QString &, const QString &, const QString &, bool)), SLOT(frog_setAccount(const QString &, const QString &, const QString &, const QString &, const QString &, bool)));
//	connect(g_api, SIGNAL(call_removeAccount(const QString &)), SLOT(frog_removeAccount(const QString &)));
//	connect(g_api, SIGNAL(call_transportRegister(const QString &, const QString &, const QString &)), SLOT(frog_transportRegister(const QString &, const QString &, const QString &)));
//	connect(g_api, SIGNAL(call_transportUnregister(const QString &)), SLOT(frog_transportUnregister(const QString &)));
//	connect(g_api, SIGNAL(call_fetchChatRoomsListOnHost(const QString &)), SLOT(frog_fetchChatRoomsListOnHost(const QString &)));
//	connect(g_api, SIGNAL(call_fetchChatRoomInfo(const QString &)), SLOT(frog_fetchChatRoomInfo(const QString &)));
	
	
	// Audibles
	_sapoAudibleListener = new JT_PushSapoAudible(_client->rootTask());
	connect(_sapoAudibleListener, SIGNAL(audibleReceived(const Jid &, const QString &)), SLOT(audible_received(const Jid &, const QString &)));
	
	// SMS Credit Manager
	_smsCreditManager = new SapoSMSCreditManager(_client);
	connect(_smsCreditManager, SIGNAL(creditUpdated(const QVariantMap &)), SLOT(smsCreditManager_updated(const QVariantMap &)));
	
	// Sapo Remote Options Manager
	_remoteOptionsMgr = new SapoRemoteOptionsMgr(_client);
	connect(_remoteOptionsMgr, SIGNAL(remoteOptionsUpdated()), SLOT(remoteOptionsManager_updated()));
	
	// File Transfers
	_client->setFileTransferEnabled(true);
	connect(_client->fileTransferManager(), SIGNAL(incomingReady()), SLOT(fileTransferMgr_incomingFileTransfer()));
	
	// S5B Server
	_s5bServer = new S5BServer;
	_client->s5bManager()->setServer(_s5bServer);
	// Don't start the server. For now, we will always use the _dataTransferProxy for every transfer.
	// _s5bServer->start(0 /* server port: let the class decide */ );
	
	// XMPP Ping
	_xmppPingListener = new JT_PushXmppPing(_client->rootTask());
	
	
	setSupportDataFolder(s_support_data_folder);
}


Account::~Account()
{
	s_accounts.removeAll(this);
	
	delete _client;
	delete _capsManager;
	delete _avatarFactory;
	delete _smsCreditManager;
	delete _s5bServer;
}


#pragma mark -
#pragma mark Setting Client Info

void Account::setClientInfoForAllAccounts (const QString &client_name, const QString &client_version,
										   const QString &os_name, const QString &caps_node, const QString &caps_version)
{
	s_client_name		= client_name;
	s_client_version	= client_version;
	s_os_name			= os_name;
	s_caps_node			= caps_node;
	s_caps_version		= caps_version;
	
	// Set them in all the existing accounts
	foreach (Account *account, s_accounts) {
		account->setClientInfo(client_name, client_version, os_name, caps_node, caps_version);
	}
}

void Account::setTimeZoneInfoForAllAccounts (const QString &tz_name, int tz_offset)
{
	s_tz_name	= tz_name;
	s_tz_offset	= tz_offset;
	
	// Set them in all the existing accounts
	foreach (Account *account, s_accounts) {
		account->setTimeZoneInfo(tz_name, tz_offset);
	}
}


void Account::setSupportDataFolderForAllAccounts(const QString &pathname)
{
	s_support_data_folder = pathname;
	
	// Set them in all the existing accounts
	foreach (Account *account, s_accounts) {
		account->setSupportDataFolder(pathname);
	}
}


void Account::addCapsFeatureForAllAccounts(const QString &feature)
{
	s_features.addFeature(feature);
	
	// Set them in all the existing accounts
	foreach (Account *account, s_accounts) {
		account->setCapsFeatures(s_features);
	}
}


void Account::setClientInfo (const QString &client_name, const QString &client_version,
							 const QString &os_name, const QString &caps_node, const QString &caps_version)
{
	_client->setClientName(client_name);
	_client->setClientVersion(client_version);
	_client->setOSName(os_name);
	_client->setCapsNode(caps_node);
	_client->setCapsVersion(caps_version);
	
	DiscoItem::Identity identity;
	identity.category = "client";
	identity.type = "pc";
	identity.name = client_name;
	_client->setIdentity(identity);
}


void Account::setTimeZoneInfo (const QString &tz_name, int tz_offset)
{
	_client->setTimeZone(tz_name, tz_offset);
}


void Account::setSupportDataFolder (const QString &pathname)
{
	CapsRegistry::instance()->setFile(pathname + "/CapabilitiesStore.xml");
	_vCardFactory->setVCardsDir(pathname + "/vCards-" + uuid());
	_avatarFactory->setAvatarsDirs(pathname + "/Custom Avatars-" + uuid(), pathname + "/Cached Avatars-" + uuid());
	_avatarFactory->reloadCachedHashes();
}


void Account::setCapsFeatures(const XMPP::Features &features)
{
	_client->setFeatures(features);
}


#pragma mark -


void Account::setClientStatus(const ShowType show_type, const QString &status, bool saveToServer, bool alsoSaveStatusMsg)
{
	// cache it
	_req_show = show_type;
	_req_status = status;
	
	if (_logged_in) {
		
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
			s.setCapsNode(_client->capsNode());
			s.setCapsVersion(_client->capsVersion());
			s.setCapsExt(_client->capsExt());
		}
		
		// Add sapo:photo info
		if (!avatarFactory()->selfSapoPhotoHash().isEmpty()) {
			s.setSapoPhotoHash(avatarFactory()->selfSapoPhotoHash());
		}
		// Add VCard photo info
		if (!avatarFactory()->selfVCardPhotoHash().isEmpty()) {
			s.setPhotoHash(avatarFactory()->selfVCardPhotoHash());
		}
		
		_client->setPresence(s);
#warning notify_...
		QMetaObject::invokeMethod(g_api, "notify_statusUpdated", Qt::QueuedConnection,
								  Q_ARG(QString, uuid()), Q_ARG(QString, show2str(show_type)), Q_ARG(QString, status));
		
		// Save on the server
		if (saveToServer && alsoSaveStatusMsg)
			_remoteOptionsMgr->setStatusAndMessage(s.show(), s.status());
		else if (saveToServer)
			_remoteOptionsMgr->setStatus(s.show());
	}
}


void Account::setStatus(const QString &_show, const QString &status, bool saveToServer, bool alsoSaveStatusMsg)
{
	ShowType show = (ShowType)str2show(_show);
	
	if(_avail) {
		if(show == Offline) {
			printf("Logging out...\n");
			
			_client->setPresence(Status("", "Logged out", 0, false));
#warning notify_...
			QMetaObject::invokeMethod(g_api, "notify_statusUpdated", Qt::QueuedConnection,
									  Q_ARG(QString, uuid()), Q_ARG(QString, show2str((ShowType)Offline)),
									  Q_ARG(QString, QString()));
			
			// Safe cleanup/delete
			QTimer::singleShot(0, this, SLOT(cleanup()));
		}
		else {
			setClientStatus(show, status, saveToServer, alsoSaveStatusMsg);
		}
	}
	else {
		if(show == Offline)
			return;
		
		printf("Logging in...\n");
		
		_req_show = show;
		_req_status = status;
		
		_conn = new AdvancedConnector;
		
		Jid fullJID = _jid.withResource(_resource);
		
		// Is there a custom host & port defined?
		if (_host.isEmpty()) {
			// Automatic server hostname and TLS probing mode.
			QString domain = fullJID.domain();
			QStringList sapoDomains;
			sapoDomains << "sapo.pt" << "netcabo.pt" << "mail.telepac.pt" << "net.sapo.pt"
			<< "netbi.pt" << "mail.sporting.pt" << "mail.slbenfica.pt"
			<< "mail.fcporto.pt" << "mail.sitepac.pt";
			
			if (sapoDomains.contains(domain, Qt::CaseInsensitive)) {
				// Force the sapo server
				_conn->setOptHostPort("clientes.im.sapo.pt", 5222);
				_conn->setOptSSL(false);
			}
			else {
				// If it's empty then we don't set the _conn->setOptHostPort() stuff. The core will then
				// use DNS SRV to get the hostname of the server.
				_conn->setOptProbe(true);
			}
		}
		else {
			// The server hostname was specified by the user. Force stuff, don't probe.
			if(_use_ssl) {
				_conn->setOptHostPort(_host, 5223);
				_conn->setOptSSL(true);
			}
			else {
				_conn->setOptHostPort(_host, 5222);
				_conn->setOptSSL(false);
			}
		}
		
		/*
		 * Don't allow TLS connections if we're in "manual mode", i.e., the server name was specified
		 * by the user and use_ssl is false (also specified by the user).
		 */
		if (_host.isEmpty() || _use_ssl) {
			if(QCA::isSupported("tls")) {
				_tls = new QCA::TLS;
				//_tls->setTrustedCertificates(CertUtil::allCertificates());
				_tlsHandler = new QCATLSHandler(_tls);
				//_tlsHandler->setXMPPCertCheck(true);
				connect(_tlsHandler, SIGNAL(tlsHandshaken()), SLOT(tls_handshaken()));
			}
			else {
				printf("Can't enable the security layer because SAPO Messenger wasn't compiled with TLS support!\n");
			}
		}
		
		_stream = new ClientStream(_conn, _tlsHandler);
		//_stream->setRequireMutualAuth(true);
		//_stream->setSSFRange(0, 256);
		//_stream->setCompress(d->acc.opt_compress);
		_stream->setAllowPlain(ClientStream::AllowPlain);
		_stream->setLang("en");			
		_stream->setOldOnly(false);
		_stream->setNoopTime(55000);
		connect(_stream, SIGNAL(connected()), SLOT(cs_connected()));
		connect(_stream, SIGNAL(securityLayerActivated(int)), SLOT(cs_securityLayerActivated(int)));
		connect(_stream, SIGNAL(needAuthParams(bool, bool, bool)), SLOT(cs_needAuthParams(bool, bool, bool)));
		connect(_stream, SIGNAL(authenticated()), SLOT(cs_authenticated()));
		connect(_stream, SIGNAL(connectionClosed()), SLOT(cs_connectionClosed()));
		connect(_stream, SIGNAL(delayedCloseFinished()), SLOT(cs_delayedCloseFinished()));
		connect(_stream, SIGNAL(warning(int)), SLOT(cs_warning(int)));
		connect(_stream, SIGNAL(error(int)), SLOT(cs_error(int)));
		
		_avail = true;
		
		_client->connectToServer(_stream, fullJID);
	}
}

void Account::sendMessage(const QString &jid_to, const QString &body)
{
	Message m;
	m.setTo(jid_to);
	m.setType("chat");
	m.setBody(body);
	_client->sendMessage(m);
}

void Account::rosterAddContact(const QString &jid, const QString &name, const QString &group)
{
	QStringList groups;
	if(!group.isEmpty())
		groups += group;
	
	JT_Roster *r = new JT_Roster(_client->rootTask());
	r->set(jid, name, groups);
	r->go(true);
	_client->sendSubscription(jid, "subscribe");
}

void Account::rosterUpdateContact(const QString &jid, const QString &name, const QString &group)
{
	QStringList groups;
	if(!group.isEmpty())
		groups += group;
	
	//const LiveRoster &lr = _client->roster();
	//LiveRoster::ConstIterator it = lr.find(jid);
	//if(it == lr.end())
	//	return;
	//QStringList groups = (*it).groups();
	
	JT_Roster *r = new JT_Roster(_client->rootTask());
	r->set(jid, name, groups);
	r->go(true);
}

void Account::rosterRemoveContact(const QString &jid)
{
	JT_Roster *r = new JT_Roster(_client->rootTask());
	r->remove(jid);
	r->go(true);
}

void Account::rosterGrantAuth(const QString &jid)
{
	_client->sendSubscription(jid, "subscribed");
}

void Account::transportRegister(const QString &host, const QString &username, const QString &password)
{
	if (_transportHostsRegManagers.contains(host)) {
		_transportHostsRegManagers[host]->registerTransport(username, password);
	}
}

void Account::transportUnregister(const QString &host)
{
	if (_transportHostsRegManagers.contains(host)) {
		_transportHostsRegManagers[host]->unregisterTransport();
	}
}

void Account::fetchChatRoomsListOnHost(const QString &host)
{
	if (_chatRoomsBrowser)
		_chatRoomsBrowser->getChatRoomsListOnHost(host);
}

void Account::fetchChatRoomInfo(const QString &room_jid)
{
	if (_chatRoomsBrowser)
		_chatRoomsBrowser->getChatRoomInfo(room_jid);
}

void Account::userIsTyping(const QString &jid_to)
{
	// TODO
	Q_UNUSED(jid_to);
}

void Account::userIsNotTyping(const QString &jid_to)
{
	// TODO
	Q_UNUSED(jid_to);
}

void Account::groupchatJoin(const QString &roomjid)
{
	// TODO
	Q_UNUSED(roomjid);
}

void Account::groupchatSendMessage(const QString &roomjid, const QString &body)
{
	// TODO
	Q_UNUSED(roomjid);
	Q_UNUSED(body);
}

void Account::accountSendXML(const QString &xml)
{
	_client->send(xml);
}

void Account::cleanup()
{
#warning g_api->takeAllContactsOffline();
	g_api->takeAllContactsOffline(this);
	
	_avail = false;
	_logged_in = false;
	
	_client->close();
	
	delete _stream;
	_stream = 0;
	
	if (_tls) {
		delete _tls; // this destroys the TLSHandler also
	}
	_tls = 0;
	_tlsHandler = 0;
	
	delete _conn;
	_conn = 0;
	
	if (_sapoAgentsTimer) {
		delete _sapoAgentsTimer;
		_sapoAgentsTimer = 0;
	}
	
	delete _sapoAgents;
	_sapoAgents = 0;
	
	delete _serverItemsInfo;
	_serverItemsInfo = 0;
	
	delete _chatRoomsBrowser;
	_chatRoomsBrowser = 0;
	
	// Clean up the transport agents registration state
	foreach (QString agentHost, _transportHostsRegManagers.keys()) {
#warning notify_...
		QMetaObject::invokeMethod(g_api, "notify_transportRegistrationStatusUpdated", Qt::QueuedConnection,
								  Q_ARG(QString, uuid()),
								  Q_ARG(QString, agentHost), Q_ARG(bool, false), Q_ARG(QString, ""));
		QMetaObject::invokeMethod(g_api, "notify_transportLoggedInStatusUpdated", Qt::QueuedConnection,
								  Q_ARG(QString, uuid()),
								  Q_ARG(QString, agentHost), Q_ARG(bool, false));
		
		delete _transportHostsRegManagers[agentHost];
		_transportHostsRegManagers[agentHost] = NULL;
	}
	_transportHostsRegManagers.clear();
	_client->clearRosterSubsyncAllowedDomainsSet();
}

void Account::tls_handshaken()
{
	QCA::Certificate cert = _tls->peerCertificateChain().primary();
	int vr = _tls->peerCertificateValidity();
	
	printf("SAPO Messenger: Successful TLS handshake.\n");
	if(vr == QCA::TLS::Valid) {
		;//printf("Valid certificate.\n");
	}
	else {
		;//printf("%s\n", qPrintable(QString("Invalid certificate: %1").arg(vr)));
		;//printf("Continuing anyway\n");
	}
	
	_tlsHandler->continueAfterHandshake();
}

void Account::cs_connected()
{
	//printf("App: connected\n");
	
	ByteStream *bs = _conn->stream();
	
	if(bs->inherits("BSocket") || bs->inherits("XMPP::BSocket")) {
		// get the IP address on our end
		QString	localAddress = ((BSocket *)bs)->address().toString();
		QString	remoteAddress = ((BSocket *)bs)->peerAddress().toString();
		
		// pass the address to our S5B server
		QStringList slist;
		slist += localAddress;
		
		// set up the server
		_s5bServer->setHostList(slist);
		
#warning notify_...
		QMetaObject::invokeMethod(g_api, "notify_accountConnectedToServer", Qt::QueuedConnection,
								  Q_ARG(QString, uuid()),
								  Q_ARG(QString, localAddress),
								  Q_ARG(QString, remoteAddress));
	}
}

void Account::cs_securityLayerActivated(int type)
{
	printf("SAPO Messenger: %s\n",
		   qPrintable(QString("Security layer activated (%1)").arg((type == XMPP::ClientStream::LayerTLS) ?
																   "TLS": "SASL")));
}

void Account::cs_needAuthParams(bool need_user, bool need_pass, bool need_realm)
{
	//printf("App: need auth params\n");
	
	if(need_user)
		_stream->setUsername(_jid.user());
	
	if(need_pass)
		_stream->setPassword(_pass);
	
	if (need_realm)
		_stream->setRealm(_jid.domain());
	
	_stream->continueAfterParams();
}

void Account::cs_authenticated()
{
	//printf("App: authenticated\n");
	
	// Update our jid and resource if necessary (they may have been modified by the server)
	if (!_stream->jid().isEmpty()) {
		_jid = _stream->jid().bare();
		_resource = _stream->jid().resource();
	}
	
	// Initiate the session
	if (!_stream->old()) {
		JT_Session *j = new JT_Session(_client->rootTask());
		connect(j, SIGNAL(finished()), SLOT(sessionStart_finished()));
		j->go(true);
	}
	else {
		sessionStarted();
	}
}

void Account::sessionStart_finished()
{
	JT_Session *j = (JT_Session*)sender();
	if ( j->success() ) {
		sessionStarted();
	}
	else {
		cs_error(-1);
	}
}

void Account::sessionStarted()
{
	// Server Items Info
	if (_serverItemsInfo) delete _serverItemsInfo;
	_serverItemsInfo = new ServerItemsInfo(_jid.host(), _client->rootTask());
	
	connect(_serverItemsInfo, SIGNAL(serverItemsUpdated(const QVariantList &)),
			SLOT(serverItemsInfo_serverItemsUpdated(const QVariantList &)));
	connect(_serverItemsInfo, SIGNAL(serverItemInfoUpdated(const QString &, const QString &, const QVariantList &, const QVariantList &)),
			SLOT(serverItemsInfo_serverItemInfoUpdated(const QString &, const QString &, const QVariantList &, const QVariantList &)));
	
	// Sapo Agents
	if (_sapoAgents) delete _sapoAgents;
	_sapoAgents = new SapoAgents(_serverItemsInfo, _client->rootTask());
	
	connect(_sapoAgents, SIGNAL(sapoAgentsUpdated(const QVariantMap &)),
			SLOT(sapoAgents_sapoAgentsUpdated(const QVariantMap &)));
	
	// Sapo Agents Timer
	if (_sapoAgentsTimer) delete _sapoAgentsTimer;
	_sapoAgentsTimer = new QTimer(this);
	
	connect(_sapoAgentsTimer, SIGNAL(timeout()), SLOT(finishConnectAndGetRoster()));
	_sapoAgentsTimer->setSingleShot(true);
	_sapoAgentsTimer->start(5000);
	
	
	_serverItemsInfo->getServerItemsInfo();
}

void Account::cs_connectionClosed()
{
	printf("SAPO Messenger: connection closed\n");
	
#warning notify_...
	QMetaObject::invokeMethod(g_api, "notify_statusUpdated", Qt::QueuedConnection,
							  Q_ARG(QString, uuid()), Q_ARG(QString, show2str((ShowType)Offline)),
							  Q_ARG(QString, QString()));
	QMetaObject::invokeMethod(g_api, "notify_connectionError", Qt::QueuedConnection,
							  Q_ARG(QString, uuid()), Q_ARG(QString, QString("ConnectionClosed")),
							  Q_ARG(int, 0), Q_ARG(int, 0));
	
	// Safe cleanup/delete
	QTimer::singleShot(0, this, SLOT(cleanup()));
}

void Account::cs_delayedCloseFinished()
{
}

void Account::cs_warning(int x)
{
	Q_UNUSED(x);
	;//printf("App: ClientStream warning [%d]\n", x);
	_stream->continueAfterWarning();
}

char * Account::stream_error_name_from_error_codes(int error_kind, int *ret_error_nr, ClientStream *cs, AdvancedConnector *conn)
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

void Account::cs_error(int error_kind)
{
	ClientStream *stream = (ClientStream *)sender();
	int error_code = 0;
	
	char *error_name = stream_error_name_from_error_codes(error_kind, &error_code, stream, _conn);
	
#warning notify_...
	QMetaObject::invokeMethod(g_api, "notify_statusUpdated", Qt::QueuedConnection,
							  Q_ARG(QString, uuid()), Q_ARG(QString, show2str((ShowType)Offline)),
							  Q_ARG(QString, QString()));
	QMetaObject::invokeMethod(g_api, "notify_connectionError", Qt::QueuedConnection,
							  Q_ARG(QString, uuid()), Q_ARG(QString, QString(error_name)),
							  Q_ARG(int, error_kind), Q_ARG(int, error_code));
	
	// Safe cleanup/delete
	QTimer::singleShot(0, this, SLOT(cleanup()));
}

void Account::avatarFactory_selfAvatarHashValuesChanged()
{
	if (_client->isActive()) {
		// Send a new presence to announce the change
		setClientStatus(_req_show, _req_status, false);
	}
}

void Account::sapoAgents_sapoAgentsUpdated(const QVariantMap &agentsMap)
{
	Q_UNUSED(agentsMap);
	
	// Save the list of transport agents so that we can check up on their presence changes
	foreach (QString agentHost, agentsMap.keys()) {
		if (agentsMap[agentHost].toMap().contains("transport")) {
			_transportHostsRegManagers[agentHost] = new TransportRegistrationManager(_client, agentHost);
			
			connect(_transportHostsRegManagers[agentHost], SIGNAL(registrationStatusChanged(bool, QString)), SLOT(transportRegistrationStatusChanged(bool, QString)));
			connect(_transportHostsRegManagers[agentHost], SIGNAL(unregistrationFinished()), SLOT(transportUnRegistrationFinished()));
			
			_client->addRosterSubsyncAllowedDomain(agentHost);
			
			
			_transportHostsRegManagers[agentHost]->checkRegistrationState();
		}
	}
	
	if (_sapoAgentsTimer && _sapoAgentsTimer->isActive()) {
		_sapoAgentsTimer->stop();
		finishConnectAndGetRoster();
	}
	
	QMetaObject::invokeMethod(g_api, "notify_sapoAgentsUpdated", Qt::QueuedConnection,
							  Q_ARG(QString, uuid()), Q_ARG(QVariantMap, agentsMap));
}

void Account::serverItemsInfo_serverItemsUpdated(const QVariantList &items)
{
#warning notify_...
	QMetaObject::invokeMethod(g_api, "notify_serverItemsUpdated", Qt::QueuedConnection,
							  Q_ARG(QString, uuid()), Q_ARG(QVariantList, items));
}

void Account::serverItemsInfo_serverItemInfoUpdated(const QString &item, const QString &name, const QVariantList &identities, const QVariantList &features)
{
	// DATA TRANSFER PROXY
	if (features.contains("http://jabber.org/protocol/bytestreams")) {
		_dataTransferProxy = item;
	}
	
	// SAPO:SMS
	const Jid &smsCreditDestJid = _smsCreditManager->destinationJid();
	if (features.contains("sapo:sms") && (!smsCreditDestJid.isValid() || !(smsCreditDestJid.compare(Jid(item), false)))) {
		_smsCreditManager->setDestinationJid(Jid(item));
	}
	
	// SAPO:LIVEUPDATE
	if (features.contains("sapo:liveupdate")) {
		QString ourJidStr(_jid.bare());
		Jid jidForLiveupdate(ourJidStr.replace("@", "%") + "@" + item);
		
		JT_SapoLiveUpdate *liveupdateTask = new JT_SapoLiveUpdate(_client->rootTask(), jidForLiveupdate);
		connect(liveupdateTask, SIGNAL(finished()), SLOT(sapoLiveUpdateFinished()));
		liveupdateTask->go(true);
	}
	
	// SAPO:CHAT-ORDER
	if (features.contains("sapo:chat-order")) {
		JT_SapoChatOrder *chatOrderTask = new JT_SapoChatOrder(_client->rootTask(), Jid(item));
		connect(chatOrderTask, SIGNAL(finished()), SLOT(sapoChatOrderFinished()));
		chatOrderTask->go(true);
	}
	
	// SERVER-VARS
	if (features.contains("http://messenger.sapo.pt/protocols/server-vars")) {
		QString ourJidStr(_jid.bare());
		Jid jidForServerVars(ourJidStr.replace("@", "%") + "@" + item);
		
		JT_ServerVars *serverVarsTask = new JT_ServerVars(_client->rootTask(), jidForServerVars);
		connect(serverVarsTask, SIGNAL(finished()), SLOT(serverVarsFinished()));
		serverVarsTask->go(true);
	}
	
	// SAPO:DEBUG
	if (features.contains("sapo:debug")) {
		QString ourJidStr(_jid.bare());
		Jid jidForSapoDebug(ourJidStr.replace("@", "%") + "@" + item);
		
		JT_SapoDebug *sapoDebugTask = new JT_SapoDebug(_client->rootTask());
		connect(sapoDebugTask, SIGNAL(finished()), SLOT(sapoDebugFinished()));
		sapoDebugTask->getDebuggerStatus(jidForSapoDebug);
		sapoDebugTask->go(true);
	}
	
	// MUC
	if (features.contains("http://jabber.org/protocol/muc")) {
		if (!_chatRoomsBrowser)
			_chatRoomsBrowser = new ChatRoomsBrowser(_client->rootTask());
		
#warning connect() directamente ao g_api
		connect(_chatRoomsBrowser, SIGNAL(chatRoomsListReceived(const QString &, const QVariantList &)),
				g_api,             SLOT(notify_chatRoomsListReceived(const QString &, const QVariantList &)));
		connect(_chatRoomsBrowser, SIGNAL(chatRoomInfoReceived(const QString &, const QVariantMap &)),
				g_api,             SLOT(notify_chatRoomInfoReceived(const QString &, const QVariantMap &)));
	}
	
#warning notify_...
	QMetaObject::invokeMethod(g_api, "notify_serverItemInfoUpdated", Qt::QueuedConnection,
							  Q_ARG(QString, uuid()), Q_ARG(QString, item),
							  Q_ARG(QString, name),
							  Q_ARG(QVariantList, identities), Q_ARG(QVariantList, features));
}

void Account::sapoLiveUpdateFinished(void)
{
	JT_SapoLiveUpdate *liveupdateTask = (JT_SapoLiveUpdate *)sender();
	
	if (liveupdateTask->success()) {
#warning notify_...
		QMetaObject::invokeMethod(g_api, "notify_liveUpdateURLReceived", Qt::QueuedConnection,
								  Q_ARG(QString, uuid()),
								  Q_ARG(QString, liveupdateTask->url()));
	}
}

void Account::sapoChatOrderFinished(void)
{
	JT_SapoChatOrder *chatOrderTask = (JT_SapoChatOrder *)sender();
	
	if (chatOrderTask->success()) {
#warning notify_...
		QMetaObject::invokeMethod(g_api, "notify_sapoChatOrderReceived", Qt::QueuedConnection,
								  Q_ARG(QString, uuid()),
								  Q_ARG(QVariantMap, chatOrderTask->orderMap()));
	}
}

void Account::serverVarsFinished(void)
{
	JT_ServerVars *serverVarsTask = (JT_ServerVars *)sender();
	
	if (serverVarsTask->success()) {
#warning notify_...
		QMetaObject::invokeMethod(g_api, "notify_serverVarsReceived", Qt::QueuedConnection,
								  Q_ARG(QString, uuid()), Q_ARG(QVariantMap, serverVarsTask->variablesValues()));
	}
}

void Account::sapoDebugFinished(void)
{
	JT_SapoDebug *sapoDebugTask = (JT_SapoDebug *)sender();
	
	if (sapoDebugTask->success()) {
#warning notify_...
		QMetaObject::invokeMethod(g_api, "notify_debuggerStatusChanged", Qt::QueuedConnection,
								  Q_ARG(QString, uuid()), Q_ARG(bool, sapoDebugTask->isDebugger()));
	}
}

void Account::finishConnectAndGetRoster()
{
	_client->start(_jid.host(), _jid.user(), _pass, _resource);
	_client->rosterRequest();
}

void Account::transportRegistrationStatusChanged(bool newRegStatus, const QString &registeredUsername)
{
	TransportRegistrationManager *manager = (TransportRegistrationManager *)sender();
	
#warning notify_...
	QMetaObject::invokeMethod(g_api, "notify_transportRegistrationStatusUpdated", Qt::QueuedConnection,
							  Q_ARG(QString, uuid()),
							  Q_ARG(QString, manager->transportHost()),
							  Q_ARG(bool, newRegStatus),
							  Q_ARG(QString, registeredUsername));
}

void Account::transportUnRegistrationFinished(void)
{
	TransportRegistrationManager *manager = (TransportRegistrationManager *)sender();
	
#warning g_api->removeAllContactEntriesForTransport(manager->transportHost());
	g_api->removeAllContactEntriesForTransport(this, manager->transportHost());
}

void Account::audible_received(const Jid &from, const QString &audibleResourceName)
{
	g_api->audible_received(this, from, audibleResourceName);
}

void Account::smsCreditManager_updated(const QVariantMap &creditProps)
{
	g_api->smsCreditManager_updated(this, creditProps);
}

void Account::remoteOptionsManager_updated(void)
{
	QString statusMsg = _remoteOptionsMgr->statusMessage();
	QString show = _remoteOptionsMgr->status();
	
	ShowType show_type;
	
	/* TODO: Save the invisible status in the server cache. */
	if (_req_show == Invisible)
		show_type = Invisible;
	else if(show == "away")
		show_type = Away;
	else if(show == "xa")
		show_type = ExtendedAway;
	else if(show == "dnd")
		show_type = DoNotDisturb;
	else
		show_type = Online;

#warning notify_...
	QMetaObject::invokeMethod(g_api, "notify_savedStatusReceived", Qt::QueuedConnection,
							  Q_ARG(QString, uuid()), Q_ARG(QString, show2str(show_type)), Q_ARG(QString, statusMsg));
}

void Account::fileTransferMgr_incomingFileTransfer()
{
	FileTransfer *ft = client()->fileTransferManager()->takeIncoming();
	
	g_api->fileTransferMgr_incomingFileTransfer(this, ft);
}

void Account::client_activated()
{
	// Reset (and, consequently, refetch) our vCard from the server as it is needed for lots of stuff
	// (including the fullname for the account, the avatar stored in the server, etc)
	_vCardFactory->resetSelfVCard();
}

void Account::client_rosterRequestFinished(bool b, int, const QString &)
{
#warning g_api->deleteEmptyGroups();
	g_api->deleteEmptyGroups();
	
	if(!b) {
		;//printf("App: roster retrieve error\n");
		return;
	}
	
	;//printf("App: roster retrieve success\n");
	
	_logged_in = true;
	setClientStatus(_req_show, _req_status, false);
}

void Account::client_rosterItemAdded(const RosterItem &i)
{
	//updateContact(i.jid().full(), i.name(), Offline);
	//updateContact(i.jid().full(), i.name(), QString());
	
	// Is it a transport agent?
	if (_transportHostsRegManagers.contains(i.jid().bare())) {
		if (i.subscription().type() == Subscription::None || i.subscription().type() == Subscription::From) {
			// Auto-subscribe
			_client->sendSubscription(i.jid().bare(), "subscribe");
		}
	}
	
#warning g_api->client_rosterItemAdded(i);
	g_api->client_rosterItemAdded(this, i);
}

void Account::client_rosterItemUpdated(const RosterItem &i)
{
#warning g_api->client_rosterItemUpdated(i);
	g_api->client_rosterItemUpdated(this, i);
	
	/*const LiveRoster &lr = _client->roster();
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

void Account::client_rosterItemRemoved(const RosterItem &i)
{
#warning g_api->client_rosterItemRemoved(i);
	g_api->client_rosterItemRemoved(this, i);
	
	//removeContact(i.jid().full());
}

void Account::client_resourceAvailable(const Jid &j, const Resource &r)
{
#warning g_api->client_resourceAvailable(j, r);
	g_api->client_resourceAvailable(this, j, r);
	
	// Is it a transport agent?
	if (_transportHostsRegManagers.contains(j.bare())) {
		_transportHostsRegManagers[j.bare()]->checkRegistrationState();
		
#warning notify_...
		QMetaObject::invokeMethod(g_api, "notify_transportLoggedInStatusUpdated", Qt::QueuedConnection,
								  Q_ARG(QString, uuid()),
								  Q_ARG(QString, j.bare()), Q_ARG(bool, true));
	}
	
	
	/*const LiveRoster &lr = _client->roster();
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

void Account::client_resourceUnavailable(const Jid &j, const Resource &r)
{
#warning g_api->client_resourceUnavailable(j, r);
	g_api->client_resourceUnavailable(this, j, r);
	
	// Is it a transport agent?
	if (_transportHostsRegManagers.contains(j.bare())) {
		const LiveRoster &lr = _client->roster();
		LiveRoster::ConstIterator it = lr.find(j.withResource(QString()));
		
		if(it != lr.end()) {
			const ResourceList &resList = it->resourceList();
			
			// Was this the last available resource for this JID?
			if (!it->isAvailable() || (resList.count() == 1 && resList.priority()->name() == r.name())) {
				_transportHostsRegManagers[j.bare()]->checkRegistrationState();
				
#warning notify_...
				QMetaObject::invokeMethod(g_api, "notify_transportLoggedInStatusUpdated", Qt::QueuedConnection,
										  Q_ARG(QString, uuid()),
										  Q_ARG(QString, j.bare()), Q_ARG(bool, false));
				
			}
		}
	}
	
	// qDebug() << "UNAVAILABLE: " << j.full() << " " << r.status().capsNode() << " " << r.status().capsVersion() << " " << r.status().capsExt();
	// Update entity capabilities.
	// CAPABILITIES UPDATES ARE PERFORMED IN g_api->client_resourceUnavailable(j, r) (see above)
	//		capsManager()->disableCaps(j.withResource(r.name()));
	
	/*const LiveRoster &lr = _client->roster();
	 LiveRoster::ConstIterator it = lr.find(j.withResource(QString()));
	 if(it == lr.end())
	 return;
	 
	 //updateContact(j.withResource(r.name()).full(), (*it).name(), Offline);
	 updatePresence(j.full(), r.name(), Offline, QString());*/
}

void Account::client_presenceError(const Jid &, int, const QString &)
{
}

void Account::client_messageReceived(const Message &m)
{
#warning g_api->client_messageReceived(m);
	g_api->client_messageReceived(this, m);
}

void Account::client_subscription(const Jid &jid, const QString &type, const QString &nick, const QString &reason)
{
	// Is it a transport agent?
	if (_transportHostsRegManagers.contains(jid.bare())) {
		if (type == "subscribe") {
			// Auto-accept
			_client->sendSubscription(jid, "subscribed");
		}
	}
	else {
#warning g_api->client_subscription(jid, type, nick, reason);
		g_api->client_subscription(this, jid, type, nick, reason);
	}
	
	//if(type == "subscribe")
	//	grantRequest(jid.full());
}

void Account::client_xmlIncoming(const QString &xml)
{
	// TODO
	g_api->notify_accountXmlIO(uuid(), true, xml);
}

void Account::client_xmlOutgoing(const QString &xml)
{
	// TODO
	g_api->notify_accountXmlIO(uuid(), false, xml);
}

void Account::client_groupChatJoined(const Jid &j)
{
	g_api->client_groupChatJoined(this, j);
}

void Account::client_groupChatLeft(const Jid &j)
{
	g_api->client_groupChatLeft(this, j);
}

void Account::client_groupChatPresence(const Jid &j, const Status &s)
{
	g_api->client_groupChatPresence(this, j, s);
}

void Account::client_groupChatError(const Jid &j, int code, const QString &str)
{
	g_api->client_groupChatError(this, j, code, str);
}

void Account::capsManager_capsChanged(const Jid &j)
{
	g_api->capsManager_capsChanged(this, j);
}

void Account::avatarFactory_avatarChanged(const Jid &jid)
{
	g_api->avatarFactory_avatarChanged(this, jid);
}

void Account::avatarFactory_selfAvatarChanged(const QByteArray &avatarData)
{
	g_api->avatarFactory_selfAvatarChanged(this, avatarData);
}

void Account::vCardFactory_selfVCardChanged()
{
	XMPP::VCard myVCard = _vCardFactory->selfVCard();
	g_api->vCardFactory_selfVCardChanged(this, myVCard);
}
