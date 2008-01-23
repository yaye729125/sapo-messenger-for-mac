/*
 *  account.h
 *
 *	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jppavao@criticalsoftware.com>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informações sobre o licenciamento, leia o ficheiro README.
 */

#ifndef ACCOUNT_H
#define ACCOUNT_H


#include <QtCore>

#include "im.h"

#include "psi-helpers/avatars.h"
#include "psi-core/src/capsmanager.h"
#include "psi-helpers/vcardfactory.h"
#include "sapo/audibles.h"
#include "sapo/chat_rooms_browser.h"
#include "sapo/ping.h"
#include "sapo/server_items_info.h"
#include "sapo/sapo_agents.h"
#include "sapo/sapo_remote_options.h"
#include "sapo/sms.h"
#include "sapo/transport_registration.h"
#include "s5b.h"


enum ShowType
{
	Offline,
	Online,
	Away,
	ExtendedAway,
	DoNotDisturb,
	Invisible
};


using namespace XMPP;


class Account : public QObject
{
	Q_OBJECT
	
protected:
	bool					_avail;
	bool					_logged_in;
	
	Client					*_client;
	AdvancedConnector		*_conn;
	QCA::TLS				*_tls;
	QCATLSHandler			*_tlsHandler;
	ClientStream			*_stream;
	S5BServer				*_s5bServer;
	
	QString					_dataTransferProxy;
	
	QString					_uuid;
	Jid						_jid;
	QString					_host;
	QString					_pass;
	QString					_resource;
	bool					_use_ssl;
	
	ShowType				_req_show;
	QString					_req_status;
	
	ServerItemsInfo			*_serverItemsInfo;
	SapoAgents				*_sapoAgents;
	QTimer					*_sapoAgentsTimer;
	
	// Chat rooms
	ChatRoomsBrowser		*_chatRoomsBrowser;
	
	CapsManager				*_capsManager;
	AvatarFactory			*_avatarFactory;
	VCardFactory			*_vCardFactory;
	
	SapoSMSCreditManager	*_smsCreditManager;
	SapoRemoteOptionsMgr	*_remoteOptionsMgr;
	
	JT_PushSapoAudible		*_sapoAudibleListener;
	JT_PushXmppPing			*_xmppPingListener;
	
	// Map containing the hostnames of transport agents received from sapo:agents
	QMap<QString, TransportRegistrationManager *>	_transportHostsRegManagers;
	
public:
	Account(const QString &uuid);
	~Account();
	
	static void setClientInfoForAllAccounts (const QString &client_name, const QString &client_version,
											 const QString &os_name, const QString &caps_node, const QString &caps_version);
	static void setTimeZoneInfoForAllAccounts (const QString &tz_name, int tz_offset);
	static void setCachesFolderForAllAccounts (const QString &pathname);
	static void addCapsFeatureForAllAccounts (const QString &feature);
	
	void setClientInfo (const QString &client_name, const QString &client_version,
						const QString &os_name, const QString &caps_node, const QString &caps_version);
	void setTimeZoneInfo (const QString &tz_name, int tz_offset);
	void setCachesFolder (const QString &pathname);
	void setCapsFeatures (const XMPP::Features &features);
	
	
	const QString & uuid() const			{ return _uuid;			}
	const Jid & jid() const					{ return _jid;			}
	const QString & host() const			{ return _host;			}
	const QString & pass() const			{ return _pass;			}
	const QString & resource() const		{ return _resource;		}
	const bool useSSL() const				{ return _use_ssl;		}
	
	void setJid(const QString &newJid)		{ _jid = newJid;		}
	void setHost(const QString &newHost)	{ _host = newHost;		}
	void setPass(const QString &newPass)	{ _pass = newPass;		}
	void setResource(const QString &newRes)	{ _resource = newRes;	}
	void setUseSSL(bool newFlag)			{ _use_ssl = newFlag;	}
	
