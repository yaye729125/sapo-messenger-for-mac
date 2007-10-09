#include "lfp_api.h"

#include "leapfrog_platform.h"
#include "account.h"

#include "psi-helpers/avatars.h"
#include "psi-core/src/capsmanager.h"
#include "psi-core/src/capsregistry.h"
#include "psi-core/src/mucmanager.h"
#include "psi-helpers/filetransferhandler.h"
#include "psi-helpers/vcardfactory.h"
#include "sapo/audibles.h"
#include "sapo/sms.h"
#include "filetransfer.h"

#include "xmpp_tasks.h"
#include "xmpp_vcard.h"

#include <QtCore>


extern leapfrog_platform_t *g_instance;


// To send notifications to the other side of the bridge
static void do_invokeMethod(const char *method, const LfpArgumentList &args)
{
	QByteArray buf = args.toArray();
	leapfrog_args_t lfp_args;
	lfp_args.data = (unsigned char *)buf.data();
	lfp_args.size = buf.size();
	leapfrog_platform_invokeMethod(g_instance, method, &lfp_args);
}


static bool checkMethod(const char *method, const LfpArgumentList &args)
{
	QByteArray buf = args.toArray();
	leapfrog_args_t lfp_args;
	lfp_args.data = (unsigned char *)buf.data();
	lfp_args.size = buf.size();
	return leapfrog_platform_checkMethod(g_instance, method, &lfp_args) == 0 ? false : true;
}


#pragma mark -
#pragma mark API data indexes


static int id_entry = 0;
static int id_contact = 0;
static int id_group = 0;
static int id_chat = 0;
static int id_groupChatContact = 0;
static int id_groupChat = 0;
static int id_fileTransfer = 0;
static int id_trans = 0;

class Group;
class Contact;

class ContactEntry
{
public:
	Account *account;
	Contact *contact;
	int id;
	QString jid;
	QString name;
	QString sub;
	bool ask;

	QStringList groups;
	QString mainGroup; // TODO: only support one group for now
};

class Contact
{
public:
	QList<Group*> groups;
	int id;
	QString name, alt;
	QList<ContactEntry*> entries;

	bool inList() const;
};

class Group
{
public:
	int id;
	QString name;
	QString type;
	QList<Contact*> contacts;
};

bool Contact::inList() const
{
	// FIXME: only using one group for now
	if(groups[0]->type == "NotInList")
		return false;
	return true;
}

class Chat
{
public:
	int id;
	Contact *contact;
	ContactEntry *entry;
	Jid jid;
};

class GroupChatContact
{
public:
	int id;
	QString full_jid;
	QString real_jid;
	QString nickname;
	QString role;
	QString affiliation;
	QString status;
	QString status_msg;
};

class GroupChat
{
public:
	int						id;
	Account					*account;
	Jid						room_jid;
	bool					req_hist_on_join;
	bool					joined;
	QString					nickname;
	GroupChatContact		*me;
	MUCManager				*mucManager;
	
	QList<GroupChatContact *>	participants;
};


class FileTransferInfo
{
public:
	int					id;
	FileTransferHandler *fileTransferHandler;
	Account				*account;
	QTimer				*progressTimer;
	qlonglong			totalBytesSentOnLastNotification;
	qlonglong			currentTotalBytesSent;
};

class TransInfo
{
public:
	int id;
	ContactEntry *entry;
	JT_VCard *task;
};

static QVariantMap vcardToInfoMap(const VCard &v)
{
	QVariantMap i;
	i["fullname"] = v.fullName();
	i["given"]    = v.givenName();
	i["family"]   = v.familyName();
	i["nickname"] = v.nickName();
	i["bday"]     = v.bdayStr();
	{
		VCard::EmailList list = v.emailList();
		if(!list.isEmpty())
			i["email"] = list[0].userid;
	}
	i["url"]      = v.url();
	{
		VCard::PhoneList list = v.phoneList();
		if(!list.isEmpty())
			i["phone"] = list[0].number;
	}
	{
		VCard::AddressList list = v.addressList();
		if(!list.isEmpty())
		{
			const VCard::Address &a = list[0];
			i["street1"]  = a.street;
			i["street2"]  = a.extaddr;
			i["locality"] = a.locality;
			i["region"]   = a.region;
			i["postal"]   = a.pcode;
			i["country"]  = a.country;
		}
	}
	{
		VCard::Org org = v.org();
		i["orgname"] = org.name;
		if(!org.unit.isEmpty())
			i["orgunit"]  = org.unit[0];
	}
	i["title"]    = v.title();
	i["role"]     = v.role();
	i["desc"]     = v.desc();
	return i;
}

static VCard infoMapToVCard(const QVariantMap &i)
{
	VCard v;
	if(i.contains("fullname"))
		v.setFullName(i["fullname"].toString());
	if(i.contains("given"))
		v.setGivenName(i["given"].toString());
	if(i.contains("family"))
		v.setFamilyName(i["family"].toString());
	if(i.contains("nickname"))
		v.setNickName(i["nickname"].toString());
	if(i.contains("bday"))
		v.setBdayStr(i["bday"].toString());
	if(i.contains("email"))
	{
		VCard::EmailList list;
		VCard::Email e;
		e.internet = true;
		e.userid = i["email"].toString();
		list += e;
		v.setEmailList(list);
	}
	if(i.contains("url"))
		v.setUrl(i["url"].toString());
	if(i.contains("phone"))
	{
		VCard::PhoneList list;
		VCard::Phone e;
		e.home = true;
		e.voice = true;
		e.number = i["phone"].toString();
		list += e;
		v.setPhoneList(list);
	}
	if(i.contains("street1") || i.contains("street2") || i.contains("locality")
		|| i.contains("region") || i.contains("postal") || i.contains("country"))
	{
		VCard::AddressList list;
		VCard::Address a;
		a.home = true;
		if(i.contains("street1"))
			a.street = i["street1"].toString();
		if(i.contains("street2"))
			a.extaddr = i["street2"].toString();
		if(i.contains("locality"))
			a.locality = i["locality"].toString();
		if(i.contains("region"))
			a.region = i["region"].toString();
		if(i.contains("postal"))
			a.pcode = i["postal"].toString();
		if(i.contains("country"))
			a.country = i["country"].toString();
		list += a;
		v.setAddressList(list);
	}
	if(i.contains("orgname") || i.contains("orgunit"))
	{
		VCard::Org org;
		if(i.contains("orgname"))
			org.name = i["orgname"].toString();
		if(i.contains("orgunit"))
		{
			QStringList list;
			list += i["orgunit"].toString();
			org.unit = list;
		}
		v.setOrg(org);
	}
	if(i.contains("title"))
		v.setTitle(i["title"].toString());
	if(i.contains("role"))
		v.setRole(i["role"].toString());
	if(i.contains("desc"))
		v.setDesc(i["desc"].toString());
	return v;
}


#pragma mark -


class LfpApi::Private : public QObject
{
	Q_OBJECT
public:
	LfpApi						*q;
	QList<Group*>				groups;
	QList<Chat*>				chats;
	QList<GroupChat*>			group_chats;
	QList<FileTransferInfo*>	file_transfers;
	QList<TransInfo*>			transinfos;
	
	QMap<int, Group *>					groupsByID;
	QMap<int, Contact *>				contactsByID;
	QMap<int, ContactEntry *>			entriesByID;
	QMap<QString, ContactEntry *>		entriesByBareJID;
	QMap<int, GroupChatContact *>		groupChatContactsByID;
	QMap<QString, GroupChatContact *>	groupChatContactsByJID;
	
	QMap<QString, Account *>			accountsByUUID;
	
	
	void registerGroup(Group *g)
	{
		groupsByID[g->id] = g;
	}
	
	void unregisterGroup(Group *g)
	{
		groupsByID.remove(g->id);
	}
	
	Group *findGroup(int id)
	{
		return (groupsByID.contains(id) ? groupsByID[id] : NULL);
	}

	Group *findGroup(const QString &type, const QString &name)
	{
		for(int n = 0; n < groups.count(); ++n)
		{
			// FIXME: only compare name for User type
			if(groups[n]->type == type && groups[n]->name == name)
				return groups[n];
		}
		return 0;
	}

	void registerContact(Contact *c)
	{
		contactsByID[c->id] = c;
	}
	
	void unregisterContact(Contact *c)
	{
		contactsByID.remove(c->id);
	}
	
	Contact *findContact(int id)
	{
		return (contactsByID.contains(id) ? contactsByID[id] : NULL);
	}
	
	Contact *findContact(const QString &name, const QString &groupName, const QString &groupType = "User")
	{
		Group *g = findGroup(groupType, groupName);
		
		if (g) {
			foreach (Contact *c, g->contacts) {
				if (c->name == name) return c;
			}
		}
		return NULL;
	}
	
	void registerEntry(ContactEntry *e)
	{
		entriesByID[e->id] = e;
		
		//entriesByBareJID[e->jid] = e;
		entriesByBareJID.insertMulti(e->jid, e);
	}
	
	void unregisterEntry(ContactEntry *e)
	{
		entriesByID.remove(e->id);
		
		//entriesByBareJID.remove(e->jid);
		QMap<QString, ContactEntry *>::iterator mapIter = entriesByBareJID.find(e->jid);
		while (mapIter != entriesByBareJID.end() && mapIter.key() == e->jid) {
			if (mapIter.value() == e) {
				entriesByBareJID.erase(mapIter);
				break;
			}
			++mapIter;
		}
	}
	
	ContactEntry *findEntry(int id)
	{
		return (entriesByID.contains(id) ? entriesByID[id] : NULL);
	}
	
	ContactEntry *findEntry(const Account *account, const Jid &j, bool compareResource = false)
	{
		Q_UNUSED(compareResource);
		
		QString jid = j.bare();
		
		QList<ContactEntry *> entries = entriesByBareJID.values(jid);
		foreach (ContactEntry *entry, entries)
			if (entry->account == account)
				return entry;
		
		return NULL;
	}
	
	Chat *findChat(int id)
	{
		for(int n = 0; n < chats.count(); ++n)
		{
			if(chats[n]->id == id)
				return chats[n];
		}
		return 0;
	}

	Chat *findChat(Contact *contact)
	{
		for(int n = 0; n < chats.count(); ++n)
		{
			if(chats[n]->contact == contact)
				return chats[n];
		}
		return 0;
	}
	
	Chat *findChat(const Account *account, const Jid &j, bool compareResource = true)
	{
		for(int n = 0; n < chats.count(); ++n)
		{
			if(chats[n]->jid.compare(j, compareResource) && chats[n]->entry->account == account)
				return chats[n];
		}
		return 0;
	}
	
	void registerGroupChatContact(GroupChatContact *c)
	{
		groupChatContactsByID[c->id] = c;
		groupChatContactsByJID[c->full_jid] = c;
	}
	
	void unregisterGroupChatContact(GroupChatContact *c)
	{
		groupChatContactsByID.remove(c->id);
		groupChatContactsByJID.remove(c->full_jid);
	}
	
	GroupChatContact *findGroupChatContact(int id)
	{
		return (groupChatContactsByID.contains(id) ? groupChatContactsByID[id] : NULL);
	}
	
	GroupChatContact *findGroupChatContact(const Jid &group_chat_contact_jid)
	{
		return (groupChatContactsByJID.contains(group_chat_contact_jid.full()) ?
				groupChatContactsByJID[group_chat_contact_jid.full()] :
				NULL);
	}

	GroupChat *findGroupChat(int id)
	{
		for(int n = 0; n < group_chats.count(); ++n)
		{
			if(group_chats[n]->id == id)
				return group_chats[n];
		}
		return 0;
	}
	
	GroupChat *findGroupChat(const Account *account, const Jid &room_jid)
	{
		for(int n = 0; n < group_chats.count(); ++n)
		{
			if(group_chats[n]->room_jid.compare(room_jid, false) && group_chats[n]->account == account)
				return group_chats[n];
		}
		return 0;
	}
	
	GroupChat *findGroupChat(MUCManager *mm)
	{
		for(int n = 0; n < group_chats.count(); ++n)
		{
			if(group_chats[n]->mucManager == mm)
				return group_chats[n];
		}
		return 0;
	}
	
	Account *findAccount(Client *client)
	{
		foreach (Account *account, accountsByUUID.values()) {
			if (account->client() == client)
				return account;
		}
		return NULL;
	}
	
	FileTransferInfo *findFileTransferInfo(int id)
	{
		for(int n = 0; n < file_transfers.count(); ++n)
		{
			if(file_transfers[n]->id == id)
				return file_transfers[n];
		}
		return 0;
	}
	
	FileTransferInfo *findFileTransferInfo(FileTransferHandler *fth)
	{
		for(int n = 0; n < file_transfers.count(); ++n)
		{
			if(file_transfers[n]->fileTransferHandler == fth)
				return file_transfers[n];
		}
		return 0;
	}

	FileTransferInfo *findFileTransferInfo(QTimer *progressTimer)
	{
		for(int n = 0; n < file_transfers.count(); ++n)
		{
			if(file_transfers[n]->progressTimer == progressTimer)
				return file_transfers[n];
		}
		return 0;
	}
	
	TransInfo *findTransInfo(int id)
	{
		for(int n = 0; n < transinfos.count(); ++n)
		{
			if(transinfos[n]->id == id)
				return transinfos[n];
		}
		return 0;
	}

	TransInfo *findTransInfo(JT_VCard *task)
	{
		for(int n = 0; n < transinfos.count(); ++n)
		{
			if(transinfos[n]->task == task)
				return transinfos[n];
		}
		return 0;
	}
	
public slots:
	void transinfo_finished()
	{
		TransInfo *t = findTransInfo((JT_VCard *)sender());
		if(!t)
			return;

		if(t->task->success())
		{
			// get?
			if(t->entry)
			{
				QVariantMap i = vcardToInfoMap(t->task->vcard());

				// success
				QMetaObject::invokeMethod(q, "notify_infoReady", Qt::QueuedConnection,
										  Q_ARG(int, t->id), Q_ARG(QVariantMap, i));
			}
			else
			{
				// success
				QMetaObject::invokeMethod(q, "notify_infoPublished", Qt::QueuedConnection,
										  Q_ARG(int, t->id));
			}
		}
		else
		{
			QString str = t->task->statusString();

			// error
			QMetaObject::invokeMethod(q, "notify_infoError", Qt::QueuedConnection,
									  Q_ARG(int, t->id), Q_ARG(QString, str));
		}

		transinfos.removeAll(t);
		delete t;
	}
};

#pragma mark -

LfpApi::LfpApi() //(Client *c, CapsManager *cm, AvatarFactory *af) : client(c), _capsManager(cm), _avatarFactory(af)
{
	d = new Private;
	d->q = this;

	Group *g = new Group;
	g->id = id_group++;
	g->type = "NoGroup";
	g->name = "General";
	
	d->groups += g;
	d->registerGroup(g);
	
	g = new Group;
	g->id = id_group++;
	g->type = "NotInList";
	g->name = "Not In List";
	
	d->groups += g;
	d->registerGroup(g);
	
#warning We should probably handle this in each account instance separately.
	_hasCustomDataTransferProxy = false;
	_dataTransferProxy = QString();
	
	qRegisterMetaType<qlonglong>("qlonglong");
	qRegisterMetaType<QVariantList>("QVariantList");
	qRegisterMetaType<QVariantMap>("QVariantMap");
}

LfpApi::~LfpApi()
{
	delete d;
}

bool LfpApi::checkApi()
{
	//printf("app: Verifying methods\n");
	const QMetaObject *mo = metaObject();
	for(int n = mo->methodOffset(); n < mo->methodCount(); ++n)
	{
		QMetaMethod m = mo->method(n);
		if(m.methodType() != QMetaMethod::Slot)
			continue;
		QByteArray sig = m.signature();
		int n = sig.indexOf('(');
		if(n == -1)
			continue;
		QByteArray method = sig.mid(0, n);

		LfpArgumentList args;
		if(method.left(7) == "notify_")
		{
			//printf("Function: [%s]\n", method.data());
			QList<QByteArray> pnames = m.parameterNames();
			QList<QByteArray> ptypes = m.parameterTypes();
			for(int n2 = 0; n2 < pnames.count(); ++n2)
			{
				QVariant::Type vType = QVariant::nameToType(ptypes[n2].data());
				QVariant v(vType);
				args += LfpArgument(QString::fromLatin1(pnames[n2]), v);
				//printf("  %s %s\n", ptypes[n2].data(), pnames[n2].data());
			}
		}
		else
		{
			method += "_ret";
			//printf("Function: [%s]\n", method.data());
			QByteArray retTypeName = m.typeName();
			if(!retTypeName.isEmpty())
			{
				QVariant::Type vType = QVariant::nameToType(retTypeName.data());
				QVariant v(vType);
				args += LfpArgument("ret", v);
				//printf("  %s %s\n", retTypeName.data(), "ret");
			}
		}

		if(!checkMethod(method.data(), args))
		{
			//printf("app: Method missing!\n");
			return false;
		}
	}
	return true;
}

