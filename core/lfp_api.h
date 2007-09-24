#ifndef LFP_API_H
#define LFP_API_H

#include <QtCore>
#include "im.h"
#include "lfp_call.h"
#include "filetransfer.h"
#include "xmpp_vcard.h"


class CapsManager;
class AvatarFactory;

class Account;

class Chat;
class GroupChat;
class FileTransferInfo;


using namespace XMPP;


class LfpApi : public QObject
{
	Q_OBJECT
protected:
	class Private;
	Private *d;

//	Client	*client;
	
#warning We should probably handle this in each account instance separately.
	QString	_dataTransferProxy;
	bool	_hasCustomDataTransferProxy;
	
//	CapsManager		*_capsManager;
//	AvatarFactory	*_avatarFactory;
	
public:
	
//	CapsManager		*capsManager()		{ return _capsManager;		}
//	AvatarFactory	*avatarFactory()	{ return _avatarFactory;	}
	
	
	LfpApi(); //(Client *c, CapsManager *cm, AvatarFactory *af);
	~LfpApi();
	
	//enum ShowMode { Online, Away, ExtendedAway, DoNotDisturb, Invisible, Chat, Offline };
	//enum GroupType { NoGroup, User, Agents, NotInList };
	//enum SortMode { Alpha, StatusAlpha, None };
	
	bool checkApi();
	bool checkOurMethod(const char *method, const LfpArgumentList &args);
	QByteArray getRetType(const char *method);
	
	void takeAllContactsOffline(const Account *account);
	void deleteEmptyGroups();
	void removeAllContactsForTransport(const Account *account, const QString &transportHost);
	
public slots:
	void client_rosterItemAdded(const Account *account, const RosterItem &i);
	void client_rosterItemUpdated(const Account *account, const RosterItem &i);
	void client_rosterItemRemoved(const Account *account, const RosterItem &i);
	void client_resourceAvailable(const Account *account, const Jid &j, const Resource &r);
	void client_resourceUnavailable(const Account *account, const Jid &j, const Resource &r);
	void client_subscription(const Account *account, const Jid &jid, const QString &type, const QString &nick);
	
private:
	Chat *getChatForJID (const Account *account, const Jid &fromJid);
public slots:
	void client_messageReceived(const Account *account, const Message &m);
	void audible_received(const Account *account, const Jid &, const QString &);
	void capsManager_capsChanged(const Account *account, const Jid &j);
	void avatarFactory_avatarChanged(const Account *account, const Jid&);
	void avatarFactory_selfAvatarChanged(const Account *account, const QByteArray&);
	void vCardFactory_selfVCardChanged(const Account *account, const VCard &myVCard);
	void clientVersion_finished();
	void smsCreditManager_updated(const Account *account, const QVariantMap &);
	
private:
	int addNewFileTransfer(const Account *account, FileTransfer *ft = NULL); // ret: file transfer bridge ID
	void cleanupFileTransferInfo(FileTransferInfo *fti);
public:
	// setAutoDataTransferProxy() is a NOP if setCustomDataTransferProxy() has already been called.
	void setAutoDataTransferProxy(const QString &proxyJid);
public slots:
	void fileTransferMgr_incomingFileTransfer(const Account *account, FileTransfer *ft);
	void fileTransferHandler_accepted();
	void fileTransferHandler_statusMessage(const QString &s);
	void fileTransferHandler_connected();
	void fileTransferHandler_progress(int p, qlonglong currentTotalSent);
	void fileTransferTimer_updateProgress();
	void fileTransferHandler_error(int, int, const QString &s);
	
	void getGCConfiguration_success(const XData& d);
	void getGCConfiguration_error(int, const QString& err_msg);
	void setGCConfiguration_success();
	void setGCConfiguration_error(int, const QString& err_msg);
	void client_groupChatJoined(const Account *account, const Jid &j);
	void client_groupChatLeft(const Account *account, const Jid &j);
	void client_groupChatPresence(const Account *account, const Jid &j, const Status &s);
	void client_groupChatError(const Account *account, const Jid &j, int code, const QString &str);
private:
	GroupChat *addNewGroupChat(const Account *account, const Jid &room_jid, const QString &nickname, bool request_history = false);
	void cleanupAndDeleteGroupChat(GroupChat *gc);
	