	Client			*client() const				{ return _client;				}
	const QString	&dataTransferProxy() const	{ return _dataTransferProxy;	}
	CapsManager		*capsManager() const		{ return _capsManager;			}
	AvatarFactory	*avatarFactory() const		{ return _avatarFactory;		}
	VCardFactory	*vCardFactory() const		{ return _vCardFactory;			}
	
	void setStatus (const QString &_show, const QString &status, bool saveToServer, bool alsoSaveStatusMsg);
	void sendMessage (const QString &jid_to, const QString &body);
	void rosterAddContact (const QString &jid, const QString &name, const QString &group);
	void rosterUpdateContact (const QString &jid, const QString &name, const QString &group);
	void rosterRemoveContact (const QString &jid);
	void rosterGrantAuth (const QString &jid);
	void transportRegister (const QString &host, const QString &username, const QString &password);
	void transportUnregister (const QString &host);
	void fetchChatRoomsListOnHost (const QString &host);
	void fetchChatRoomInfo (const QString &room_jid);
	void userIsTyping (const QString &jid_to);
	void userIsNotTyping (const QString &jid_to);
	void groupchatJoin (const QString &roomjid);
	void groupchatSendMessage (const QString &roomjid, const QString &body);
	void accountSendXML (const QString &xml);
	
private:
	void setClientStatus (const ShowType show_type, const QString &status,
						  bool saveToServer = false, bool alsoSaveStatusMsg = true);

	
private slots:
	void cleanup();
	
	void tls_handshaken();
	void cs_connected();
	void cs_securityLayerActivated(int type);
	void cs_needAuthParams(bool need_user, bool need_pass, bool need_realm);
	void cs_authenticated();	
	void sessionStart_finished();
	void sessionStarted();
	void cs_connectionClosed();
	void cs_delayedCloseFinished();
	void cs_warning(int x);
	char * stream_error_name_from_error_codes(int error_kind, int *ret_error_nr, ClientStream *cs, AdvancedConnector *conn);
	void cs_error(int error_kind);
	
	void avatarFactory_selfAvatarHashValuesChanged();
	void sapoAgents_sapoAgentsUpdated(const QVariantMap &agentsMap);
	void serverItemsInfo_serverItemsUpdated(const QVariantList &items);
	void serverItemsInfo_serverItemInfoUpdated(const QString &item, const QString &name, const QVariantList &identities, const QVariantList &features);
	void sapoLiveUpdateFinished(void);
	void sapoChatOrderFinished(void);
	void serverVarsFinished(void);
	void sapoDebugFinished(void);
	void finishConnectAndGetRoster();
	
	void transportRegistrationStatusChanged(bool newRegStatus, const QString &registeredUsername);
	void transportUnRegistrationFinished(void);
	void audible_received(const Jid &from, const QString &audibleResourceName);
	void smsCreditManager_updated(const QVariantMap &creditProps);
	void remoteOptionsManager_updated(void);
	void fileTransferMgr_incomingFileTransfer();
	void client_activated();
	void client_rosterRequestFinished(bool b, int, const QString &);
	void client_rosterItemAdded(const RosterItem &i);
	void client_rosterItemUpdated(const RosterItem &i);
	void client_rosterItemRemoved(const RosterItem &i);
	void client_resourceAvailable(const Jid &j, const Resource &r);
	void client_resourceUnavailable(const Jid &j, const Resource &r);
	void client_presenceError(const Jid &, int, const QString &);
	void client_messageReceived(const Message &m);
	void client_subscription(const Jid &jid, const QString &type, const QString &nick, const QString &reason);
	void client_xmlIncoming(const QString &xml);
	void client_xmlOutgoing(const QString &xml);
	void client_groupChatJoined(const Jid &j);
	void client_groupChatLeft(const Jid &j);
	void client_groupChatPresence(const Jid &j, const Status &s);
	void client_groupChatError(const Jid &j, int code, const QString &str);
	void capsManager_capsChanged(const Jid &j);
	void avatarFactory_avatarChanged(const Jid&);
	void avatarFactory_selfAvatarChanged(const QByteArray&);
	void vCardFactory_selfVCardChanged();	
};


#endif