bool LfpApi::checkOurMethod(const char *c_method, const LfpArgumentList &args)
{
	const QMetaObject *mo = metaObject();
	for(int n = mo->methodOffset(); n < mo->methodCount(); ++n)
	{
		QMetaMethod m = mo->method(n);
		QByteArray sig = m.signature();
		int n = sig.indexOf('(');
		if(n == -1)
			continue;
		QByteArray method = sig.mid(0, n);

		if(method != c_method)
			continue;

		bool args_good = true;
		QList<QByteArray> pnames = m.parameterNames();
		QList<QByteArray> ptypes = m.parameterTypes();
		for(int n2 = 0; n2 < pnames.count(); ++n2)
		{
			QVariant::Type vType = QVariant::nameToType(ptypes[n2].data());
			if(args[n2].value.type() != vType /*|| args[n2].name.toLatin1() != pnames[n2]*/)
			{
				args_good = false;
				break;
			}
		}
		if(!args_good)
			break;

		return true;
	}
	return false;
}

QByteArray LfpApi::getRetType(const char *_method)
{
	const QMetaObject *mo = metaObject();
	for(int n = mo->methodOffset(); n < mo->methodCount(); ++n)
	{
		QMetaMethod m = mo->method(n);
		QByteArray sig = m.signature();
		int n = sig.indexOf('(');
		if(n == -1)
			continue;
		QByteArray method = sig.mid(0, n);

		if(method != _method)
			continue;

		return m.typeName();
	}
	return QByteArray();
}

void LfpApi::takeAllContactsOffline(const Account *account)
{
	for(int n = 0; n < d->groups.count(); ++n) {
		Group *g = d->groups[n];
		for(int n2 = 0; n2 < g->contacts.count(); ++n2) {
			Contact *c = g->contacts[n2];
			for(int n3 = 0; n3 < c->entries.count(); ++n3) {
				ContactEntry *e = c->entries[n3];
				
				if (e->account != account)
					continue;
				
				QMetaObject::invokeMethod(this, "notify_presenceUpdated", Qt::QueuedConnection,
										  Q_ARG(int, e->id), Q_ARG(QString, QString("Offline")), Q_ARG(QString, QString()));
				
				QMetaObject::invokeMethod(this, "notify_rosterEntryResourceListChanged", Qt::QueuedConnection,
										  Q_ARG(int, e->id), Q_ARG(QVariantList, QVariantList()));
				
				// Only discard capabilities after having taken care of the notifications emitted above.
				// Discarding the capabilities triggers a bridge notification, and the GUI layer should already
				// have been notified about the current presence so that it can act upon the loss of capabilities
				// info more appropriately.
				const Jid					jid(e->jid);
				const LiveRoster			&r = account->client()->roster();
				LiveRoster::ConstIterator	roster_it = r.find(jid, false);
				
				if (roster_it != r.constEnd()) {
					const ResourceList	&res_list = (*roster_it).resourceList();
					foreach (Resource res, res_list) {
						const Jid &jidForCaps = (jid.resource().isEmpty() ?
												 jid.withResource(res.name()) :
												 jid);
						account->capsManager()->disableCaps(jidForCaps);
					}
				}
			}
		}
	}
}

void LfpApi::deleteEmptyGroups()
{
	foreach (Group *g, d->groups) {
		if (g->contacts.isEmpty()) {
			rosterGroupRemove(g->id);
		}
	}
}

void LfpApi::removeAllContactEntriesForTransport(const Account *account, const QString &transportHost)
{
	foreach (QString jid, d->entriesByBareJID.keys()) {
		if (jid == transportHost || jid.endsWith("@" + transportHost)) {
			QList<ContactEntry *> entries = d->entriesByBareJID.values(jid);
			
			foreach (ContactEntry *e, entries) {
				if (e->account == account) {
					Contact *c = e->contact;
					Group *g = (e->mainGroup.isEmpty() ? NULL : d->findGroup("User", e->mainGroup));
					
					rosterEntryRemove(d->entriesByBareJID[jid]->id);
					
					if (c->entries.count() == 0)
						rosterContactRemove(c->id);
					if (g && g->contacts.count() == 0)
						rosterGroupRemove(g->id);
				}
			}
		}
	}
}

void LfpApi::removeAllContactEntriesForAccount(const Account *account)
{
	foreach (ContactEntry *entry, d->entriesByID.values()) {
		if (entry->account == account) {
			Contact *c = entry->contact;
			Group *g = (entry->mainGroup.isEmpty() ? NULL : d->findGroup("User", entry->mainGroup));
			
			rosterEntryRemove(entry->id);
			
			if (c->entries.count() == 0)
				rosterContactRemove(c->id);
			if (g && g->contacts.count() == 0)
				rosterGroupRemove(g->id);
		}
	}
}

void LfpApi::systemQuit()
{
	emit call_quit();
}

void LfpApi::setClientInfo(const QString &client_name, const QString &client_version, const QString &os_name, const QString &caps_node, const QString &caps_version)
{
	Account::setClientInfoForAllAccounts(client_name, client_version, os_name, caps_node, caps_version);
}

void LfpApi::setTimeZoneInfo(const QString &tz_name, int tz_offset)
{
	Account::setTimeZoneInfoForAllAccounts(tz_name, tz_offset);
}

void LfpApi::setSupportDataFolder(const QString &pathname)
{
	Account::setSupportDataFolderForAllAccounts(pathname);
}

void LfpApi::addCapsFeature(const QString &feature)
{
	Account::addCapsFeatureForAllAccounts(feature);
}

void LfpApi::setAccount(const QString &uuid, const QString &jid, const QString &host, const QString &pass, const QString &resource, bool use_ssl)
{
	//printf("app: LfpApi::setAccount\n");
	
	Account *acc = NULL;
	
	if (d->accountsByUUID.contains(uuid)) {
		acc = d->accountsByUUID[uuid];
	} else {
		acc = new Account(uuid);
		d->accountsByUUID[uuid] = acc;
	}
	
	acc->setJid(jid);
	acc->setHost(host);
	acc->setPass(pass);
	acc->setResource(resource);
	acc->setUseSSL(use_ssl);
}

void LfpApi::removeAccount(const QString &uuid)
{
	//printf("app: LfpApi::removeAccount\n");
	
	if (d->accountsByUUID.contains(uuid)) {
		Account *account = d->accountsByUUID[uuid];
		
		removeAllContactEntriesForAccount(account);
		
		delete account;
		d->accountsByUUID.remove(uuid);
	}
}

void LfpApi::setCustomDataTransferProxy(const QString &proxyJid)
{
	_hasCustomDataTransferProxy = true;
	_dataTransferProxy = proxyJid;
}

void LfpApi::setAutoDataTransferProxy(const QString &proxyJid)
{
	if (!_hasCustomDataTransferProxy)
		_dataTransferProxy = proxyJid;
}

void LfpApi::accountSendXml(const QString &accountUUID, const QString &xml)
{
	if (d->accountsByUUID.contains(accountUUID)) {
		d->accountsByUUID[accountUUID]->accountSendXML(xml);
	}
}

void LfpApi::setStatus(const QString &accountUUID, const QString &show, const QString &status, bool saveToServer, bool alsoSaveStatusMessage)
{
	if (d->accountsByUUID.contains(accountUUID)) {
		d->accountsByUUID[accountUUID]->setStatus(show, status, saveToServer, alsoSaveStatusMessage);
	}
}


#pragma mark -


void LfpApi::rosterStart()
{
	// announce built-in groups
	for(int n = 0; n < d->groups.count(); ++n)
	{
		QMetaObject::invokeMethod(this, "notify_rosterGroupAdded", Qt::QueuedConnection,
								  Q_ARG(int, d->groups[n]->id),
								  Q_ARG(QVariantMap, rosterGroupGetProps(d->groups[n]->id)));
	}
}

int LfpApi::rosterGroupAdd(const QString &name, int pos)
{
	Group *g;
	
	if (name.isEmpty())
		return -1;
	
	// No duplicates, please
	g = d->findGroup("User", name);
	if (g)
		return g->id;
	
	g = new Group;
	g->id = id_group++;
	g->type = "User";
	g->name = name;
	if(pos == -1)
		d->groups += g;
	else
		d->groups.insert(pos, g);
	
	d->registerGroup(g);

	QMetaObject::invokeMethod(this, "notify_rosterGroupAdded", Qt::QueuedConnection,
							  Q_ARG(int, g->id), Q_ARG(QVariantMap, rosterGroupGetProps(g->id)));
	return g->id;
}

void LfpApi::rosterGroupRemove(int group_id)
{
	Group *g = d->findGroup(group_id);
	if(!g)
		return;
	if(g->type != "User")
		return;

	foreach(Contact *c, g->contacts)
		rosterContactRemoveGroup(c->id, group_id);

	d->groups.removeAll(g);
	d->unregisterGroup(g);
	delete g;

	QMetaObject::invokeMethod(this, "notify_rosterGroupRemoved", Qt::QueuedConnection,
							  Q_ARG(int, group_id));
}

void LfpApi::rosterGroupRename(int group_id, const QString &name)
{
	Group *g = d->findGroup(group_id);
	if (name.isEmpty())
		return;
	if(!g)
		return;
	if(g->type != "User")
		return;
	QString oldname = g->name;
	g->name = name;

	// commit groupchanges (commit all entries of all contacts)
	foreach (Contact *c, g->contacts) {
		foreach (ContactEntry *ce, c->entries) {
			ce->groups.removeAll(oldname);
			ce->groups.append(name);
			if (ce->mainGroup == oldname)
				ce->mainGroup = name;
			
			JT_Roster *r = new JT_Roster(ce->account->client()->rootTask());
			r->set(ce->jid, ce->name, ce->groups);
			r->go(true);
		}
	}

	QMetaObject::invokeMethod(this, "notify_rosterGroupChanged", Qt::QueuedConnection,
							  Q_ARG(int, group_id), Q_ARG(QVariantMap, rosterGroupGetProps(group_id)));
}

void LfpApi::rosterGroupMove(int group_id, int pos)
{
	Group *g = d->findGroup(group_id);
	if(!g)
		return;
	if(g->type != "User")
		return;
	QList<int> old;
	for(int n = 0; n < d->groups.count(); ++n)
		old += d->groups[n]->id;
	d->groups.move(d->groups.indexOf(g), pos);

	for(int n = 0; n < d->groups.count(); ++n)
	{
		// not in the same position as before?
		if(d->groups[n]->id != old[n])
		{
			QMetaObject::invokeMethod(this, "notify_rosterGroupChanged", Qt::QueuedConnection,
									  Q_ARG(int, old[n]), Q_ARG(QVariantMap, rosterGroupGetProps(old[n])));
		}
	}
}

QVariantMap LfpApi::rosterGroupGetProps(int group_id)
{
	//printf("  rosterGroupGetProps: [%d]\n", group_id);
	QVariantMap ret;

	Group *g = d->findGroup(group_id);
	if(!g)
		return ret;
	ret["type"] = g->type;
	ret["name"] = g->name;
	ret["pos"] = d->groups.indexOf(g);
	return ret;
}

int LfpApi::rosterContactAdd(int group_id, const QString &name, int pos)
{
	if (name.isEmpty())
		return -1;
	
	Group *g = d->findGroup(group_id);
	if(!g)
		return -1;
	
	Contact *c;
	
	// No duplicates, please
	c = d->findContact(name, g->name);
	if (c) {
		if (!c->groups.contains(g))
			rosterContactAddGroup(c->id, group_id);
		return c->id;
	}
	
	
	c = new Contact;
	c->id = id_contact++;
	c->name = name;
	if(pos == -1)
		g->contacts += c;
	else
		g->contacts.insert(pos, c);
	c->groups += g;
	
	d->registerContact(c);
	
	QMetaObject::invokeMethod(this, "notify_rosterContactAdded", Qt::QueuedConnection,
							  Q_ARG(int, g->id), Q_ARG(int, c->id), Q_ARG(QVariantMap, rosterContactGetProps(c->id)));
	return c->id;
}

void LfpApi::rosterContactRemove(int contact_id)
{
	Contact *c = d->findContact(contact_id);
	if(!c)
		return;
	
	foreach (ContactEntry *e, c->entries)
		rosterEntryRemove(e->id);
	foreach (Group *g, c->groups)
		g->contacts.removeAll(c);
	
	d->unregisterContact(c);
	delete c;

	QMetaObject::invokeMethod(this, "notify_rosterContactRemoved", Qt::QueuedConnection,
							  Q_ARG(int, contact_id));
}

void LfpApi::rosterContactRename(int contact_id, const QString &name)
{
	if (name.isEmpty())
		return;
	
	Contact *c = d->findContact(contact_id);
	if(!c)
		return;
	c->name = name;
	
	// commit changes (rename every contact entry)
	foreach (ContactEntry *ce, c->entries) {
		ce->name = name;
		
		JT_Roster *r = new JT_Roster(ce->account->client()->rootTask());
		r->set(ce->jid, ce->name, ce->groups);
		r->go(true);
	}
	
	QMetaObject::invokeMethod(this, "notify_rosterContactChanged", Qt::QueuedConnection,
							  Q_ARG(int, contact_id), Q_ARG(QVariantMap, rosterContactGetProps(contact_id)));
}

void LfpApi::rosterContactSetAlt(int contact_id, const QString &name)
{
	Contact *c = d->findContact(contact_id);
	if(!c)
		return;
	c->alt = name;

	QMetaObject::invokeMethod(this, "notify_rosterContactChanged", Qt::QueuedConnection,
							  Q_ARG(int, contact_id), Q_ARG(QVariantMap, rosterContactGetProps(contact_id)));
}

void LfpApi::rosterContactMove(int contact_id, int pos)
{
	Contact *c = d->findContact(contact_id);
	if(!c)
		return;
	Group *g = c->groups[0]; // TODO: later
	QList<int> old;
	for(int n = 0; n < g->contacts.count(); ++n)
		old += g->contacts[n]->id;
	g->contacts.move(g->contacts.indexOf(c), pos);

	for(int n = 0; n < g->contacts.count(); ++n)
	{
		// not in the same position as before?
		if(g->contacts[n]->id != old[n])
		{
			QMetaObject::invokeMethod(this, "notify_rosterContactChanged", Qt::QueuedConnection,
									  Q_ARG(int, old[n]), Q_ARG(QVariantMap, rosterContactGetProps(old[n])));
		}
	}

	// TODO: later, commit to server if changing groups (commit all entries)
	// note: you can't change groups with this function so i don't know what i'm saying here.
}

void LfpApi::rosterContactAddGroup(int contact_id, int group_id)
{
	Contact *c = d->findContact(contact_id);
	if(!c)
		return;
	
	Group *g = d->findGroup(group_id);
	if(!g || g->type != "User")
		return;
	
	if (!c->groups.contains(g)) {
		c->groups += g;
		g->contacts += c;
		
		// commit changes (add every contact entry)
		foreach (ContactEntry *ce, c->entries) {
			ce->groups += g->name;
			if (ce->mainGroup.isEmpty())
				ce->mainGroup = g->name;
			
			JT_Roster *r = new JT_Roster(ce->account->client()->rootTask());
			r->set(ce->jid, ce->name, ce->groups);
			r->go(true);
		}
		
		QMetaObject::invokeMethod(this, "notify_rosterContactGroupAdded", Qt::QueuedConnection,
								  Q_ARG(int, contact_id), Q_ARG(int, group_id));
	}
}

void LfpApi::rosterContactChangeGroup(int contact_id, int group_old_id, int group_new_id)
{
	Contact *c = d->findContact(contact_id);
	if(!c)
		return;
	Group *g = c->groups[0];
	if(group_old_id != g->id)
		return;
	
	Group *new_g = d->findGroup(group_new_id);
	if(!new_g)
		return;
	
	// don't allow transfer to/from the NotInList group
	if(g->type == "NotInList" || new_g->type == "NotInList")
		return;
	
	c->groups.removeAll(g);
	c->groups += new_g;
	g->contacts.removeAll(c);
	new_g->contacts += c;
	
	// commit groupchange to server (commit all entries)
	for(int n = 0; n < c->entries.count(); ++n)
	{
		ContactEntry *ce = c->entries[n];
		if(g->type == "User") {
			ce->groups.removeAll(g->name);
			if (ce->mainGroup == g->name)
				ce->mainGroup = "";
		}
		if (new_g->type == "User") {
			ce->groups.append(new_g->name);
			if (ce->mainGroup.isEmpty())
				ce->mainGroup = new_g->name;
		}
		
		JT_Roster *r = new JT_Roster(ce->account->client()->rootTask());
		r->set(ce->jid, ce->name, ce->groups);
		r->go(true);
	}
	
	QMetaObject::invokeMethod(this, "notify_rosterContactGroupChanged", Qt::QueuedConnection,
							  Q_ARG(int, contact_id), Q_ARG(int, group_old_id), Q_ARG(int, group_new_id));
}