	void groupChatLeaveAndCleanup(GroupChat *gc);
	void processGroupChatMessage(const GroupChat *gc, const Message &m);
	
signals:
	void call_quit();
//	void call_setAccount(const QString &uuid, const QString &jid, const QString &host, const QString &pass, const QString &resource, bool use_ssl);
//	void call_removeAccount(const QString &uuid);
//	void call_transportRegister(const QString &, const QString &, const QString &);
//	void call_transportUnregister(const QString &);
	
//	void call_fetchChatRoomsListOnHost(const QString &host);
//	void call_fetchChatRoomInfo(const QString &room_jid);
	
public slots:
	// we implement these
	void systemQuit();
	void setClientInfo(const QString &client_name, const QString &client_version, const QString &os_name, const QString &caps_node, const QString &caps_version);
	void setTimeZoneInfo(const QString &tz_name, int tz_offset);
	void setSupportDataFolder(const QString &pathname);
	void addCapsFeature(const QString &feature);
	void setAccount(const QString &uuid, const QString &jid, const QString &host, const QString &pass, const QString &resource, bool use_ssl);
	void removeAccount(const QString &uuid);
	void setCustomDataTransferProxy(const QString &proxyJid);
	void accountSendXml(const QString &accountUUID, const QString &xml);
	void setStatus(const QString &accountUUID, const QString &show, const QString &status, bool saveToServer, bool alsoSaveStatusMessage);
	void rosterStart();
	int rosterGroupAdd(const QString &name, int pos); // int group_id
	void rosterGroupRemove(int group_id);
	void rosterGroupRename(int group_id, const QString &name);
	void rosterGroupMove(int group_id, int pos);
	QVariantMap rosterGroupGetProps(int group_id); // { QString type, QString name, int pos }
	int rosterContactAdd(int group_id, const QString &name, int pos); // int contact_id
	void rosterContactRemove(int contact_id);
	void rosterContactRename(int contact_id, const QString &name);
	void rosterContactSetAlt(int contact_id, const QString &name);
	void rosterContactMove(int contact_id, int pos);
	void rosterContactAddGroup(int contact_id, int group_id);
	void rosterContactChangeGroup(int contact_id, int group_old_id, int group_new_id);
	void rosterContactRemoveGroup(int contact_id, int group_id);
	QVariantMap rosterContactGetProps(int contact_id); // { QString name, QString altName, int pos }
	int rosterEntryAdd(int contact_id, const QString &accountUUID, const QString &address, int pos); // int entry_id
	void rosterEntryRemove(int entry_id);
	void rosterEntryMove(int entry_id, int contact_id, int pos);
	void rosterEntryChangeContact(int entry_id, int contact_old_id, int contact_new_id);
	QVariantMap rosterEntryGetProps(int entry_id); // { int account_id, QString address, int pos, QString sub, bool ask }
	QString rosterEntryGetFirstAvailableResource(int entry_id); // string resource
	QString rosterEntryGetResourceWithCapsFeature(int entry_id, const QString &feature); // string resource
	bool rosterEntryResourceHasCapsFeature(int entry_id, const QString &resource, const QString &feature);
	QVariantList rosterEntryGetResourceList(int entry_id); // sequence<string> resources
	QVariantList rosterEntryGetResourceCapsFeatures(int entry_id, const QString & resource); // sequence<string> features
	QVariantMap rosterEntryGetResourceProps(int entry_id, const QString &resource); // { ShowMode show, string status, string last_updated, string capabilities }
	void rosterEntryResourceClientInfoGet(int entry_id, const QString &resource);
	void rosterSortGroups(const QString &mode);
	void rosterSortContacts(const QString &mode);
	void authRequest(int entry_id);
	void authGrant(int entry_id, bool accept);
	QVariantMap chatStart(int contact_id, int entry_id); // { int chat_id, string address }
//	int chatStartGroup(const QString &room, const QString &nick); // int chat_id
//	QVariantMap chatStartGroupPrivate(int groupchat_id, const QString &nick); // { int chat_id, string address }
	void chatChangeEntry(int chat_id, int entry_id);
	void chatEnd(int chat_id);
	void chatMessageSend(int chat_id, const QString &plain, const QString &xhtml, const QVariantList &urls);
	void chatAudibleSend(int chat_id, const QString &audibleResourceName, const QString &plainTextAlternative, const QString &htmlAlternative);
	void chatSendInvalidAudibleError(int chat_id, const QString &errorMsg, const QString &audibleResourceName, const QString &originalMsgBody, const QString &originalMsgHTMLBody);
	void chatTopicSet(int chat_id, const QString &topic);
	void chatUserTyping(int chat_id, bool typing);
	
	void fetchChatRoomsListOnHost(const QString &accountUUID, const QString &host);
	void fetchChatRoomInfo(const QString &accountUUID, const QString &room_jid);
	