void LfpApi::rosterContactRemoveGroup(int contact_id, int group_id)
{
	Contact *c = d->findContact(contact_id);
	Group *g = d->findGroup(group_id);
	if(!c)
		return;
	if(!g)
		return;
	if(!c->groups.contains(g))
		return;
	
	// don't allow removal from the NotInList group
	if(g->type == "NotInList")
		return;
	
	c->groups.removeAll(g);
	g->contacts.removeAll(c);
	
	// commit groupchange to server (commit all entries)
	foreach (ContactEntry *ce, c->entries) {
		if(g->type == "User") {
			ce->groups.removeAll(g->name);
			if (ce->mainGroup == g->name)
				ce->mainGroup = "";
		}
		
		JT_Roster *r = new JT_Roster(ce->account->client()->rootTask());
		r->set(ce->jid, ce->name, ce->groups);
		r->go(true);
	}
	
	// Added to the "No Groups" group if there are no groups left
	if (c->groups.isEmpty()) {
		Group *noGroupsGroup = d->findGroup("NoGroup", "General");
		
		c->groups += noGroupsGroup;
		noGroupsGroup->contacts += c;
		
		QMetaObject::invokeMethod(this, "notify_rosterContactGroupChanged", Qt::QueuedConnection,
								  Q_ARG(int, contact_id), Q_ARG(int, group_id), Q_ARG(int, noGroupsGroup->id));
	}
	else {
		QMetaObject::invokeMethod(this, "notify_rosterContactGroupRemoved", Qt::QueuedConnection,
								  Q_ARG(int, contact_id), Q_ARG(int, group_id));
	}
}

QVariantMap LfpApi::rosterContactGetProps(int contact_id)
{
	QVariantMap ret;

	Contact *c = d->findContact(contact_id);
	if(!c)
		return ret;
	Group *g = c->groups[0];
	ret["name"] = c->name;
	ret["altName"] = c->alt;
	ret["pos"] = g->contacts.indexOf(c);
	return ret;
}

int LfpApi::rosterEntryAdd(int contact_id, const QString &accountUUID, const QString &address, const QString &myNick, const QString &reason, int pos)
{
	Account *account = d->accountsByUUID[accountUUID];
	
	if (address.isEmpty())
		return -1;
	
	Contact *c = d->findContact(contact_id);
	if(!c)
		return -1;
	
	ContactEntry *e;
	
	// No duplicates, please
	e = d->findEntry(account, address, false);
	
	if (e) {
		if (e->contact != c) {
			bool needsSubscription = !(e->contact->inList());
			int oldContactID = e->contact->id;
			
			rosterEntryChangeContact(e->id, oldContactID, contact_id);
			rosterContactRemove(oldContactID);
			
			if (needsSubscription) {
				e->account->client()->sendSubscription(e->jid, "subscribe", myNick, reason);
			}
		}
	}
	else  {
		e = new ContactEntry;
		e->id = id_entry++;
		e->account = d->accountsByUUID[accountUUID];
		e->jid = address;
		e->name = c->name;
		e->sub = "none";
		e->ask = false;
		e->groups = QStringList();
		
		d->registerEntry(e);
		
		// FIXME: warning, another assumption about only having one group
		if(c->groups[0]->type == "User")
			e->groups += c->groups[0]->name;
		
		e->mainGroup = e->groups.isEmpty() ? QString() : e->groups[0];
		
		if(pos == -1)
			c->entries += e;
		else
			c->entries.insert(pos, e);
		e->contact = c;
		
		if(c->inList())
		{
			// commit to server and request subscription
			JT_Roster *r = new JT_Roster(e->account->client()->rootTask());
			r->set(e->jid, e->name, e->groups);
			r->go(true);
			account->client()->sendSubscription(e->jid, "subscribe", myNick, reason);
		}
		
		QMetaObject::invokeMethod(this, "notify_rosterEntryAdded", Qt::QueuedConnection,
								  Q_ARG(int, c->id), Q_ARG(int, e->id), Q_ARG(QVariantMap, rosterEntryGetProps(e->id)));
	}
	
	return e->id;
}

void LfpApi::rosterEntryRemove(int entry_id)
{
	ContactEntry *e = d->findEntry(entry_id);
	if(!e)
		return;

	Jid jid = e->jid;
	Contact *c = e->contact;
	c->entries.removeAll(e);
	d->unregisterEntry(e);
	delete e;
	
	if(c->inList() && e->account->client()->isActive())
	{
		// commit to server
		JT_Roster *r = new JT_Roster(e->account->client()->rootTask());
		r->remove(jid);
		r->go(true);
	}

	QMetaObject::invokeMethod(this, "notify_rosterEntryRemoved", Qt::QueuedConnection,
							  Q_ARG(int, entry_id));
}

void LfpApi::rosterEntryMove(int entry_id, int contact_id, int pos)
{
	Contact *c = d->findContact(contact_id);
	if(!c)
		return;

	ContactEntry *e = d->findEntry(entry_id);
	if(!e)
		return;

	// moving to another contact?
	if(e->contact != c)
	{
		e->contact->entries.removeAll(e);
		e->contact = c;
		if(pos == -1)
			e->contact->entries += e;
		else
			e->contact->entries.insert(pos, e);

		// TODO: ### commit to server if changing groups (commit entry)
		// TODO: don't forget about inList handling
		/*JT_Roster *r = new JT_Roster(client->rootTask());
		r->set(jid, name, groups);
		r->go(true);*/
	}
	else
	{
		if(pos != -1)
			c->entries.move(c->entries.indexOf(e), pos);
	}

	QMetaObject::invokeMethod(this, "notify_rosterEntryChanged", Qt::QueuedConnection,
							  Q_ARG(int, entry_id), Q_ARG(QVariantMap, rosterEntryGetProps(entry_id)));
}

void LfpApi::rosterEntryChangeContact(int entry_id, int contact_old_id, int contact_new_id)
{
	ContactEntry *e = d->findEntry(entry_id);
	if (!e) return;
	Contact *old_c = d->findContact(contact_old_id);
	if (!old_c) return;
	Contact *new_c = d->findContact(contact_new_id);
	if (!new_c) return;
	
	if (e->contact != old_c) return;
	
	old_c->entries.removeAll(e);
	new_c->entries += e;
	
	e->contact = new_c;
	e->name = new_c->name;
	e->groups = QStringList();
	
	foreach (Group *g, new_c->groups) {
		if (g->type == "User")
			e->groups += g->name;
	}
	e->mainGroup = (e->groups.isEmpty() ? QString() : e->groups[0]);
	
	// commit changes to server
	JT_Roster *r = new JT_Roster(e->account->client()->rootTask());
	r->set(e->jid, e->name, e->groups);
	r->go(true);
	
	QMetaObject::invokeMethod(this, "notify_rosterEntryContactChanged", Qt::QueuedConnection,
							  Q_ARG(int, entry_id), Q_ARG(int, contact_old_id), Q_ARG(int, contact_new_id));
}

QVariantMap LfpApi::rosterEntryGetProps(int entry_id)
{
	QVariantMap ret;

	ContactEntry *e = d->findEntry(entry_id);
	if(!e)
		return ret;
	Contact *c = e->contact;
	ret["accountUUID"] = e->account->uuid();
	ret["address"] = e->jid;
	ret["pos"] = c->entries.indexOf(e);
	ret["sub"] = e->sub;
	ret["ask"] = e->ask;
	return ret;
}

QString LfpApi::rosterEntryGetFirstAvailableResource(int entry_id)
{
	ContactEntry *e = d->findEntry(entry_id);
	if (e) {
		Client *client = e->account->client();
		
		if (client->isActive()) {
			const LiveRoster &r = client->roster();
			LiveRoster::ConstIterator roster_it = r.find(Jid(e->jid), false);
			if ((roster_it != r.constEnd()) && !((*roster_it).resourceList().isEmpty())) {
				return (*((*roster_it).priority())).name();
			}
		}
	}
	
	return QString();
}

QString LfpApi::rosterEntryGetResourceWithCapsFeature(int entry_id, const QString &feature)
{
	QString result = QString();
	
	ContactEntry *e = d->findEntry(entry_id);
	if (e) {
		const LiveRoster &r = e->account->client()->roster();
		LiveRoster::ConstIterator roster_it = r.find(Jid(e->jid), false);
		
		if ((roster_it != r.constEnd()) && !(roster_it->resourceList().isEmpty())) {
			// Iterate on the resources for this entry
			const ResourceList &resource_list = roster_it->resourceList();
			
			for (ResourceList::ConstIterator resource_it = resource_list.constBegin();
				 resource_it != resource_list.constEnd();
				 ++resource_it)
			{
				const QString &resourceName = resource_it->name();
				
				Jid fullJid = Jid(e->jid).withResource(resourceName);
				QStringList features = e->account->capsManager()->features(fullJid).list();
				
				if (features.contains(feature)) {
					result = resourceName;
					break;
				}
			}
		}
	}
	
	return result;
}

bool LfpApi::rosterEntryResourceHasCapsFeature(int entry_id, const QString &resource, const QString &feature)
{
	ContactEntry *e = d->findEntry(entry_id);
	if (e) {
		Jid fullJid = Jid(e->jid).withResource(resource);
		QStringList features = e->account->capsManager()->features(fullJid).list();
		
		return features.contains(feature);
	}
	else {
		return false;
	}
}

QVariantList LfpApi::rosterEntryGetResourceList(int entry_id)
{
	ContactEntry *e = d->findEntry(entry_id);
	if (e) {
		Client *client = e->account->client();
		
		if (client->isActive()) {
			const LiveRoster			&r = client->roster();
			LiveRoster::ConstIterator	roster_it = r.find(Jid(e->jid), false);
			
			if (roster_it != r.constEnd()) {
				const ResourceList	&res_list = (*roster_it).resourceList();
				QVariantList		resulting_resources_list;
				
				foreach (Resource res, res_list) {
					resulting_resources_list << QVariant(res.name());
				}
				return resulting_resources_list;
			}
		}
	}
	
	return QVariantList();
}

QVariantList LfpApi::rosterEntryGetResourceCapsFeatures(int entry_id, const QString & resource)
{
	QVariantMap resultingMap;
	
	ContactEntry *e = d->findEntry(entry_id);
	if (e) {
		Jid				fullJid = Jid(e->jid).withResource(resource);
		QVariantList	capsFeaturesList;
		
		foreach (QString feature, e->account->capsManager()->features(fullJid).list())
			capsFeaturesList += QVariant(feature);
		
		return capsFeaturesList;
	}
	
	return QVariantList();
}

QVariantMap LfpApi::rosterEntryGetResourceProps(int entry_id, const QString &resource)
{
	// ret: { ShowMode show, string status, string last_updated, string capabilities }
	QVariantMap resultingMap;
	
	ContactEntry *e = d->findEntry(entry_id);
	if (e) {
		Jid							fullJid = Jid(e->jid).withResource(resource);
		const LiveRoster			&r = e->account->client()->roster();
		LiveRoster::ConstIterator	roster_it = r.find(fullJid, false);
		
		if (roster_it != r.constEnd()) {
			// find the correct resource
			const ResourceList				&res_list = (*roster_it).resourceList();
			ResourceList::ConstIterator		resource_iter;
			for (resource_iter = res_list.constBegin(); resource_iter != res_list.constEnd(); ++resource_iter) {
				if (resource_iter->name() == resource) break;
			}
			
			if (resource_iter != res_list.constEnd()) {
				const Status &status = resource_iter->status();
				
				QString xmpp_show = status.show();
				QString show = "Online";
				
				if (status.isInvisible())
					show = "Invisible";
				else if(xmpp_show == "away")
					show = "Away";
				else if(xmpp_show == "xa")
					show = "ExtendedAway";
				else if(xmpp_show == "dnd")
					show = "DoNotDisturb";
				
				
				resultingMap["show"]			= show;
				resultingMap["status"]			= status.status();
				resultingMap["last_updated"]	= status.timeStamp().toString(Qt::LocalDate);
				resultingMap["capabilities"]	= e->account->capsManager()->features(fullJid).list().join(" ");
			}
		}
	}
	
	return resultingMap;
}

void LfpApi::rosterEntryResourceClientInfoGet(int entry_id, const QString &resource)
{
	ContactEntry *entry = d->findEntry(entry_id);
	
	if (entry) {
		JT_ClientVersion *cv_task = new JT_ClientVersion(entry->account->client()->rootTask());
		
		cv_task->get(Jid(entry->jid).withResource(resource));
		connect(cv_task, SIGNAL(finished()), SLOT(clientVersion_finished()));
		cv_task->go(true);
	}
}

void LfpApi::rosterSortGroups(const QString &mode)
{
	// TODO: later
	Q_UNUSED(mode);
}

void LfpApi::rosterSortContacts(const QString &mode)
{
	// TODO: later
	Q_UNUSED(mode);
}

#pragma mark -

void LfpApi::client_rosterItemAdded(const Account *account, const RosterItem &i)
{
	// do we have the contact already?
	ContactEntry *e = d->findEntry(account, i.jid());

	// already in the list?
	if(e && e->contact->inList())
		return;

	QString groupType;
	QString groupName;
	QStringList groups = i.groups();
	if (groups.isEmpty()) {
		groupType = "NoGroup";
		groupName = "General";
	}
	else {
		groupType = "User";
		groupName = groups[0];	// TODO: multiple group support
	}
	
	// find an existing group, else make it
	Group *g = d->findGroup(groupType, groupName);
	if(!g) {
		int gID = rosterGroupAdd(groupName, -1);
		g = d->findGroup(gID);
		// Change the default "User" group type
		g->type = groupType;
	}
	
	// have it, but not in the list?  move it
	if(e && !e->contact->inList())
	{
		Group *g_old = d->findGroup("NotInList", "Not In List");

		Contact *c = e->contact;
		c->groups.removeAll(g_old);
		c->groups += g;
		g_old->contacts.removeAll(c);
		g->contacts += c;

		QMetaObject::invokeMethod(this, "notify_rosterContactGroupChanged", Qt::QueuedConnection,
								  Q_ARG(int, c->id), Q_ARG(int, g_old->id), Q_ARG(int, g->id));

		e->sub = i.subscription().toString();
		e->ask = !i.ask().isEmpty();
		
		// Update the groups of all the entries in the contact
		foreach (ContactEntry *ce, c->entries) {
			ce->groups = i.groups();
			ce->mainGroup = e->groups.isEmpty() ? QString() : ce->groups[0];
			
			QMetaObject::invokeMethod(this, "notify_rosterEntryChanged", Qt::QueuedConnection,
									  Q_ARG(int, ce->id), Q_ARG(QVariantMap, rosterEntryGetProps(ce->id)));
		}
	}
	else {
		// Create a new Contact Entry
		e = new ContactEntry;
		e->id = id_entry++;
		e->account = const_cast<Account*>(account);
		e->jid = i.jid().bare();
		e->name = i.name().isEmpty() ? i.jid().bare() : i.name();
		e->sub = i.subscription().toString();
		e->ask = !i.ask().isEmpty();
		e->groups = i.groups();
		e->mainGroup = e->groups.isEmpty() ? QString() : e->groups[0];
		d->registerEntry(e);
		
		// Multi-contacts stuff: if a contact already exists in the same group and with the same name, use it.
		Contact *c = d->findContact(e->name, g->name, g->type);
		int contact_id;
		
		if (c) {
			contact_id = c->id;
		} else {
			contact_id = rosterContactAdd(g->id, e->name, -1);
			c = d->findContact(contact_id);
		}
		
		c->entries += e;
		e->contact = c;
		
		QMetaObject::invokeMethod(this, "notify_rosterEntryAdded", Qt::QueuedConnection,
								  Q_ARG(int, c->id), Q_ARG(int, e->id), Q_ARG(QVariantMap, rosterEntryGetProps(e->id)));
	}
}

void LfpApi::client_rosterItemUpdated(const Account *account, const RosterItem &i)
{
	ContactEntry *e = d->findEntry(account, i.jid());
	if(!e)
		return;
	
	e->sub = i.subscription().toString();
	e->ask = !i.ask().isEmpty();
	
	
	// Are we changing groups?
	bool		groupChanged = false;
	Group		*gTo = NULL;
	
	if ((e->groups.isEmpty() && !i.groups().isEmpty())						// we were in no group, but now we are in group(s)
		|| (!e->groups.isEmpty() && !i.groups().contains(e->mainGroup)))	// we were in a group that doesn't exist anymore
	{
		QString groupType;
		QString groupName;
		QStringList groups = i.groups();
		
		if (groups.isEmpty()) {
			groupType = "NoGroup";
			groupName = "General";
		}
		else {
			groupType = "User";
			groupName = groups[0];	// TODO: multiple group support
		}
		
		e->mainGroup = groups.isEmpty() ? QString() : groups[0];
		
		groupChanged = true;
		gTo = d->findGroup(groupType, groupName);
		
		if (!gTo) {
			// We need to create the new group
			int gID = rosterGroupAdd(groupName, -1);
			gTo = d->findGroup(gID);
		}
	}
	// the new grouplist won't affect anything
	e->groups = i.groups();
	
	
	// Are we changing contacts?
	Contact *contactFrom = e->contact;
	Contact *contactTo;
	
	if ((!i.name().isEmpty() && e->name != i.name()) || groupChanged) {
		e->name = i.name().isEmpty() ? i.jid().bare() : i.name();
		
		contactTo = d->findContact(e->name, e->mainGroup);
		if (!contactTo) {
			// We need to create the new contact
			int cID = rosterContactAdd((groupChanged ? gTo->id : e->contact->groups[0]->id), e->name, -1);
			contactTo = d->findContact(cID);
		}
		
		if (contactFrom) {
			contactFrom->entries.removeAll(e);
		}
		
		contactTo->entries += e;
		e->contact = contactTo;
		
		QMetaObject::invokeMethod(this, "notify_rosterEntryContactChanged", Qt::QueuedConnection,
								  Q_ARG(int, e->id), Q_ARG(int, contactFrom->id), Q_ARG(int, contactTo->id));
		
		if (contactFrom && contactFrom->entries.isEmpty()) {
			rosterContactRemove(contactFrom->id);
		}		
	}

	QMetaObject::invokeMethod(this, "notify_rosterEntryChanged", Qt::QueuedConnection,
							  Q_ARG(int, e->id), Q_ARG(QVariantMap, rosterEntryGetProps(e->id)));
}

void LfpApi::client_rosterItemRemoved(const Account *account, const RosterItem &i)
{
	ContactEntry *e = d->findEntry(account, i.jid());
	if(!e)
		return;
	
	int entry_id = e->id;
	Contact *c = e->contact;
	c->entries.removeAll(e);
	d->unregisterEntry(e);
	delete e;

	QMetaObject::invokeMethod(this, "notify_rosterEntryRemoved", Qt::QueuedConnection,
							  Q_ARG(int, entry_id));

	// no entries left?  nuke the contact
	if(c->entries.isEmpty()) {
		rosterContactRemove(c->id);
	}
}

void LfpApi::client_resourceAvailable(const Account *account, const Jid &j, const Resource &r)
{
	// Ignore resources with negative priotities
	if (r.priority() >= 0) {
		ContactEntry *e = d->findEntry(account, j, false);
		if(!e)
			return;
		
		const LiveRoster &lr = account->client()->roster();
		LiveRoster::ConstIterator it = lr.find(j.withResource(QString()));
		if(it == lr.end())
			return;
		
		QString xmpp_show = r.status().show();
		QString show = "Online";
		
		if (r.status().isInvisible())
			show = "Invisible";
		else if(xmpp_show == "away")
			show = "Away";
		else if(xmpp_show == "xa")
			show = "ExtendedAway";
		else if(xmpp_show == "dnd")
			show = "DoNotDisturb";
		
		
		QString status = r.status().status();
		
		QMetaObject::invokeMethod(this, "notify_presenceUpdated", Qt::QueuedConnection,
								  Q_ARG(int, e->id), Q_ARG(QString, show), Q_ARG(QString, status));
		
		QMetaObject::invokeMethod(this, "notify_rosterEntryResourceListChanged", Qt::QueuedConnection,
								  Q_ARG(int, e->id), Q_ARG(QVariantList, rosterEntryGetResourceList(e->id)));
		
		QMetaObject::invokeMethod(this, "notify_rosterEntryResourceChanged", Qt::QueuedConnection,
								  Q_ARG(int, e->id), Q_ARG(QString, j.resource()));
		
		if (!r.status().capsNode().isEmpty()) {
			const Jid &jidForCaps = (j.resource().isEmpty() ?
									 j.withResource(r.name()) :
									 j);
			account->capsManager()->updateCaps(jidForCaps, r.status().capsNode(), r.status().capsVersion(), r.status().capsExt());
		}
	}
}

void LfpApi::client_resourceUnavailable(const Account *account, const Jid &j, const Resource &r)
{
	// Ignore resources with negative priotities
	if (r.priority() >= 0) {
		ContactEntry *e = d->findEntry(account, j, false);
		if(!e)
			return;
		
		const LiveRoster &lr = account->client()->roster();
		LiveRoster::ConstIterator it = lr.find(j.withResource(QString()));
		if(it == lr.end())
			return;
		
		QString show;
		QString status;
		
		const ResourceList &resList = it->resourceList();
		
		// Was this the last available resource for this JID?
		if (!it->isAvailable() || (resList.count() == 1 && resList.priority()->name() == r.name())) {
			show = "Offline";
		}
		else {
			ResourceList::ConstIterator highestPriorityRes = it->priority();
			
			// Is the iterator pointing to the resource that is going offline? Skip over to the next one.
			if (highestPriorityRes->name() == r.name())
				++highestPriorityRes;
			
			QString xmpp_show = highestPriorityRes->status().show();
			
			show = "Online";
			
			if (highestPriorityRes->status().isInvisible())
				show = "Invisible";
			else if(xmpp_show == "away")
				show = "Away";
			else if(xmpp_show == "xa")
				show = "ExtendedAway";
			else if(xmpp_show == "dnd")
				show = "DoNotDisturb";
			
			
			status = highestPriorityRes->status().status();
		}
		
		QMetaObject::invokeMethod(this, "notify_presenceUpdated", Qt::QueuedConnection,
								  Q_ARG(int, e->id), Q_ARG(QString, show), Q_ARG(QString, status));
		
		QVariantList resourceList = rosterEntryGetResourceList(e->id);
		resourceList.removeAll(r.name());
		QMetaObject::invokeMethod(this, "notify_rosterEntryResourceListChanged", Qt::QueuedConnection,
								  Q_ARG(int, e->id), Q_ARG(QVariantList, resourceList));
		
		// Only discard capabilities after having taken care of the notifications emitted above.
		// Discarding the capabilities triggers a bridge notification, and the GUI layer should already
		// have been notified about the current presence so that it can act upon the loss of capabilities
		// info more appropriately.
		const Jid &jidForCaps = (j.resource().isEmpty() ?
								 j.withResource(r.name()) :
								 j);
		account->capsManager()->disableCaps(jidForCaps);
	}
}

void LfpApi::client_subscription(const Account *account, const Jid &jid, const QString &type, const QString &nick, const QString &reason)
{
	ContactEntry *e = d->findEntry(account, jid, false);

	// don't have the contact?  make a NotInList entry, then
	if(!e)
	{
		Group *g = d->findGroup("NotInList", "Not In List");
		Contact *c = new Contact;
		c->id = id_contact++;
		c->name = (nick.isEmpty() ? jid.bare() : nick);
		g->contacts += c;
		c->groups += g;
		d->registerContact(c);

		QMetaObject::invokeMethod(this, "notify_rosterContactAdded", Qt::QueuedConnection,
								  Q_ARG(int, g->id), Q_ARG(int, c->id), Q_ARG(QVariantMap, rosterContactGetProps(c->id)));

		e = new ContactEntry;
		e->id = id_entry++;
		e->account = const_cast<Account*>(account);
		e->jid = jid.bare();
		e->name = (nick.isEmpty() ? jid.bare() : nick);
		e->sub = "none";
		e->ask = false;
		e->groups = QStringList();
		e->mainGroup = QString();
		d->registerEntry(e);
		
		c->entries += e;
		e->contact = c;

		QMetaObject::invokeMethod(this, "notify_rosterEntryAdded", Qt::QueuedConnection,
								  Q_ARG(int, c->id), Q_ARG(int, e->id), Q_ARG(QVariantMap, rosterEntryGetProps(e->id)));
	}

	int entry_id = e->id;

	if(type == "subscribe") {
		QMetaObject::invokeMethod(this, "notify_authRequest", Qt::QueuedConnection,
								  Q_ARG(int, entry_id), Q_ARG(QString, nick), Q_ARG(QString, reason));
	}
	else if(type == "subscribed") {
		QMetaObject::invokeMethod(this, "notify_authGranted", Qt::QueuedConnection, Q_ARG(int, entry_id));
	}
	else if(type == "unsubscribed") {
		QMetaObject::invokeMethod(this, "notify_authLost", Qt::QueuedConnection, Q_ARG(int, entry_id));
	}
}


Chat * LfpApi::getChatForJID (const Account *account, const Jid &fromJid)
{
	ContactEntry *e = d->findEntry(account, fromJid, false);
	
	// no suitable entry?  make one
	if(!e)
	{
		Group *g = d->findGroup("NotInList", "Not In List");
		Contact *c = new Contact;
		c->id = id_contact++;
		c->name = fromJid.bare();
		g->contacts += c;
		c->groups += g;
		d->registerContact(c);
		
		QMetaObject::invokeMethod(this, "notify_rosterContactAdded", Qt::QueuedConnection,
								  Q_ARG(int, g->id), Q_ARG(int, c->id), Q_ARG(QVariantMap, rosterContactGetProps(c->id)));
		
		e = new ContactEntry;
		e->id = id_entry++;
		e->account = const_cast<Account*>(account);
		e->jid = fromJid.bare();
		e->name = QString();
		e->sub = "none";
		e->ask = false;
		e->groups = QStringList();
		e->mainGroup = QString();
		d->registerEntry(e);
		
		c->entries += e;
		e->contact = c;
		
		QMetaObject::invokeMethod(this, "notify_rosterEntryAdded", Qt::QueuedConnection,
								  Q_ARG(int, c->id), Q_ARG(int, e->id), Q_ARG(QVariantMap, rosterEntryGetProps(e->id)));
	}
	
	Chat *chat = d->findChat(account, fromJid, false);
	if (!chat)
		chat = d->findChat(e->contact);
	
	// no suitable chat?  make one
	if(!chat)
	{
		chat = new Chat;
		chat->id = id_chat++;
		chat->contact = e->contact;
		chat->entry = e;
		chat->jid = fromJid;
		d->chats += chat;
		
		QMetaObject::invokeMethod(this, "notify_chatIncoming", Qt::QueuedConnection,
								  Q_ARG(int, chat->id), Q_ARG(int, e->contact->id),
								  Q_ARG(int, e->id), Q_ARG(QString, chat->jid.full()));
	}
	else {
		if (chat->entry != e) {
			// Contact JID changed
			chat->entry = e;
			chat->jid = fromJid;
			
			QMetaObject::invokeMethod(this, "notify_chatEntryChanged", Qt::QueuedConnection,
									  Q_ARG(int, chat->id), Q_ARG(int, e->id));
		}
		else if (!(chat->jid.compare(fromJid, true))) {
			// Only the resource changed. The contact entry is the same, no need to notify the GUI layer.
			chat->jid = fromJid;
		}
	}
	
	return chat;
}

void LfpApi::client_messageReceived(const Account *account, const Message &m)
{
	// TODO: ### handle message events
	// notify_chatContactTyping

	// else, treat as message

	// no body? (but this could be a topic change for a group chat)
	if(m.body().isEmpty() && m.urlList().isEmpty() && m.subject().isEmpty() && m.mucInvites().isEmpty() && m.type() != "groupchat")
		return;
	
	bool processAsRegularChatMessage = false;
	
	if (m.isSapoSMS()) {
		// sapo:sms
		const QVariantMap & props = m.sapoSMSProperties();
		
		if (props.contains("received")) {
			QMetaObject::invokeMethod(this, "notify_smsReceived", Qt::QueuedConnection,
									  Q_ARG(QString, account->uuid()),
									  Q_ARG(QString, props["received"].toString()),
									  Q_ARG(QString, m.from().bare()),
									  Q_ARG(QString, props["body"].toString()),
									  Q_ARG(int, ( props.contains("credit") ? props["credit"].toInt() : -1)),
									  Q_ARG(int, ( props.contains("free") ? props["free"].toInt() : -1)),
									  Q_ARG(int, ( props.contains("monthsms") ? props["monthsms"].toInt() : -1)));
		}
		else if (props.contains("result")) {
			QMetaObject::invokeMethod(this, "notify_smsSent", Qt::QueuedConnection,
									  Q_ARG(QString, account->uuid()),
									  Q_ARG(int, props["result"].toInt()),
									  Q_ARG(int, props["totalsms"].toInt()),
									  Q_ARG(int, props["totalchars"].toInt()),
									  Q_ARG(QString, m.from().bare()),
									  Q_ARG(QString, props["body"].toString()),
									  Q_ARG(int, ( props.contains("credit") ? props["credit"].toInt() : -1)),
									  Q_ARG(int, ( props.contains("free") ? props["free"].toInt() : -1)),
									  Q_ARG(int, ( props.contains("monthsms") ? props["monthsms"].toInt() : -1)));
		}
		else {
			processAsRegularChatMessage = true;
		}
	}
	else if (m.type() == "headline") {
		
		if (m.isSapoAudible()) {
			// sapo:audible
			const QString & audibleResourceName = m.sapoAudibleResource();
			Chat *chat = getChatForJID(account, m.from());
			
			if (chat) {
				QMetaObject::invokeMethod(this, "notify_chatAudibleReceived", Qt::QueuedConnection,
										  Q_ARG(int, chat->id), Q_ARG(QString, audibleResourceName),
										  Q_ARG(QString, m.body()),
										  Q_ARG(QString, m.containsHTML() ? m.html().toString() : QString()));
			}
		}
		else {
			// Change the "default" to true. We don't process it as a regular message only if at least
			// one headline can be processed successfully.
			processAsRegularChatMessage = true;
			
			foreach (PubSubItem item, m.pubsubItems()) {
				const QDomElement &notifyElement = item.payload();
				
				if (notifyElement.namespaceURI() == "http://messenger.sapo.pt/protocol/notifications") {
					
					QDomElement	channel_elem	= notifyElement.firstChildElement("channel");
					QDomElement	item_url_elem	= notifyElement.firstChildElement("item_url");
					QDomElement	flash_url_elem	= notifyElement.firstChildElement("flash_url");
					QDomElement	icon_url_elem	= notifyElement.firstChildElement("icon_url");
					
					QString channel		= (channel_elem.isNull()   ? "" : channel_elem.text());
					QString item_url	= (item_url_elem.isNull()  ? "" : item_url_elem.text());
					QString flash_url	= (flash_url_elem.isNull() ? "" : flash_url_elem.text());
					QString icon_url	= (icon_url_elem.isNull()  ? "" : icon_url_elem.text());
					
					// ### TODO: also process the payload specific to each namespace (<payload> XML item).
					
					QString xhtml; // Not used yet
					
					QMetaObject::invokeMethod(this, "notify_headlineNotificationMessageReceived", Qt::QueuedConnection,
											  Q_ARG(QString, account->uuid()),
											  Q_ARG(QString, channel), Q_ARG(QString, item_url),
											  Q_ARG(QString, flash_url), Q_ARG(QString, icon_url),
											  Q_ARG(QString, m.nick()), Q_ARG(QString, m.subject()),
											  Q_ARG(QString, m.body()), Q_ARG(QString, xhtml)); 
					
					processAsRegularChatMessage = false;
				}
			}
		}
	}
	else if (m.type() == "groupchat") {
		GroupChat *gc = d->findGroupChat(account, m.from());
		if (gc)
			processGroupChatMessage(gc, m);
		else
			processAsRegularChatMessage = true;
	}
	else if (m.type() == "error" && d->findGroupChat(account, m.from()) != NULL) {
		// It's an error associated with a group chat of ours
		client_groupChatError(account, m.from(), m.error().code(), m.error().text);
	}
	else if (!m.mucInvites().isEmpty()) {
		QMetaObject::invokeMethod(this, "notify_groupChatInvitationReceived", Qt::QueuedConnection,
								  Q_ARG(QString, account->uuid()),
								  // room jid
								  Q_ARG(QString, m.from().full()),
								  // sender of the invitation
								  Q_ARG(QString, m.mucInvites().first().from().full()),
								  Q_ARG(QString, m.mucInvites().first().reason()),
								  Q_ARG(QString, m.mucPassword()));
	}
	else {
		processAsRegularChatMessage = true;
	}
	
	if (processAsRegularChatMessage) {
		QString xhtml; // Not used yet
		
		// Build the QVariantList containing all the URLs
		QVariantList urlsVList;
		foreach (Url url, m.urlList())
			urlsVList += QVariant(url.url());
		
		if (m.spooled()) {
			// Delayed/Offline message
			QMetaObject::invokeMethod(this, "notify_offlineMessageReceived", Qt::QueuedConnection,
									  Q_ARG(QString, account->uuid()),
									  Q_ARG(QString, m.timeStamp().toString()),
									  Q_ARG(QString, m.from().bare()),
									  Q_ARG(QString, m.nick()), Q_ARG(QString, m.subject()),
									  Q_ARG(QString, m.body()), Q_ARG(QString, xhtml),
									  Q_ARG(QVariantList, urlsVList));
		}
		else {
			// Regular chat message
			Chat *chat = getChatForJID(account, m.from());
			
			if (chat) {
				if (m.type() == "error") {
					QMetaObject::invokeMethod(this, "notify_chatError", Qt::QueuedConnection,
											  Q_ARG(int, chat->id), Q_ARG(QString, m.error().text));
				}
				else {
					QMetaObject::invokeMethod(this, "notify_chatMessageReceived", Qt::QueuedConnection,
											  Q_ARG(int, chat->id),
											  Q_ARG(QString, m.nick()), Q_ARG(QString, m.subject()),
											  Q_ARG(QString, m.body()), Q_ARG(QString, xhtml),
											  Q_ARG(QVariantList, urlsVList));
				}
			}
		}
	}
}

void LfpApi::audible_received(const Account *account, const Jid &from, const QString &audibleResourceName)
{
	Chat *chat = getChatForJID(account, from);
	
	if (chat) {
		QMetaObject::invokeMethod(this, "notify_chatAudibleReceived", Qt::QueuedConnection,
								  Q_ARG(int, chat->id), Q_ARG(QString, audibleResourceName),
								  Q_ARG(QString, QString()), Q_ARG(QString, QString()));
	}
}