	int groupChatJoin(const QString &accountUUID, const QString &room_name, const QString &nickname, const QString &password, bool request_history);
	void groupChatRetryJoin(int group_chat_id, const QString &password);
	void groupChatChangeNick(int group_chat_id, const QString &nick);
	void groupChatChangeTopic(int group_chat_id, const QString &topic);
	void groupChatSetStatus(int group_chat_id, const QString &show, const QString &status);
	void groupChatSendMessage(int group_chat_id, const QString &msg);
	void groupChatEnd(int group_chat_id);
	void groupChatInvite(const QString &accountUUID, const QString &jid, const QString &roomJid, const QString &reason);
	void groupChatFetchConfigurationForm(int group_chat_id);
	void submitGroupChatConfigurationForm(int group_chat_id, const QString &configurationForm);
	
	void avatarSet(int contact_id, const QString &type, const QByteArray &data);
	void avatarPublish(const QString &type, const QByteArray &data);
	int fileStart(int entry_id, const QString &filesrc, const QString &desc); // int file_id
	int fileCreatePending(int entry_id);
	void fileStartPending(int transfer_id, int entry_id, const QString &filesrc, const QString &desc);
	void fileAccept(int file_id, const QString &filedest);
	void fileCancel(int file_id);
	QVariantMap fileGetProps(int file_id); // { int contact_id, string filename, long long size, string desc }
	int infoGet(int contact_id); // int trans_id
	int infoPublish(const QString &accountUUID, const QVariantMap &info); // int trans_id
	void sendSMS(int entry_id, const QString & text);
	void transportRegister(const QString &accountUUID, const QString &host, const QString &username, const QString &password);
	void transportUnregister(const QString &accountUUID, const QString &host);
	
	// we call out to these
	void notify_accountXmlIO(const QString &accountUUID, bool inbound, const QString &xml);
	void notify_accountConnectedToServerHost(const QString &accountUUID, const QString &hostname);
	void notify_connectionError(const QString &accountUUID, const QString &error_name, int error_kind, int error_code);
	void notify_statusUpdated(const QString &accountUUID, const QString &show, const QString &status);
	void notify_savedStatusReceived(const QString &accountUUID, const QString &show, const QString &status);
	void notify_rosterGroupAdded(int group_id, const QVariantMap & group_props);
	void notify_rosterGroupChanged(int group_id, const QVariantMap & group_props);
	void notify_rosterGroupRemoved(int group_id);
	void notify_rosterContactAdded(int group_id, int contact_id, const QVariantMap & props);
	void notify_rosterContactChanged(int contact_id, const QVariantMap & props);
	void notify_rosterContactGroupAdded(int contact_id, int group_id);
	void notify_rosterContactGroupChanged(int contact_id, int group_old_id, int group_new_id);
	void notify_rosterContactGroupRemoved(int contact_id, int group_id);
	void notify_rosterContactRemoved(int contact_id);
	void notify_rosterEntryAdded(int contact_id, int entry_id, const QVariantMap & props);
	void notify_rosterEntryChanged(int entry_id, const QVariantMap & props);
	void notify_rosterEntryContactChanged(int entry_id, int contact_old_id, int contact_new_id);
	void notify_rosterEntryRemoved(int entry_id);
	void notify_rosterEntryResourceListChanged(int entry_id, const QVariantList & resourceList);
	void notify_rosterEntryResourceChanged(int entry_id, const QString &resource);
	void notify_rosterEntryResourceCapabilitiesChanged(int entry_id, const QString &resource, const QVariantList & capsFeatures);
	void notify_rosterEntryResourceClientInfoReceived(int entry_id, const QString &resource, const QString &client_name, const QString &client_version, const QString &os_name);
	void notify_authGranted(int entry_id);
	void notify_authRequest(int entry_id);
	void notify_authLost(int entry_id);
	void notify_presenceUpdated(int entry_id, const QString &show, const QString &status);
	void notify_chatIncoming(int chat_id, int contact_id, int entry_id, const QString &address);
	void notify_chatIncomingPrivate(int chat_id, int groupchat_id, const QString &nick, const QString &address);
	void notify_chatEntryChanged(int chat_id, int entry_id);
	void notify_chatJoined(int chat_id);
	void notify_chatError(int chat_id, const QString &message);
	void notify_chatPresence(int chat_id, const QString &nick, const QString &show, const QString &status);
	void notify_chatMessageReceived(int chat_id, const QString &nick, const QString &subject, const QString &plain, const QString &xhtml, const QVariantList &urls);
	void notify_chatAudibleReceived(int chat_id, const QString &audibleResourceName, const QString &body, const QString &htmlBody);
	void notify_chatSystemMessageReceived(int chat_id, const QString &plain);
	void notify_chatTopicChanged(int chat_id, const QString &topic);
	void notify_chatContactTyping(int chat_id, const QString &nick, bool typing);
	