void LfpApi::capsManager_capsChanged(const Account *account, const Jid &j)
{
//	if (!logged_in)
//		return;
	
//	QString name = capsManager()->clientName(j);
//	QString version = (name.isEmpty() ? QString() : capsManager()->clientVersion(j));
	
	
	ContactEntry *e = d->findEntry(account, j, FALSE);
	if(e) {
		QMetaObject::invokeMethod(this, "notify_rosterEntryResourceCapabilitiesChanged", Qt::QueuedConnection,
								  Q_ARG(int, e->id), Q_ARG(QString, j.resource()),
								  Q_ARG(QVariantList, rosterEntryGetResourceCapsFeatures(e->id, j.resource())));
	}
	
	//	printf("#*#*#*#*# CAPS CHANGED: JID = %s ; features: \"%s\"\n", qPrintable(j.full()), qPrintable(capsManager()->features(j).list().join(" ")));
	
	//		foreach (UserListItem *u, findRelevant(j)) {
	//			UserResourceList::Iterator rit = u->userResourceList().find(j.resource());
	//			bool found = (rit == u->userResourceList().end()) ? false : true;
	//			
	//			if(!found)
	//				continue;
	//			
	//			(*rit).setClient(name, version, "");
	//		}
}

void LfpApi::avatarFactory_avatarChanged(const Account *account, const Jid &jid)
{
	ContactEntry *entry = d->findEntry(account, jid, false);
	
	if (entry) {
		AvatarFactory	*avatarFactory = account->avatarFactory();
		QPixmap			avatarPixmap = avatarFactory->getAvatar(jid);
		
		// Make a QByteArray out of it
		QByteArray		avatarData;
		QBuffer			buffer(&avatarData);
		
		buffer.open(QIODevice::WriteOnly);
		avatarPixmap.save(&buffer, "PNG");
		
		QMetaObject::invokeMethod(this, "notify_avatarChanged", Qt::QueuedConnection,
								  Q_ARG(int, entry->id), Q_ARG(QString, "PNG"), Q_ARG(QByteArray, avatarData));
	}
}

void LfpApi::avatarFactory_selfAvatarChanged(const Account *account, const QByteArray &avatarData)
{
	QMetaObject::invokeMethod(this, "notify_selfAvatarChanged", Qt::QueuedConnection,
							  Q_ARG(QString, account->uuid()),
							  Q_ARG(QString, "PNG"), Q_ARG(QByteArray, avatarData));
}

void LfpApi::vCardFactory_selfVCardChanged(const Account *account, const VCard &myVCard)
{
	QMetaObject::invokeMethod(this, "notify_selfVCardChanged", Qt::QueuedConnection,
							  Q_ARG(QString, account->uuid()), Q_ARG(QVariantMap, vcardToInfoMap(myVCard)));
}

void LfpApi::clientVersion_finished()
{
	JT_ClientVersion *cv_task = (JT_ClientVersion *)sender();
	
	if (cv_task->success()) {
		ContactEntry *entry = d->findEntry(d->findAccount(cv_task->client()), cv_task->jid(), false);
		
		if (entry)
			QMetaObject::invokeMethod(this, "notify_rosterEntryResourceClientInfoReceived", Qt::QueuedConnection,
									  Q_ARG(int, entry->id), Q_ARG(QString, cv_task->jid().resource()),
									  Q_ARG(QString, cv_task->name()), Q_ARG(QString, cv_task->version()), Q_ARG(QString, cv_task->os()));
	}
}

void LfpApi::smsCreditManager_updated(const Account *account, const QVariantMap &creditProps)
{
	QMetaObject::invokeMethod(this, "notify_smsCreditUpdated", Qt::QueuedConnection,
							  Q_ARG(QString, account->uuid()),
							  Q_ARG(int, ( creditProps.contains("credit") ? creditProps["credit"].toInt() : -1)),
							  Q_ARG(int, ( creditProps.contains("free") ? creditProps["free"].toInt() : -1)),
							  Q_ARG(int, ( creditProps.contains("monthsms") ? creditProps["monthsms"].toInt() : -1)));
}

int LfpApi::addNewFileTransfer(const Account *account, FileTransfer *ft)
{
	// Create and initialize the actual file transfer handler
	FileTransferHandler *fth;
	
	if (ft)	fth = new FileTransferHandler(account->client()->fileTransferManager(), ft, _dataTransferProxy);
	else    fth = new FileTransferHandler(account->client()->fileTransferManager());
	
	connect(fth, SIGNAL(accepted()),						SLOT(fileTransferHandler_accepted()));
	connect(fth, SIGNAL(statusMessage(const QString &)),	SLOT(fileTransferHandler_statusMessage(const QString &)));
	connect(fth, SIGNAL(connected()),						SLOT(fileTransferHandler_connected()));
	connect(fth, SIGNAL(progress(int, qlonglong)),			SLOT(fileTransferHandler_progress(int, qlonglong)));
	connect(fth, SIGNAL(error(int, int, const QString &)),	SLOT(fileTransferHandler_error(int, int, const QString &)));
	
	// Create a timer for spacing out progress update notifications further apart than the interval
	// at which they are received from the file transfer handler
	QTimer *progressTimer = new QTimer;
	
	connect(progressTimer, SIGNAL(timeout()), SLOT(fileTransferTimer_updateProgress()));
	
	// Create and store our file transfer info with its ID for the bridge API
	FileTransferInfo *fti = new FileTransferInfo;
	
	fti->id = id_fileTransfer++;
	fti->fileTransferHandler = fth;
	fti->account = const_cast<Account*>(account);
	fti->progressTimer = progressTimer;
	fti->totalBytesSentOnLastNotification = 0;
	fti->currentTotalBytesSent = 0;
	
	d->file_transfers += fti;
	
	return fti->id;
}

void LfpApi::cleanupFileTransferInfo(FileTransferInfo *fti)
{
	delete fti->fileTransferHandler;
	fti->fileTransferHandler = 0;
	delete fti->progressTimer;
	fti->progressTimer = 0;
	
	// Leave the file transfer info structure alone for now. It doesn't take too much space and this way it can
	// still be used to inspect its properties later.
}

void LfpApi::fileTransferMgr_incomingFileTransfer(const Account *account, FileTransfer *ft)
{
	if(ft) {
		int newFileTransferID = addNewFileTransfer(account, ft);
		QMetaObject::invokeMethod(this, "notify_fileIncoming", Qt::QueuedConnection, Q_ARG(int, newFileTransferID));
	}
}

void LfpApi::fileTransferHandler_accepted()
{
	FileTransferHandler *fth = (FileTransferHandler *)(sender());
	FileTransferInfo *fti = d->findFileTransferInfo(fth);
	
	if (fti) {
		QMetaObject::invokeMethod(this, "notify_fileAccepted", Qt::QueuedConnection, Q_ARG(int, fti->id));
	}
}

void LfpApi::fileTransferHandler_statusMessage(const QString &s)
{
#warning Can we use this signal for anything useful in leapfrog?
	Q_UNUSED(s);
}

void LfpApi::fileTransferHandler_connected()
{
#warning Can we use this signal for anything useful in leapfrog?
	
}

void LfpApi::fileTransferHandler_progress(int p, qlonglong currentTotalSent)
{
	// printf("+-+-+-+-+-+-+-+ file transfer progress: p -> %d , sent -> %lld\n", p, sent);
	Q_UNUSED(p);
	
	FileTransferHandler *fth = (FileTransferHandler *)sender();
	FileTransferInfo *fti = d->findFileTransferInfo(fth);
	
	if (fti) {
		fti->currentTotalBytesSent = currentTotalSent;
		
		if (!(fti->progressTimer->isActive())) {
			// Emit a maximum of 10 notifications per second through the bridge
			fti->progressTimer->start(100);
		}
	}
}

void LfpApi::fileTransferTimer_updateProgress()
{
	QTimer *progressTimer = (QTimer *)sender();
	FileTransferInfo *fti = d->findFileTransferInfo(progressTimer);
	FileTransferHandler *fth = fti->fileTransferHandler;
	
	if (fti) {
		QMetaObject::invokeMethod(this, "notify_fileProgress", Qt::QueuedConnection,
								  Q_ARG(int, fti->id), /* status: take care of this later */ Q_ARG(QString, QString()),
								  Q_ARG(qlonglong, fti->currentTotalBytesSent - fti->totalBytesSentOnLastNotification),
								  Q_ARG(qlonglong, fti->currentTotalBytesSent),
								  Q_ARG(qlonglong, fth->fileSize()));
		
		fti->totalBytesSentOnLastNotification = fti->currentTotalBytesSent;
		
		if (fti->currentTotalBytesSent == fth->fileSize()) {
			QMetaObject::invokeMethod(this, "notify_fileFinished", Qt::QueuedConnection, Q_ARG(int, fti->id));
			cleanupFileTransferInfo(fti);
		}
	}
}

void LfpApi::fileTransferHandler_error(int major_error_type, int minor_error_type, const QString &s)
{
	Q_UNUSED(major_error_type);
	Q_UNUSED(minor_error_type);
	
	FileTransferHandler *fth = (FileTransferHandler *)(sender());
	FileTransferInfo *fti = d->findFileTransferInfo(fth);
	
	if (fti) {
		QMetaObject::invokeMethod(this, "notify_fileError", Qt::QueuedConnection,
								  Q_ARG(int, fti->id), Q_ARG(QString, s));
		cleanupFileTransferInfo(fti);
	}
}


GroupChat *LfpApi::addNewGroupChat(const Account *account, const Jid &room_jid, const QString &nickname, bool request_history)
{
	GroupChat *gc = new GroupChat;
	gc->id = id_groupChat++;
	gc->account = const_cast<Account*>(account);
	gc->room_jid = Jid(room_jid.bare());
	gc->nickname = nickname;
	gc->req_hist_on_join = request_history;
	gc->joined = false;
	
	gc->mucManager = new MUCManager(account->client(), gc->room_jid);
	
	connect(gc->mucManager, SIGNAL(getConfiguration_success(const XData&)),			SLOT(getGCConfiguration_success(const XData&)));
	connect(gc->mucManager, SIGNAL(getConfiguration_error(int, const QString&)),	SLOT(getGCConfiguration_error(int, const QString&)));
	connect(gc->mucManager, SIGNAL(setConfiguration_success()),						SLOT(setGCConfiguration_success()));
	connect(gc->mucManager, SIGNAL(setConfiguration_error(int, const QString&)),	SLOT(setGCConfiguration_error(int, const QString&)));
	
//	connect(manager_, SIGNAL(getItemsByAffiliation_success(MUCItem::Affiliation, const QList<MUCItem>&)), SLOT(getItemsByAffiliation_success(MUCItem::Affiliation, const QList<MUCItem>&)));
//	connect(manager_, SIGNAL(setItems_success()), SLOT(setItems_success()));
//	connect(manager_, SIGNAL(setItems_error(int, const QString&)), SLOT(setItems_error(int, const QString&)));
//	connect(manager_, SIGNAL(getItemsByAffiliation_error(MUCItem::Affiliation, int, const QString&)), SLOT(getItemsByAffiliation_error(MUCItem::Affiliation, int, const QString&)));
//	connect(manager_, SIGNAL(destroy_success()), SLOT(destroy_success()));
//	connect(manager_, SIGNAL(destroy_error(int, const QString&)), SLOT(destroy_error(int, const QString&)));
//	connect(ui_.pb_destroy, SIGNAL(clicked()), SLOT(destroy()));
	
	
#warning TO DO: CONNECT ACTIONS FROM MUCMANAGER
	//		// Connect signals from MUC manager
	//		connect(d->mucManager,SIGNAL(action_error(MUCManager::Action, int, const QString&)), SLOT(action_error(MUCManager::Action, int, const QString&)));
	
	d->group_chats += gc;
	
	// DEBUG
	//fprintf(stderr, "Created chat room representation on the bridge: %s @ %s\n",
	//		qPrintable(gc->nickname), qPrintable(gc->room_jid.bare()));
	
	return gc;
}

void LfpApi::cleanupAndDeleteGroupChat(GroupChat *gc)
{
	// Cleanup the group-chat contacts
	for (QList<GroupChatContact *>::Iterator it = gc->participants.begin(); it != gc->participants.end(); ++it) {
		GroupChatContact *gcc = *it;
		
		// DEBUG
		//fprintf(stderr, "Destroyed chat room contact on the bridge: %s / %s / %s @ %s\n",
		//		qPrintable(gcc->nickname), qPrintable(gcc->full_jid), qPrintable(gcc->real_jid), qPrintable(gc->room_jid.bare()));
		
		d->unregisterGroupChatContact(gcc);
		delete gcc;
	}
	
	// DEBUG
	//fprintf(stderr, "Destroyed chat room representation on the bridge: %s @ %s\n",
	//		qPrintable(gc->nickname), qPrintable(gc->room_jid.bare()));
	
	delete gc->mucManager;
	
	d->group_chats.removeAll(gc);
	delete gc;
}

void LfpApi::getGCConfiguration_success(const XData& xdata)
{
	GroupChat *gc = d->findGroupChat((MUCManager *)sender());
	if (gc) {
		QDomDocument	domDoc;
		QString			xdata_xml_str;
		QTextStream		ts(&xdata_xml_str);
		
		ts << xdata.toXml(&domDoc, false);
		
		QMetaObject::invokeMethod(this, "notify_groupChatConfigurationFormReceived", Qt::QueuedConnection,
								  Q_ARG(int, gc->id), Q_ARG(QString, xdata_xml_str), Q_ARG(QString, QString()));
	}
}

void LfpApi::getGCConfiguration_error(int, const QString& err_msg)
{
	GroupChat *gc = d->findGroupChat((MUCManager *)sender());
	if (gc)
		QMetaObject::invokeMethod(this, "notify_groupChatConfigurationFormReceived", Qt::QueuedConnection,
								  Q_ARG(int, gc->id), Q_ARG(QString, QString()), Q_ARG(QString, err_msg));
}

void LfpApi::setGCConfiguration_success()
{
	GroupChat *gc = d->findGroupChat((MUCManager *)sender());
	if (gc)
		QMetaObject::invokeMethod(this, "notify_groupChatConfigurationModificationResult", Qt::QueuedConnection,
								  Q_ARG(int, gc->id), Q_ARG(bool, true), Q_ARG(QString, QString()));
}

void LfpApi::setGCConfiguration_error(int, const QString& err_msg)
{
	GroupChat *gc = d->findGroupChat((MUCManager *)sender());
	if (gc)
		QMetaObject::invokeMethod(this, "notify_groupChatConfigurationModificationResult", Qt::QueuedConnection,
								  Q_ARG(int, gc->id), Q_ARG(bool, false), Q_ARG(QString, err_msg));
}

void LfpApi::groupChatLeaveAndCleanup(GroupChat *gc)
{
	if (gc) {
		QString host = gc->room_jid.domain();
		QString room = gc->room_jid.node();
		
		gc->account->client()->groupChatLeave(host, room);
		
		// The following method (slot) invocation effectively triggers all the bridge notifications that are expected
		// when a chat room is being destroyed. Memory structures used by the bridge which are related to this group
		// chat are also cleaned up.
		client_groupChatLeft(gc->account, gc->room_jid);
	}
}

void LfpApi::client_groupChatJoined(const Account *account, const Jid &j)
{
	GroupChat *gc = d->findGroupChat(account, j);
	
	if (!gc) {
		gc = addNewGroupChat(account, j, j.resource());
	}
	
	gc->joined = true;

	QMetaObject::invokeMethod(this, "notify_groupChatJoined", Qt::QueuedConnection,
							  Q_ARG(int, gc->id),
							  Q_ARG(QString, gc->room_jid.bare()), Q_ARG(QString, gc->nickname));
}

void LfpApi::client_groupChatLeft(const Account *account, const Jid &j)
{
	GroupChat *gc = d->findGroupChat(account, j);
	if (gc) {
		QMetaObject::invokeMethod(this, "notify_groupChatLeft", Qt::QueuedConnection, Q_ARG(int, gc->id));
		cleanupAndDeleteGroupChat(gc);
	}
}

void LfpApi::client_groupChatPresence(const Account *account, const Jid &j, const Status &s)
{
	if(s.hasError()) {
		// Forward errors to the appropriate notification method
		QString message = ((s.errorCode() == 409) ? "Please choose a different nickname" : "An error occurred");
		client_groupChatError(account, j, s.errorCode(), message);
		return;
	}
	
	GroupChat *gc = d->findGroupChat(account, j);
	
	if (gc) {
		const QString &nick = j.resource();
	
		if(s.isAvailable()) {
			// Available
			if (s.mucStatus() == 201) {
				QMetaObject::invokeMethod(this, "notify_groupChatCreated", Qt::QueuedConnection, Q_ARG(int, gc->id));
				gc->mucManager->setDefaultConfiguration();
			}
			
			QString role = MUCManager::roleToString(s.mucItem().role());
			QString affiliation = MUCManager::affiliationToString(s.mucItem().affiliation());
			
			GroupChatContact *gcc = d->findGroupChatContact(j);
			if (!gcc) {
				// Contact is joining
				gcc = new GroupChatContact;
				gcc->id = id_groupChatContact++;
				gcc->full_jid = j.full();
				gcc->real_jid = s.mucItem().jid().full();
				gcc->nickname = j.resource();
				gcc->role = role;
				gcc->affiliation = affiliation;
				gcc->status = "";
				gcc->status_msg = "";
				
				if (gcc->nickname == gc->nickname && gc->me == NULL)
					gc->me = gcc;
				
				d->registerGroupChatContact(gcc);
				gc->participants += gcc;
				
				// DEBUG
				//fprintf(stderr, "Created chat room contact on the bridge: %s / %s / %s @ %s\n",
				//		qPrintable(gcc->nickname), qPrintable(gcc->full_jid), qPrintable(gcc->real_jid), qPrintable(gc->room_jid.bare()));
				
				QMetaObject::invokeMethod(this, "notify_groupChatContactJoined", Qt::QueuedConnection,
										  Q_ARG(int, gc->id), Q_ARG(QString, nick), Q_ARG(QString, gcc->real_jid),
										  Q_ARG(QString, gcc->role), Q_ARG(QString, gcc->affiliation));
			}
			else {
				// Status change
				if (role != gcc->role || affiliation != gcc->affiliation) {
					gcc->role = role;
					gcc->affiliation = affiliation;
					QMetaObject::invokeMethod(this, "notify_groupChatContactRoleOrAffiliationChanged", Qt::QueuedConnection,
											  Q_ARG(int, gc->id), Q_ARG(QString, nick),
											  Q_ARG(QString, gcc->role), Q_ARG(QString, gcc->affiliation));
				}
				
				QString xmpp_show = s.show();
				QString status = "Online";
				
				if (s.isInvisible())
					status = "Invisible";
				else if(xmpp_show == "away")
					status = "Away";
				else if(xmpp_show == "xa")
					status = "ExtendedAway";
				else if(xmpp_show == "dnd")
					status = "DoNotDisturb";
				
				if (status != gcc->status || s.status() != gcc->status_msg) {
					gcc->status = status;
					gcc->status_msg = s.status();
					
					QMetaObject::invokeMethod(this, "notify_groupChatContactStatusChanged", Qt::QueuedConnection,
											  Q_ARG(int, gc->id), Q_ARG(QString, nick),
											  Q_ARG(QString, gcc->status), Q_ARG(QString, gcc->status_msg));
				}
			}
		}
		else {
			// Unavailable
			if (s.hasMUCDestroy()) {
				// Room was destroyed
				QMetaObject::invokeMethod(this, "notify_groupChatDestroyed", Qt::QueuedConnection,
										  Q_ARG(int, gc->id), Q_ARG(QString, s.mucDestroy().reason()),
										  Q_ARG(QString, s.mucDestroy().jid().full()));  // alternate room
				groupChatLeaveAndCleanup(gc);
			}
			
			switch (s.mucStatus()) {
				case 301:
					// Ban
					QMetaObject::invokeMethod(this, "notify_groupChatContactBanned", Qt::QueuedConnection,
											  Q_ARG(int, gc->id), Q_ARG(QString, nick),
											  Q_ARG(QString, s.mucItem().actor().full()),
											  Q_ARG(QString, s.mucItem().reason()));
					if (nick == gc->nickname) {
						groupChatLeaveAndCleanup(gc);
					}
					break;
					
				case 303:
					// NIckname changed
					QMetaObject::invokeMethod(this, "notify_groupChatContactNicknameChanged", Qt::QueuedConnection,
											  Q_ARG(int, gc->id), Q_ARG(QString, nick),
											  Q_ARG(QString, s.mucItem().nick()));
					GroupChatContact *gcc = d->findGroupChatContact(j);
					if (gcc) {
						QString new_nick = s.mucItem().nick();
						Jid		new_full_jid = Jid(gcc->full_jid);
						
						new_full_jid.setResource(new_nick);
						
						d->unregisterGroupChatContact(gcc);
						
						gcc->nickname = new_nick;
						gcc->full_jid = new_full_jid.full();
						
						d->registerGroupChatContact(gcc);
					}
					if (nick == gc->nickname)
						gc->nickname = s.mucItem().nick();
					break;
					
				case 307:
					// Kick
					QMetaObject::invokeMethod(this, "notify_groupChatContactKicked", Qt::QueuedConnection,
											  Q_ARG(int, gc->id), Q_ARG(QString, nick),
											  Q_ARG(QString, s.mucItem().actor().full()),
											  Q_ARG(QString, s.mucItem().reason()));
					
					if (nick == gc->nickname) {
						groupChatLeaveAndCleanup(gc);
					}
					break;
					
				case 321:
					// Remove due to affiliation change
					QMetaObject::invokeMethod(this, "notify_groupChatContactRemoved", Qt::QueuedConnection,
											  Q_ARG(int, gc->id), Q_ARG(QString, nick),
											  Q_ARG(QString, "affiliation_change"),
											  Q_ARG(QString, s.mucItem().actor().full()),
											  Q_ARG(QString, s.mucItem().reason()));
					
					if (nick == gc->nickname) {
						groupChatLeaveAndCleanup(gc);
					}
					break;
					
				case 322:
					// Remove due to members only
					QMetaObject::invokeMethod(this, "notify_groupChatContactRemoved", Qt::QueuedConnection,
											  Q_ARG(int, gc->id), Q_ARG(QString, nick),
											  Q_ARG(QString, "members_only"),
											  Q_ARG(QString, s.mucItem().actor().full()),
											  Q_ARG(QString, s.mucItem().reason()));
					
					if (nick == gc->nickname) {
						groupChatLeaveAndCleanup(gc);
					}
					break;
					
				default:
					// Contact leaving
					QMetaObject::invokeMethod(this, "notify_groupChatContactLeft", Qt::QueuedConnection,
											  Q_ARG(int, gc->id), Q_ARG(QString, nick), Q_ARG(QString, s.status()));
			}
			
			// Delete the contact
			GroupChatContact *gcc = d->findGroupChatContact(j);
			if (gcc) {
				gc->participants.removeAll(gcc);
				if (gc->me == gcc)
					gc->me = NULL;
				
				// DEBUG
				//fprintf(stderr, "Destroyed chat room contact on the bridge: %s / %s / %s @ %s\n",
				//		qPrintable(gcc->nickname), qPrintable(gcc->full_jid), qPrintable(gcc->real_jid), qPrintable(gc->room_jid.bare()));
				
				d->unregisterGroupChatContact(gcc);
				delete gcc;
			}
		}
	}

#warning TO DO: GROUP CHAT CONTACT CAPABILITIES!
//	if (!s.capsNode().isEmpty()) {
//		Jid caps_jid(s.mucItem().jid().isEmpty() ? Jid(d->jid).withResource(nick) : s.mucItem().jid());
//		d->pa->capsManager()->updateCaps(caps_jid,s.capsNode(),s.capsVersion(),s.capsExt());
//	}
}

void LfpApi::client_groupChatError(const Account *account, const Jid &j, int code, const QString &str)
{
	GroupChat *gc = d->findGroupChat(account, j);
	if (gc) {
		QMetaObject::invokeMethod(this, "notify_groupChatError", Qt::QueuedConnection,
								  Q_ARG(int, gc->id), Q_ARG(int, code), Q_ARG(QString, str));
	}
}


void LfpApi::processGroupChatMessage(const GroupChat *gc, const Message &m)
{
	QString from_nick = m.from().resource();
	
	if(!m.subject().isEmpty()) {
		QMetaObject::invokeMethod(this, "notify_groupChatTopicChanged", Qt::QueuedConnection,
								  Q_ARG(int, gc->id), Q_ARG(QString, from_nick), Q_ARG(QString, m.subject()));
	}
	
	if(!m.body().isEmpty()) {
		QMetaObject::invokeMethod(this, "notify_groupChatMessageReceived", Qt::QueuedConnection,
								  Q_ARG(int, gc->id), Q_ARG(QString, from_nick), Q_ARG(QString, m.body()));
	}
}


#pragma mark -

void LfpApi::authRequest(int entry_id, const QString &nick, const QString &reason)
{
	ContactEntry *e = d->findEntry(entry_id);
	if(!e)
		return;
	
	e->account->client()->sendSubscription(e->jid, "subscribe", nick, reason);
}

void LfpApi::authGrant(int entry_id, bool accept)
{
	ContactEntry *e = d->findEntry(entry_id);
	if(!e)
		return;
	Jid jid = e->jid;
	if(accept)
		e->account->client()->sendSubscription(jid, "subscribed");
	else
		e->account->client()->sendSubscription(jid, "unsubscribed");
}

QVariantMap LfpApi::chatStart(int contact_id, int entry_id)
{
	QVariantMap ret;
	
	Contact *c = d->findContact(contact_id);
	if(!c)
		return ret;
	
	ContactEntry *e = d->findEntry(entry_id);
	
	Chat *chat = new Chat;
	chat->id = id_chat++;
	chat->contact = c;
	chat->entry = e;
	chat->jid = (e ? e->jid : Jid());

	d->chats += chat;

	ret["chat_id"] = chat->id;
	ret["address"] = chat->jid.full();
	return ret;
}

//int LfpApi::chatStartGroup(const QString &room, const QString &nick)
//{
//	// TODO: later
//	Q_UNUSED(room);
//	Q_UNUSED(nick);
//	return 0;
//}

//QVariantMap LfpApi::chatStartGroupPrivate(int groupchat_id, const QString &nick)
//{
//	// TODO: later
//	Q_UNUSED(groupchat_id);
//	Q_UNUSED(nick);
//	return QVariantMap();
//}

void LfpApi::chatChangeEntry(int chat_id, int entry_id)
{
	Chat *chat = d->findChat(chat_id);
	if (!chat)
		return;
	
	ContactEntry *entry = d->findEntry(entry_id);
	
	if (entry && (entry->contact != chat->contact))
		return;
	
	if (entry != chat->entry) {
		chat->entry = entry;
		chat->jid = (entry ? entry->jid : Jid());
		int newEntryID = (entry ? entry->id : -1 );
		
		QMetaObject::invokeMethod(this, "notify_chatEntryChanged", Qt::QueuedConnection,
								  Q_ARG(int, chat->id), Q_ARG(int, newEntryID));
	}
}

void LfpApi::chatEnd(int chat_id)
{
	Chat *chat = d->findChat(chat_id);
	if(!chat)
		return;
	d->chats.removeAll(chat);
	delete chat;
}

void LfpApi::chatMessageSend(int chat_id, const QString &plain, const QString &xhtml, const QVariantList &urls)
{
	Chat *chat = d->findChat(chat_id);
	if(!chat)
		return;

	// TODO: ### xhtml/urls
	Q_UNUSED(xhtml);
	Q_UNUSED(urls);

	// TODO: ### advertise message events

	Message m;
	m.setTo(chat->jid);
	m.setType("chat");
	m.setBody(plain);
	chat->entry->account->client()->sendMessage(m);
}

void LfpApi::chatAudibleSend(int chat_id, const QString &audibleResourceName, const QString &plainTextAlternative, const QString &htmlAlternative)
{
	Chat *chat = d->findChat(chat_id);
	if(!chat)
		return;
	
	ContactEntry *e = chat->entry;
	if(!e)
		return;
	
	Jid destJid = chat->jid;
	QString resource = destJid.resource();
	
	if (resource.isEmpty()) {
		resource = rosterEntryGetFirstAvailableResource(e->id);
		destJid = destJid.withResource(resource);
	}
	
	if (rosterEntryResourceHasCapsFeature(e->id, resource, "sapo:audible")) {
		// Send an old-style IQ based audible
		JT_SapoAudible *audibleTask = new JT_SapoAudible(e->account->client()->rootTask());
		audibleTask->prepareIQBasedAudible(destJid, audibleResourceName);
		audibleTask->go(true);
	}
	else {
		// Send the new headline message based audible
		QDomDocument htmlDOMDoc;
		htmlDOMDoc.setContent(htmlAlternative);
		
		Message m;
		m.setTo(chat->jid);
		m.setType("headline");
		m.setSapoAudibleResource(audibleResourceName);
		m.setBody(plainTextAlternative);
		m.setHTML(HTMLElement(htmlDOMDoc.documentElement()));
		e->account->client()->sendMessage(m);
	}
}

void LfpApi::chatSendInvalidAudibleError(int chat_id, const QString &errorMsg, const QString &audibleResourceName, const QString &originalMsgBody, const QString &originalMsgHTMLBody)
{
	Chat *chat = d->findChat(chat_id);
	if(!chat)
		return;
	
	Stanza::Error err(Stanza::Error::Modify, Stanza::Error::BadRequest, errorMsg);
	err.fromCode(400);
	
	QDomDocument htmlDOMDoc;
	htmlDOMDoc.setContent(originalMsgHTMLBody);
	
	Message m;
	m.setTo(chat->jid);
	m.setType("error");
	m.setError(err);
	m.setSapoAudibleResource(audibleResourceName);
	m.setBody(originalMsgBody);
	m.setHTML(HTMLElement(htmlDOMDoc.documentElement()));
	chat->entry->account->client()->sendMessage(m);
}

void LfpApi::chatTopicSet(int chat_id, const QString &topic)
{
	// TODO: later
	Q_UNUSED(chat_id);
	Q_UNUSED(topic);
}

void LfpApi::chatUserTyping(int chat_id, bool typing)
{
	// TODO: ### send message event
	Q_UNUSED(chat_id);
	Q_UNUSED(typing);
}


void LfpApi::fetchChatRoomsListOnHost(const QString &accountUUID, const QString &host)
{
	if (d->accountsByUUID.contains(accountUUID))
		d->accountsByUUID[accountUUID]->fetchChatRoomsListOnHost(host);
}


void LfpApi::fetchChatRoomInfo(const QString &accountUUID, const QString &room_jid)
{
	if (d->accountsByUUID.contains(accountUUID))
		d->accountsByUUID[accountUUID]->fetchChatRoomInfo(room_jid);
}


int LfpApi::groupChatJoin(const QString &accountUUID, const QString &roomJidStr, const QString &nickname, const QString &password, bool request_history)
{
	Account			*account = (d->accountsByUUID.contains(accountUUID) ? d->accountsByUUID[accountUUID] : NULL);
	Jid				roomJid(roomJidStr);
	const QString	&room_name = roomJid.node();
	const QString	&room_host = roomJid.domain();
	int				ret = (-1);
	
	GroupChat *gc = d->findGroupChat(account, roomJid);
	
	if (!gc && roomJid.isValid()) {
		bool success = false;
		
		if (request_history)
			success = account->client()->groupChatJoin(room_host, room_name, nickname, password, 1000, 20, 36000);
		else
			success = account->client()->groupChatJoin(room_host, room_name, nickname, password, 0);
		
		if (success) {
			gc = addNewGroupChat(account, roomJid, nickname, request_history);
			ret = gc->id;
		}
	}
	
	return ret;
}

void LfpApi::groupChatRetryJoin(int group_chat_id, const QString &password)
{
	GroupChat *gc = d->findGroupChat(group_chat_id);
	if (gc) {
		if (gc->req_hist_on_join)
			gc->account->client()->groupChatJoin(gc->room_jid.domain(), gc->room_jid.node(), gc->nickname, password,
												 1000, 20, 36000);
		else
			gc->account->client()->groupChatJoin(gc->room_jid.domain(), gc->room_jid.node(), gc->nickname, password, 0);
	}
}

void LfpApi::groupChatChangeNick(int group_chat_id, const QString &nick)
{
	GroupChat *gc = d->findGroupChat(group_chat_id);
	if (gc) {
		QString host = gc->room_jid.domain();
		QString room = gc->room_jid.node();
		
		gc->account->client()->groupChatChangeNick(host, room, nick, Status());
	}
}

void LfpApi::groupChatChangeTopic(int group_chat_id, const QString &topic)
{
	GroupChat *gc = d->findGroupChat(group_chat_id);
	if (gc) {
		Message m;
		m.setTo(gc->room_jid);
		m.setType("groupchat");
		m.setSubject(topic);
		gc->account->client()->sendMessage(m);
	}
}

void LfpApi::groupChatSetStatus(int group_chat_id, const QString &show, const QString &status)
{
	GroupChat *gc = d->findGroupChat(group_chat_id);
	
	if (gc) {
		QString host = gc->room_jid.domain();
		QString room = gc->room_jid.node();
		
		gc->account->client()->groupChatSetStatus(host, room, Status(show, status));
	}
}

void LfpApi::groupChatSendMessage(int group_chat_id, const QString &msg)
{
	GroupChat *gc = d->findGroupChat(group_chat_id);
	if (gc) {
		Message m;
		m.setTo(gc->room_jid);
		m.setType("groupchat");
		m.setBody(msg);
		gc->account->client()->sendMessage(m);
	}
}

void LfpApi::groupChatEnd(int group_chat_id)
{
	GroupChat *gc = d->findGroupChat(group_chat_id);
	if (gc)
		groupChatLeaveAndCleanup(gc);
}

void LfpApi::groupChatInvite(const QString &accountUUID, const QString &jid, const QString &roomJid, const QString &reason)
{
	Message		m;
	Jid			room(roomJid);
	Account		*account = d->accountsByUUID[accountUUID];
	
	m.setTo(room);
	m.addMUCInvite(MUCInvite(jid, reason));
	
	QString password = account->client()->groupChatPassword(room.user(), room.host());
	if (!password.isEmpty())
		m.setMUCPassword(password);
	
	m.setTimeStamp(QDateTime::currentDateTime());
	account->client()->sendMessage(m);
}