	void notify_groupChatJoined(int group_chat_id, const QString &room_jid, const QString &nickname);
	void notify_groupChatLeft(int group_chat_id);
	void notify_groupChatCreated(int group_chat_id);
	void notify_groupChatDestroyed(int group_chat_id, const QString &reason, const QString &alternate_room_jid);
	void notify_groupChatContactJoined(int group_chat_id, const QString &nickname, const QString &jid, const QString &role, const QString &affiliation);
	void notify_groupChatContactRoleOrAffiliationChanged(int group_chat_id, const QString &nickname, const QString &role, const QString &affiliation);
	void notify_groupChatContactStatusChanged(int group_chat_id, const QString &nickname, const QString &show, const QString &status);
	void notify_groupChatContactNicknameChanged(int group_chat_id, const QString &old_nickname, const QString &new_nickname);
	void notify_groupChatContactBanned(int group_chat_id, const QString &nickname, const QString &actor, const QString &reason);
	void notify_groupChatContactKicked(int group_chat_id, const QString &nickname, const QString &actor, const QString &reason);
	void notify_groupChatContactRemoved(int group_chat_id, const QString &nickname, const QString &due_to, const QString &actor, const QString &reason);  // "affiliation_change" OR "members_only"
	void notify_groupChatContactLeft(int group_chat_id, const QString &nickname, const QString &status);
	void notify_groupChatError(int group_chat_id, int code, const QString &str);
	void notify_groupChatTopicChanged(int group_chat_id, const QString &actor, const QString &new_topic);
	void notify_groupChatMessageReceived(int group_chat_id, const QString &from_nick, const QString &plain_body);
	void notify_groupChatInvitationReceived(const QString &accountUUID, const QString &room_jid, const QString &sender, const QString &reason, const QString &password);
	void notify_groupChatConfigurationFormReceived(int group_chat_id, const QString &formXDataXML, const QString &err_msg);
	void notify_groupChatConfigurationModificationResult(int group_chat_id, bool success, const QString &err_msg);
	
	void notify_offlineMessageReceived(const QString &accountUUID, const QString &timestamp, const QString &fromJID, const QString &nick, const QString &subject, const QString &plain, const QString &xhtml, const QVariantList &urls);
	void notify_headlineNotificationMessageReceived(const QString &accountUUID, const QString &channel, const QString &item_url, const QString &flash_url, const QString &icon_url, const QString &nick, const QString &subject, const QString &plain, const QString &xhtml);
	void notify_avatarChanged(int entry_id, const QString &type, const QByteArray &data);
	void notify_selfAvatarChanged(const QString &accountUUID, const QString &type, const QByteArray &data);
	void notify_fileIncoming(int file_id);
	void notify_fileAccepted(int file_id);
	void notify_fileProgress(int file_id, const QString &status, qlonglong sent, qlonglong progressAt, qlonglong progressTotal);
	void notify_fileFinished(int file_id);
	void notify_fileError(int file_id, const QString &message);
	void notify_infoReady(int trans_id, const QVariantMap &info);
	void notify_infoPublished(int trans_id);
	void notify_infoError(int trans_id, const QString &message);
	void notify_serverItemsUpdated(const QVariantList &server_items);
	void notify_serverItemInfoUpdated(const QString &item, const QString &name, const QVariantList &features);
	void notify_sapoAgentsUpdated(const QVariantMap &sapo_agents_description);
	
	void notify_chatRoomsListReceived(const QString &host, const QVariantList &rooms_list);
	void notify_chatRoomInfoReceived(const QString &room_jid, const QVariantMap &info);
	
	void notify_smsCreditUpdated(const QString &accountUUID, int credit, int free_msgs, int total_sent_this_month);
	void notify_smsSent(const QString &accountUUID,
						int result, int nr_used_msgs, int nr_used_chars,
						const QString & destination_phone_nr, const QString & body,
						int credit, int free_msgs, int total_sent_this_month);
	void notify_smsReceived(const QString &accountUUID,
							const QString & date_received, const QString & source_phone_nr, const QString & body,
							int credit, int free_msgs, int total_sent_this_month);
	void notify_liveUpdateURLReceived(const QString &accountUUID, const QString &url);
	void notify_sapoChatOrderReceived(const QString &accountUUID, const QVariantMap &orderMap);
	void notify_transportRegistrationStatusUpdated(const QString &accountUUID, const QString &transportAgent, bool registered, const QString &registeredUsername);
	void notify_transportLoggedInStatusUpdated(const QString &accountUUID, const QString &transportAgent, bool logged_in);
	void notify_serverVarsReceived(const QString &accountUUID, const QVariantMap &varsValues);
	void notify_selfVCardChanged(const QString &accountUUID, const QVariantMap &vCard);
	void notify_debuggerStatusChanged(const QString &accountUUID, bool isDebugger);
};

#endif