void LfpApi::groupChatFetchConfigurationForm(int group_chat_id)
{
	GroupChat *gc = d->findGroupChat(group_chat_id);
	if (gc)
		gc->mucManager->getConfiguration();
}

void LfpApi::submitGroupChatConfigurationForm(int group_chat_id, const QString &configurationForm)
{
	GroupChat *gc = d->findGroupChat(group_chat_id);
	if (gc) {
		QDomDocument formDOMDoc;
		formDOMDoc.setContent(configurationForm);
		
		XData xdata;
		xdata.fromXml(formDOMDoc.documentElement());
		
		gc->mucManager->setConfiguration(xdata);
	}
}

void LfpApi::avatarSet(int contact_id, const QString &type, const QByteArray &data)
{
	// TODO: ###
	Q_UNUSED(contact_id);
	Q_UNUSED(type);
	Q_UNUSED(data);
}

void LfpApi::avatarPublish(const QString &type, const QByteArray &data)
{
	Q_UNUSED(type);
	
	foreach (Account *account, d->accountsByUUID.values()) {
		account->avatarFactory()->setSelfAvatar(data);
	}
}

int LfpApi::fileStart(int entry_id, const QString &filesrc, const QString &desc)
{
	int fileTransferID = fileCreatePending(entry_id);
	
	if (fileTransferID >= 0) {
		fileStartPending(fileTransferID, entry_id, filesrc, desc);
	}
	return fileTransferID;
}

int LfpApi::fileCreatePending(int entry_id)
{
	ContactEntry *entry = d->findEntry(entry_id);
	
	if (entry) {
		int	fileTransferID = addNewFileTransfer(entry->account);
		return fileTransferID;
	}
	else {
		return -1;
	}
}

void LfpApi::fileStartPending(int transfer_id, int entry_id, const QString &filesrc, const QString &desc)
{
	ContactEntry *entry = d->findEntry(entry_id);
	
	if (entry) {
		FileTransferInfo *fti = d->findFileTransferInfo(transfer_id);
		
		QString resource = rosterEntryGetResourceWithCapsFeature(entry->id,
																 "http://jabber.org/protocol/si/profile/file-transfer");
		
		fti->fileTransferHandler->send(Jid(entry->jid).withResource(resource), filesrc, desc, _dataTransferProxy);
	}
}

void LfpApi::fileAccept(int file_id, const QString &filedest)
{
	FileTransferInfo *fti = d->findFileTransferInfo(file_id);
	
	if (fti) {
		fti->fileTransferHandler->accept(filedest, QFileInfo(filedest).fileName());
	}
}

void LfpApi::fileCancel(int file_id)
{
	FileTransferInfo *fti = d->findFileTransferInfo(file_id);
	if (fti)
		cleanupFileTransferInfo(fti);
}

QVariantMap LfpApi::fileGetProps(int file_id)
{
	FileTransferInfo *fti = d->findFileTransferInfo(file_id);
	
	if (fti && fti->fileTransferHandler) {
		QVariantMap ret;
		
		ret["entry_id"] = d->findEntry(fti->account, fti->fileTransferHandler->peer(), false)->id;
		ret["accountUUID"] = fti->account->uuid();
		ret["filename"] = fti->fileTransferHandler->fileName();
		ret["size"] = fti->fileTransferHandler->fileSize();
		ret["desc"] = fti->fileTransferHandler->description();
		
		return ret;
	}
	else {
		return QVariantMap();
	}
}

int LfpApi::infoGet(int contact_id)
{
	Contact *c = d->findContact(contact_id);
	if(!c)
		return -1;

	// TODO: ### pick the best entry
	ContactEntry *e = c->entries[0];

	TransInfo *t = new TransInfo;
	t->id = id_trans++;
	t->entry = e;
	t->task = new JT_VCard(e->account->client()->rootTask());
	connect(t->task, SIGNAL(finished()), d, SLOT(transinfo_finished()));
	t->task->get(e->jid);
	t->task->go(true);
	d->transinfos += t;

	return t->id;
}

int LfpApi::infoPublish(const QString &accountUUID, const QVariantMap &info)
{
	VCard v = infoMapToVCard(info);

	TransInfo *t = new TransInfo;
	t->id = id_trans++;
	t->entry = 0; // publish
	t->task = new JT_VCard(d->accountsByUUID[accountUUID]->client()->rootTask());
	connect(t->task, SIGNAL(finished()), d, SLOT(transinfo_finished()));
	t->task->set(v);
	t->task->go(true);
	d->transinfos += t;

	return t->id;
}


void LfpApi::sendSMS(int entry_id, const QString & text)
{
	ContactEntry *e = d->findEntry(entry_id);
	if (!e)
		return;
	
	Message m;
	m.setTo(e->jid);
	m.setType("chat");
	m.setBody(text);
	e->account->client()->sendMessage(m);
}


void LfpApi::transportRegister(const QString &accountUUID, const QString &host, const QString &username, const QString &password)
{
	if (d->accountsByUUID.contains(accountUUID))
		d->accountsByUUID[accountUUID]->transportRegister(host, username, password);
}

void LfpApi::transportUnregister(const QString &accountUUID, const QString &host)
{
	if (d->accountsByUUID.contains(accountUUID))
		d->accountsByUUID[accountUUID]->transportUnregister(host);
}


#pragma mark -
#pragma mark Bridge Notifications

void LfpApi::notify_accountXmlIO(const QString &accountUUID, bool inbound, const QString &xml)
{
	LfpArgumentList args;
	args += LfpArgument("accountUUID", accountUUID);
	args += LfpArgument("inbound", inbound);
	args += LfpArgument("xml", xml);
	do_invokeMethod("notify_accountXmlIO", args);
}

void LfpApi::notify_accountConnectedToServerHost(const QString &uuid, const QString &hostname)
{
	LfpArgumentList args;
	args += LfpArgument("accountUUID", uuid);
	args += LfpArgument("hostname", hostname);
	do_invokeMethod("notify_accountConnectedToServerHost", args);
}

void LfpApi::notify_connectionError(const QString &accountUUID, const QString &error_name, int error_kind, int error_code)
{
	LfpArgumentList args;
	args += LfpArgument("accountUUID", accountUUID);
	args += LfpArgument("error_name", error_name);
	args += LfpArgument("error_kind", error_kind);
	args += LfpArgument("error_code", error_code);
	do_invokeMethod("notify_connectionError", args);
}

void LfpApi::notify_statusUpdated(const QString &accountUUID, const QString &show, const QString &status)
{
	LfpArgumentList args;
	args += LfpArgument("accountUUID", accountUUID);
	args += LfpArgument("show", show);
	args += LfpArgument("status", status);
	do_invokeMethod("notify_statusUpdated", args);
}

void LfpApi::notify_savedStatusReceived(const QString &accountUUID, const QString &show, const QString &status)
{
	LfpArgumentList args;
	args += LfpArgument("accountUUID", accountUUID);
	args += LfpArgument("show", show);
	args += LfpArgument("status", status);
	do_invokeMethod("notify_savedStatusReceived", args);
}

void LfpApi::notify_rosterGroupAdded(int group_id, const QVariantMap & group_props)
{
	LfpArgumentList args;
	args += LfpArgument("group_id", group_id);
	args += LfpArgument("props", group_props);
	do_invokeMethod("notify_rosterGroupAdded", args);
}

void LfpApi::notify_rosterGroupChanged(int group_id, const QVariantMap & group_props)
{
	LfpArgumentList args;
	args += LfpArgument("group_id", group_id);
	args += LfpArgument("props", group_props);
	do_invokeMethod("notify_rosterGroupChanged", args);
}

void LfpApi::notify_rosterGroupRemoved(int group_id)
{
	LfpArgumentList args;
	args += LfpArgument("group_id", group_id);
	do_invokeMethod("notify_rosterGroupRemoved", args);
}

void LfpApi::notify_rosterContactAdded(int group_id, int contact_id, const QVariantMap & props)
{
	LfpArgumentList args;
	args += LfpArgument("group_id", group_id);
	args += LfpArgument("contact_id", contact_id);
	args += LfpArgument("contact_props", props);
	do_invokeMethod("notify_rosterContactAdded", args);
}

void LfpApi::notify_rosterContactChanged(int contact_id, const QVariantMap & props)
{
	LfpArgumentList args;
	args += LfpArgument("contact_id", contact_id);
	args += LfpArgument("contact_props", props);
	do_invokeMethod("notify_rosterContactChanged", args);
}

void LfpApi::notify_rosterContactGroupAdded(int contact_id, int group_id)
{
	LfpArgumentList args;
	args += LfpArgument("contact_id", contact_id);
	args += LfpArgument("group_id", group_id);
	do_invokeMethod("notify_rosterContactGroupAdded", args);
}

void LfpApi::notify_rosterContactGroupChanged(int contact_id, int group_old_id, int group_new_id)
{
	LfpArgumentList args;
	args += LfpArgument("contact_id", contact_id);
	args += LfpArgument("group_old_id", group_old_id);
	args += LfpArgument("group_new_id", group_new_id);
	do_invokeMethod("notify_rosterContactGroupChanged", args);
}

void LfpApi::notify_rosterContactGroupRemoved(int contact_id, int group_id)
{
	LfpArgumentList args;
	args += LfpArgument("contact_id", contact_id);
	args += LfpArgument("group_id", group_id);
	do_invokeMethod("notify_rosterContactGroupRemoved", args);
}

void LfpApi::notify_rosterContactRemoved(int contact_id)
{
	LfpArgumentList args;
	args += LfpArgument("contact_id", contact_id);
	do_invokeMethod("notify_rosterContactRemoved", args);
}

void LfpApi::notify_rosterEntryAdded(int contact_id, int entry_id, const QVariantMap & props)
{
	LfpArgumentList args;
	args += LfpArgument("contact_id", contact_id);
	args += LfpArgument("entry_id", entry_id);
	args += LfpArgument("entry_props", props);
	do_invokeMethod("notify_rosterEntryAdded", args);
}

void LfpApi::notify_rosterEntryChanged(int entry_id, const QVariantMap & props)
{
	LfpArgumentList args;
	args += LfpArgument("entry_id", entry_id);
	args += LfpArgument("entry_props", props);
	do_invokeMethod("notify_rosterEntryChanged", args);
}

void LfpApi::notify_rosterEntryContactChanged(int entry_id, int contact_old_id, int contact_new_id)
{
	LfpArgumentList args;
	args += LfpArgument("entry_id", entry_id);
	args += LfpArgument("contact_old_id", contact_old_id);
	args += LfpArgument("contact_new_id", contact_new_id);
	do_invokeMethod("notify_rosterEntryContactChanged", args);
}

void LfpApi::notify_rosterEntryRemoved(int entry_id)
{
	LfpArgumentList args;
	args += LfpArgument("entry_id", entry_id);
	do_invokeMethod("notify_rosterEntryRemoved", args);
}

void LfpApi::notify_rosterEntryResourceListChanged(int entry_id, const QVariantList & resourceList)
{
	LfpArgumentList args;
	args += LfpArgument("entry_id", entry_id);
	args += LfpArgument("resource_list", resourceList);
	do_invokeMethod("notify_rosterEntryResourceListChanged", args);
}

void LfpApi::notify_rosterEntryResourceChanged(int entry_id, const QString &resource)
{
	LfpArgumentList args;
	args += LfpArgument("entry_id", entry_id);
	args += LfpArgument("resource", resource);
	do_invokeMethod("notify_rosterEntryResourceChanged", args);
}

void LfpApi::notify_rosterEntryResourceCapabilitiesChanged(int entry_id, const QString &resource, const QVariantList & capsFeatures)
{
	LfpArgumentList args;
	args += LfpArgument("entry_id", entry_id);
	args += LfpArgument("resource", resource);
	args += LfpArgument("features", capsFeatures);
	do_invokeMethod("notify_rosterEntryResourceCapabilitiesChanged", args);
}

void LfpApi::notify_rosterEntryResourceClientInfoReceived(int entry_id, const QString &resource, const QString &client_name, const QString &client_version, const QString &os_name)
{
	LfpArgumentList args;
	args += LfpArgument("entry_id", entry_id);
	args += LfpArgument("resource", resource);
	args += LfpArgument("client_name", client_name);
	args += LfpArgument("client_version", client_version);
	args += LfpArgument("os_name", os_name);
	do_invokeMethod("notify_rosterEntryResourceClientInfoReceived", args);
}

void LfpApi::notify_authGranted(int entry_id)
{
	LfpArgumentList args;
	args += LfpArgument("entry_id", entry_id);
	do_invokeMethod("notify_authGranted", args);
}

void LfpApi::notify_authRequest(int entry_id, const QString &nick, const QString &reason)
{
	LfpArgumentList args;
	args += LfpArgument("entry_id", entry_id);
	args += LfpArgument("nick", nick);
	args += LfpArgument("reason", reason);
	do_invokeMethod("notify_authRequest", args);
}

void LfpApi::notify_authLost(int entry_id)
{
	LfpArgumentList args;
	args += LfpArgument("entry_id", entry_id);
	do_invokeMethod("notify_authLost", args);
}

void LfpApi::notify_presenceUpdated(int entry_id, const QString &show, const QString &status)
{
		LfpArgumentList args;
		args += LfpArgument("entry_id", entry_id);
		args += LfpArgument("show", show);
		args += LfpArgument("status", status);
		do_invokeMethod("notify_presenceUpdated", args);
}

void LfpApi::notify_chatIncoming(int chat_id, int contact_id, int entry_id, const QString &address)
{
	LfpArgumentList args;
	args += LfpArgument("chat_id", chat_id);
	args += LfpArgument("contact_id", contact_id);
	args += LfpArgument("entry_id", entry_id);
	args += LfpArgument("address", address);
	do_invokeMethod("notify_chatIncoming", args);
}

void LfpApi::notify_chatIncomingPrivate(int chat_id, int groupchat_id, const QString &nick, const QString &address)
{
	LfpArgumentList args;
	args += LfpArgument("chat_id", chat_id);
	args += LfpArgument("groupchat_id", groupchat_id);
	args += LfpArgument("nick", nick);
	args += LfpArgument("address", address);
	do_invokeMethod("notify_chatIncomingPrivate", args);
}

void LfpApi::notify_chatEntryChanged(int chat_id, int entry_id)
{
	LfpArgumentList args;
	args += LfpArgument("chat_id", chat_id);
	args += LfpArgument("entry_id", entry_id);
	do_invokeMethod("notify_chatEntryChanged", args);
}

void LfpApi::notify_chatJoined(int chat_id)
{
	LfpArgumentList args;
	args += LfpArgument("chat_id", chat_id);
	do_invokeMethod("notify_chatJoined", args);
}

void LfpApi::notify_chatError(int chat_id, const QString &message)
{
	LfpArgumentList args;
	args += LfpArgument("chat_id", chat_id);
	args += LfpArgument("message", message);
	do_invokeMethod("notify_chatError", args);
}

void LfpApi::notify_chatPresence(int chat_id, const QString &nick, const QString &show, const QString &status)
{
	LfpArgumentList args;
	args += LfpArgument("chat_id", chat_id);
	args += LfpArgument("nick", nick);
	args += LfpArgument("show", show);
	args += LfpArgument("status", status);
	do_invokeMethod("notify_chatPresence", args);
}

void LfpApi::notify_chatMessageReceived(int chat_id, const QString &nick, const QString &subject, const QString &plain, const QString &xhtml, const QVariantList &urls)
{
	LfpArgumentList args;
	args += LfpArgument("chat_id", chat_id);
	args += LfpArgument("nick", nick);
	args += LfpArgument("subject", subject);
	args += LfpArgument("plain", plain);
	args += LfpArgument("xhtml", xhtml);
	args += LfpArgument("urls", urls);
	do_invokeMethod("notify_chatMessageReceived", args);
}

void LfpApi::notify_chatAudibleReceived(int chat_id, const QString &audibleResourceName, const QString &body, const QString &htmlBody)
{
	LfpArgumentList args;
	args += LfpArgument("chat_id", chat_id);
	args += LfpArgument("audible_resource_name", audibleResourceName);
	args += LfpArgument("body", body);
	args += LfpArgument("htmlBody", htmlBody);
	do_invokeMethod("notify_chatAudibleReceived", args);
}

void LfpApi::notify_chatSystemMessageReceived(int chat_id, const QString &plain)
{
	LfpArgumentList args;
	args += LfpArgument("chat_id", chat_id);
	args += LfpArgument("plain", plain);
	do_invokeMethod("notify_chatSystemMessageReceived", args);
}

void LfpApi::notify_chatTopicChanged(int chat_id, const QString &topic)
{
	LfpArgumentList args;
	args += LfpArgument("chat_id", chat_id);
	args += LfpArgument("topic", topic);
	do_invokeMethod("notify_chatTopicChanged", args);
}

void LfpApi::notify_chatContactTyping(int chat_id, const QString &nick, bool typing)
{
	LfpArgumentList args;
	args += LfpArgument("chat_id", chat_id);
	args += LfpArgument("nick", nick);
	args += LfpArgument("typing", typing);
	do_invokeMethod("notify_chatContactTyping", args);
}

void LfpApi::notify_groupChatJoined(int group_chat_id, const QString &room_jid, const QString &nickname)
{
	LfpArgumentList args;
	args += LfpArgument("group_chat_id", group_chat_id);
	args += LfpArgument("room_jid", room_jid);
	args += LfpArgument("nickname", nickname);
	do_invokeMethod("notify_groupChatJoined", args);
}

void LfpApi::notify_groupChatLeft(int group_chat_id)
{
	LfpArgumentList args;
	args += LfpArgument("group_chat_id", group_chat_id);
	do_invokeMethod("notify_groupChatLeft", args);
}

void LfpApi::notify_groupChatCreated(int group_chat_id)
{
	LfpArgumentList args;
	args += LfpArgument("group_chat_id", group_chat_id);
	do_invokeMethod("notify_groupChatCreated", args);
}

void LfpApi::notify_groupChatDestroyed(int group_chat_id, const QString &reason, const QString &alternate_room_jid)
{
	LfpArgumentList args;
	args += LfpArgument("group_chat_id", group_chat_id);
	args += LfpArgument("reason", reason);
	args += LfpArgument("alternate_room_jid", alternate_room_jid);
	do_invokeMethod("notify_groupChatDestroyed", args);
}

void LfpApi::notify_groupChatContactJoined(int group_chat_id, const QString &nickname, const QString &jid, const QString &role, const QString &affiliation)
{
	LfpArgumentList args;
	args += LfpArgument("group_chat_id", group_chat_id);
	args += LfpArgument("nickname", nickname);
	args += LfpArgument("jid", jid);
	args += LfpArgument("role", role);
	args += LfpArgument("affiliation", affiliation);
	do_invokeMethod("notify_groupChatContactJoined", args);
}

void LfpApi::notify_groupChatContactRoleOrAffiliationChanged(int group_chat_id, const QString &nickname, const QString &role, const QString &affiliation)
{
	LfpArgumentList args;
	args += LfpArgument("group_chat_id", group_chat_id);
	args += LfpArgument("nickname", nickname);
	args += LfpArgument("role", role);
	args += LfpArgument("affiliation", affiliation);
	do_invokeMethod("notify_groupChatContactRoleOrAffiliationChanged", args);
}

void LfpApi::notify_groupChatContactStatusChanged(int group_chat_id, const QString &nickname, const QString &show, const QString &status)
{
	LfpArgumentList args;
	args += LfpArgument("group_chat_id", group_chat_id);
	args += LfpArgument("nickname", nickname);
	args += LfpArgument("show", show);
	args += LfpArgument("status", status);
	do_invokeMethod("notify_groupChatContactStatusChanged", args);
}

void LfpApi::notify_groupChatContactNicknameChanged(int group_chat_id, const QString &old_nickname, const QString &new_nickname)
{
	LfpArgumentList args;
	args += LfpArgument("group_chat_id", group_chat_id);
	args += LfpArgument("old_nickname", old_nickname);
	args += LfpArgument("new_nickname", new_nickname);
	do_invokeMethod("notify_groupChatContactNicknameChanged", args);
}

void LfpApi::notify_groupChatContactBanned(int group_chat_id, const QString &nickname, const QString &actor, const QString &reason)
{
	LfpArgumentList args;
	args += LfpArgument("group_chat_id", group_chat_id);
	args += LfpArgument("nickname", nickname);
	args += LfpArgument("actor", actor);
	args += LfpArgument("reason", reason);
	do_invokeMethod("notify_groupChatContactBanned", args);
}

void LfpApi::notify_groupChatContactKicked(int group_chat_id, const QString &nickname, const QString &actor, const QString &reason)
{
	LfpArgumentList args;
	args += LfpArgument("group_chat_id", group_chat_id);
	args += LfpArgument("nickname", nickname);
	args += LfpArgument("actor", actor);
	args += LfpArgument("reason", reason);
	do_invokeMethod("notify_groupChatContactKicked", args);
}

void LfpApi::notify_groupChatContactRemoved(int group_chat_id, const QString &nickname, const QString &due_to, const QString &actor, const QString &reason)
{
	LfpArgumentList args;
	args += LfpArgument("group_chat_id", group_chat_id);
	args += LfpArgument("nickname", nickname);
	args += LfpArgument("due_to", due_to);
	args += LfpArgument("actor", actor);
	args += LfpArgument("reason", reason);
	do_invokeMethod("notify_groupChatContactRemoved", args);
}

void LfpApi::notify_groupChatContactLeft(int group_chat_id, const QString &nickname, const QString &status)
{
	LfpArgumentList args;
	args += LfpArgument("group_chat_id", group_chat_id);
	args += LfpArgument("nickname", nickname);
	args += LfpArgument("status", status);
	do_invokeMethod("notify_groupChatContactLeft", args);
}

void LfpApi::notify_groupChatError(int group_chat_id, int code, const QString &str)
{
	LfpArgumentList args;
	args += LfpArgument("group_chat_id", group_chat_id);
	args += LfpArgument("code", code);
	args += LfpArgument("str", str);
	do_invokeMethod("notify_groupChatError", args);
}

void LfpApi::notify_groupChatTopicChanged(int group_chat_id, const QString &actor, const QString &new_topic)
{
	LfpArgumentList args;
	args += LfpArgument("group_chat_id", group_chat_id);
	args += LfpArgument("actor", actor);
	args += LfpArgument("new_topic", new_topic);
	do_invokeMethod("notify_groupChatTopicChanged", args);
}

void LfpApi::notify_groupChatMessageReceived(int group_chat_id, const QString &from_nick, const QString &plain_body)
{
	LfpArgumentList args;
	args += LfpArgument("group_chat_id", group_chat_id);
	args += LfpArgument("from_nick", from_nick);
	args += LfpArgument("plain_body", plain_body);
	do_invokeMethod("notify_groupChatMessageReceived", args);
}

void LfpApi::notify_groupChatInvitationReceived(const QString &accountUUID, const QString &room_jid, const QString &sender, const QString &reason, const QString &password)
{
	LfpArgumentList args;
	args += LfpArgument("accountUUID", accountUUID);
	args += LfpArgument("room_jid", room_jid);
	args += LfpArgument("sender", sender);
	args += LfpArgument("reason", reason);
	args += LfpArgument("password", password);
	do_invokeMethod("notify_groupChatInvitationReceived", args);
}

void LfpApi::notify_groupChatConfigurationFormReceived(int group_chat_id, const QString &formXDataXML, const QString &err_msg)
{
	LfpArgumentList args;
	args += LfpArgument("group_chat_id", group_chat_id);
	args += LfpArgument("formXDataXML", formXDataXML);
	args += LfpArgument("err_msg", err_msg);
	do_invokeMethod("notify_groupChatConfigurationFormReceived", args);
}

void LfpApi::notify_groupChatConfigurationModificationResult(int group_chat_id, bool success, const QString &err_msg)
{
	LfpArgumentList args;
	args += LfpArgument("group_chat_id", group_chat_id);
	args += LfpArgument("success", success);
	args += LfpArgument("err_msg", err_msg);
	do_invokeMethod("notify_groupChatConfigurationModificationResult", args);
}


void LfpApi::notify_offlineMessageReceived(const QString &accountUUID, const QString &timestamp, const QString &fromJID, const QString &nick, const QString &subject, const QString &plain, const QString &xhtml, const QVariantList &urls)
{
	LfpArgumentList args;
	args += LfpArgument("accountUUID", accountUUID);
	args += LfpArgument("timestamp", timestamp);
	args += LfpArgument("fromJID", fromJID);
	args += LfpArgument("nick", nick);
	args += LfpArgument("subject", subject);
	args += LfpArgument("plain", plain);
	args += LfpArgument("xhtml", xhtml);
	args += LfpArgument("urls", urls);
	do_invokeMethod("notify_offlineMessageReceived", args);
}

void LfpApi::notify_headlineNotificationMessageReceived(const QString &accountUUID, const QString &channel, const QString &item_url, const QString &flash_url, const QString &icon_url, const QString &nick, const QString &subject, const QString &plain, const QString &xhtml)
{
	LfpArgumentList args;
	args += LfpArgument("accountUUID", accountUUID);
	args += LfpArgument("channel", channel);
	args += LfpArgument("item_url", item_url);
	args += LfpArgument("flash_url", flash_url);
	args += LfpArgument("icon_url", icon_url);
	args += LfpArgument("nick", nick);
	args += LfpArgument("subject", subject);
	args += LfpArgument("plain", plain);
	args += LfpArgument("xhtml", xhtml);
	do_invokeMethod("notify_headlineNotificationMessageReceived", args);
}

void LfpApi::notify_avatarChanged(int entry_id, const QString &type, const QByteArray &data)
{
	LfpArgumentList args;
	args += LfpArgument("entry_id", entry_id);
	args += LfpArgument("type", type);
	args += LfpArgument("data", data);
	do_invokeMethod("notify_avatarChanged", args);
}

void LfpApi::notify_selfAvatarChanged(const QString &accountUUID, const QString &type, const QByteArray &data)
{
	LfpArgumentList args;
	args += LfpArgument("accountUUID", accountUUID);
	args += LfpArgument("type", type);
	args += LfpArgument("data", data);
	do_invokeMethod("notify_selfAvatarChanged", args);
}

void LfpApi::notify_fileIncoming(int file_id)
{
	LfpArgumentList args;
	args += LfpArgument("file_id", file_id);
	do_invokeMethod("notify_fileIncoming", args);
}

void LfpApi::notify_fileAccepted(int file_id)
{
	LfpArgumentList args;
	args += LfpArgument("file_id", file_id);
	do_invokeMethod("notify_fileAccepted", args);
}

void LfpApi::notify_fileProgress(int file_id, const QString &status, qlonglong sent, qlonglong progressAt, qlonglong progressTotal)
{
	LfpArgumentList args;
	args += LfpArgument("file_id", file_id);
	args += LfpArgument("status", status);
	args += LfpArgument("sent", sent);
	args += LfpArgument("progressAt", progressAt);
	args += LfpArgument("progressTotal", progressTotal);
	do_invokeMethod("notify_fileProgress", args);
}

void LfpApi::notify_fileFinished(int file_id)
{
	LfpArgumentList args;
	args += LfpArgument("file_id", file_id);
	do_invokeMethod("notify_fileFinished", args);
}

void LfpApi::notify_fileError(int file_id, const QString &message)
{
	LfpArgumentList args;
	args += LfpArgument("file_id", file_id);
	args += LfpArgument("message", message);
	do_invokeMethod("notify_fileError", args);
}

void LfpApi::notify_infoReady(int trans_id, const QVariantMap &info)
{
	LfpArgumentList args;
	args += LfpArgument("trans_id", trans_id);
	args += LfpArgument("info", info);
	do_invokeMethod("notify_infoReady", args);
}

void LfpApi::notify_infoPublished(int trans_id)
{
	LfpArgumentList args;
	args += LfpArgument("trans_id", trans_id);
	do_invokeMethod("notify_infoPublished", args);
}

void LfpApi::notify_infoError(int trans_id, const QString &message)
{
	LfpArgumentList args;
	args += LfpArgument("trans_id", trans_id);
	args += LfpArgument("message", message);
	do_invokeMethod("notify_infoError", args);
}

void LfpApi::notify_serverItemsUpdated(const QVariantList &server_items)
{
	LfpArgumentList args;
	args += LfpArgument("server_items", server_items);
	do_invokeMethod("notify_serverItemsUpdated", args);
}

void LfpApi::notify_serverItemInfoUpdated(const QString &item, const QString &name, const QVariantList &features)
{
	LfpArgumentList args;
	args += LfpArgument("item", item);
	args += LfpArgument("name", name);
	args += LfpArgument("features", features);
	do_invokeMethod("notify_serverItemInfoUpdated", args);
}

void LfpApi::notify_sapoAgentsUpdated(const QVariantMap &sapo_agents_description)
{
	LfpArgumentList args;
	args += LfpArgument("sapo_agents_description", sapo_agents_description);
	do_invokeMethod("notify_sapoAgentsUpdated", args);
}

void LfpApi::notify_chatRoomsListReceived(const QString &host, const QVariantList &rooms_list)
{
	LfpArgumentList args;
	args += LfpArgument("host", host);
	args += LfpArgument("rooms_list", rooms_list);
	do_invokeMethod("notify_chatRoomsListReceived", args);
}

void LfpApi::notify_chatRoomInfoReceived(const QString &room_jid, const QVariantMap &info)
{
	LfpArgumentList args;
	args += LfpArgument("room_jid", room_jid);
	args += LfpArgument("info", info);
	do_invokeMethod("notify_chatRoomInfoReceived", args);
}

void LfpApi::notify_smsCreditUpdated(const QString &accountUUID, int credit, int free_msgs, int total_sent_this_month)
{
	LfpArgumentList args;
	args += LfpArgument("accountUUID", accountUUID);
	args += LfpArgument("credit", credit);
	args += LfpArgument("free_msgs", free_msgs);
	args += LfpArgument("total_sent_this_month", total_sent_this_month);
	do_invokeMethod("notify_smsCreditUpdated", args);
}

void LfpApi::notify_smsSent(const QString &accountUUID,
							int result, int nr_used_msgs, int nr_used_chars,
							const QString & destination_phone_nr, const QString & body,
							int credit, int free_msgs, int total_sent_this_month)
{
	LfpArgumentList args;
	args += LfpArgument("accountUUID", accountUUID);
	args += LfpArgument("result", result);
	args += LfpArgument("nr_used_msgs", nr_used_msgs);
	args += LfpArgument("nr_used_chars", nr_used_chars);
	args += LfpArgument("destination_phone_nr", destination_phone_nr);
	args += LfpArgument("body", body);
	args += LfpArgument("credit", credit);
	args += LfpArgument("free_msgs", free_msgs);
	args += LfpArgument("total_sent_this_month", total_sent_this_month);
	do_invokeMethod("notify_smsSent", args);
}

void LfpApi::notify_smsReceived(const QString &accountUUID,
								const QString & date_received, const QString & source_phone_nr, const QString & body,
								int credit, int free_msgs, int total_sent_this_month)
{
	LfpArgumentList args;
	args += LfpArgument("accountUUID", accountUUID);
	args += LfpArgument("date_received", date_received);
	args += LfpArgument("source_phone_nr", source_phone_nr);
	args += LfpArgument("body", body);
	args += LfpArgument("credit", credit);
	args += LfpArgument("free_msgs", free_msgs);
	args += LfpArgument("total_sent_this_month", total_sent_this_month);
	do_invokeMethod("notify_smsReceived", args);
}

void LfpApi::notify_liveUpdateURLReceived(const QString &accountUUID, const QString &url)
{
	LfpArgumentList args;
	args += LfpArgument("accountUUID", accountUUID);
	args += LfpArgument("url", url);
	do_invokeMethod("notify_liveUpdateURLReceived", args);
}

void LfpApi::notify_sapoChatOrderReceived(const QString &accountUUID, const QVariantMap &orderMap)
{
	LfpArgumentList args;
	args += LfpArgument("accountUUID", accountUUID);
	args += LfpArgument("orderMap", orderMap);
	do_invokeMethod("notify_sapoChatOrderReceived", args);
}

void LfpApi::notify_transportRegistrationStatusUpdated(const QString &accountUUID, const QString &transportAgent, bool isRegistered, const QString &registeredUsername)
{
	LfpArgumentList args;
	args += LfpArgument("accountUUID", accountUUID);
	args += LfpArgument("transportAgent", transportAgent);
	args += LfpArgument("registered", isRegistered);
	args += LfpArgument("username", registeredUsername);
	do_invokeMethod("notify_transportRegistrationStatusUpdated", args);
}

void LfpApi::notify_transportLoggedInStatusUpdated(const QString &accountUUID, const QString &transportAgent, bool isLoggedIn)
{
	LfpArgumentList args;
	args += LfpArgument("accountUUID", accountUUID);
	args += LfpArgument("transportAgent", transportAgent);
	args += LfpArgument("logged_in", isLoggedIn);
	do_invokeMethod("notify_transportLoggedInStatusUpdated", args);
}

void LfpApi::notify_serverVarsReceived(const QString &accountUUID, const QVariantMap &varsValues)
{
	LfpArgumentList args;
	args += LfpArgument("accountUUID", accountUUID);
	args += LfpArgument("varsValues", varsValues);
	do_invokeMethod("notify_serverVarsReceived", args);
}

void LfpApi::notify_selfVCardChanged(const QString &accountUUID, const QVariantMap &vCard)
{
	LfpArgumentList args;
	args += LfpArgument("accountUUID", accountUUID);
	args += LfpArgument("vCard", vCard);
	do_invokeMethod("notify_selfVCardChanged", args);
}

void LfpApi::notify_debuggerStatusChanged(const QString &accountUUID, bool isDebugger)
{
	LfpArgumentList args;
	args += LfpArgument("accountUUID", accountUUID);
	args += LfpArgument("isDebugger", isDebugger);
	do_invokeMethod("notify_debuggerStatusChanged", args);
}

#include "lfp_api.moc"

