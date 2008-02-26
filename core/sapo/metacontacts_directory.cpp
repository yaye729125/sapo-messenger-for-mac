/*
 *  metacontacts_directory.cpp
 *
 *	Copyright (C) 2008 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jpavao@co.sapo.pt>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informações sobre o licenciamento, leia o ficheiro README.
 */

#include "metacontacts_directory.h"


//#define METACONTACTS_DEBUG


JT_StorageMetacontacts::JT_StorageMetacontacts(Task *parent) : Task(parent)
{
}

JT_StorageMetacontacts::~JT_StorageMetacontacts()
{
}

void JT_StorageMetacontacts::get()
{
	QDomElement iq = doc()->createElement("iq");
	QDomElement query = doc()->createElement("query");
	QDomElement storage = doc()->createElement("storage");
	
	iq.setAttribute("id", id());
	iq.setAttribute("type", "get");
	iq.appendChild(query);
	
	query.setAttribute("xmlns", "jabber:iq:private");
	query.appendChild(storage);
	
	storage.setAttribute("xmlns", "storage:metacontacts");
	
	_type = "get";
	_iq = iq;
}

void JT_StorageMetacontacts::set(const QList<MetacontactJIDRecord> &metacontacts_list)
{
	QDomElement iq = doc()->createElement("iq");
	QDomElement query = doc()->createElement("query");
	QDomElement storage = doc()->createElement("storage");
	
	iq.setAttribute("id", id());
	iq.setAttribute("type", "set");
	iq.appendChild(query);
	
	query.setAttribute("xmlns", "jabber:iq:private");
	query.appendChild(storage);
	
	storage.setAttribute("xmlns", "storage:metacontacts");
	
	foreach (const MetacontactJIDRecord &rec, metacontacts_list) {
		QDomElement meta = doc()->createElement("meta");
		
		meta.setAttribute("jid", rec["jid"]);
		meta.setAttribute("tag", rec["tag"]);
		if (rec.contains("order"))
			meta.setAttribute("order", rec["order"]);
		storage.appendChild(meta);
	}
	
	_type = "set";
	_iq = iq;
	_metacontacts_list = metacontacts_list;
}

void JT_StorageMetacontacts::onGo()
{
	send(_iq);
}

bool JT_StorageMetacontacts::take (const QDomElement &stanza)
{
	if (stanza.tagName() == "iq" && stanza.attribute("id") == id()) {
		if (stanza.attribute("type") == "result") {
			if (_type == "get") {
				
				QDomElement query = stanza.firstChildElement("query");
				
				if (!query.isNull() && query.attribute("xmlns") == "jabber:iq:private") {
					QDomElement storage = query.firstChildElement("storage");
					
					if (!storage.isNull() && storage.attribute("xmlns") == "storage:metacontacts") {
						_metacontacts_list.clear();
						
						QDomElement meta = storage.firstChildElement("meta");
						
						while (!meta.isNull()) {
							MetacontactJIDRecord	metaRecord;
							const QDomNamedNodeMap	&attribsMap = meta.attributes();
							
							for (int i = 0; i < attribsMap.count(); ++i) {
								const QDomAttr &attrib = attribsMap.item(i).toAttr();
								metaRecord[attrib.name()] = attrib.value();
							}
							_metacontacts_list += metaRecord;
							
							meta = meta.nextSiblingElement("meta");
						}
						setSuccess();
						return true;
					}
				}
				setError();
			}
			else {
				setSuccess();
			}
		}
		else {
			setError();
		}
		return true;
	}
	return false;
}


#pragma mark -


MetacontactsDirectory::MetacontactsDirectory(Client *c) :
	_client(c), _needsToSaveToServer(false), _needsToUpdateFromServer(false)
{
	connect(&_saveTimer, SIGNAL(timeout()), SLOT(saveTimerTimedOut()));
	connect(&_updateTimer, SIGNAL(timeout()), SLOT(updateTimerTimedOut()));
}

MetacontactsDirectory::~MetacontactsDirectory()
{
}

void MetacontactsDirectory::clear(void)
{
	_tagsByJID.clear();
	_orderByJID.clear();
	setNeedsToSaveToServer(false);
	_dirtyJIDs.clear();
	
#ifdef METACONTACTS_DEBUG
	fprintf(stderr, "    ** _dirtyJIDs.clear() in MetacontactsDirectory::clear()\n");
#endif
}

void MetacontactsDirectory::updateFromServer(void)
{
	JT_StorageMetacontacts *task = new JT_StorageMetacontacts(client()->rootTask());
	
	connect(task, SIGNAL(finished()), SLOT(storageMetacontacts_finishedUpdateFromServer()));
	task->get();
	task->go(true);
}

void MetacontactsDirectory::saveTimerTimedOut (void)
{
	saveToServerIfNeeded();
}

void MetacontactsDirectory::updateTimerTimedOut (void)
{
	updateFromServer();
}

void MetacontactsDirectory::storageMetacontacts_finishedUpdateFromServer(void)
{
	JT_StorageMetacontacts *task = (JT_StorageMetacontacts *)sender();
	
	if (task->success()) {
		const QList<JT_StorageMetacontacts::MetacontactJIDRecord> &metacontacts = task->metacontacts_list();
		QSet<QString> jids_in_metacontacts_list;
		
		// Update all the added or changed entries
		foreach (JT_StorageMetacontacts::MetacontactJIDRecord rec, metacontacts) {
			if (rec.contains("jid")) {
				QString &jid = rec["jid"];
				bool didChange = false;
				
				// Add the jid to the set that will be used later
				jids_in_metacontacts_list += jid;
				
				if (rec["tag"] != _tagsByJID[jid]) {
					_tagsByJID[jid] = rec["tag"];
					didChange = true;
				}
				if (rec["order"].toInt() != _orderByJID[jid]) {
					_orderByJID[jid] = rec["order"].toInt();
					didChange = true;
				}
				
				if (didChange) {
					emit metacontactInfoForJIDDidChange(jid, _tagsByJID[jid], _orderByJID[jid]);
				}
			}
		}
		
		// Update all the deleted entries
		foreach (QString jid, _tagsByJID.keys()) {
			if (!jids_in_metacontacts_list.contains(jid)) {
				_tagsByJID.remove(jid);
				_orderByJID.remove(jid);
				
				emit metacontactInfoForJIDDidChange(jid, "", 0);
			}
		}
		
		setNeedsToSaveToServer(false);
		_dirtyJIDs.clear();
		
#ifdef METACONTACTS_DEBUG
		fprintf(stderr, "    ** _dirtyJIDs.clear() in MetacontactsDirectory::storageMetacontacts_finishedUpdateFromServer()\n");
#endif
	}
	
	emit finishedUpdateFromServer(task->success());
}

void MetacontactsDirectory::saveToServer(void)
{
	QList<JT_StorageMetacontacts::MetacontactJIDRecord> metacontacts;
	
	foreach (QString jid, _tagsByJID.keys()) {
		JT_StorageMetacontacts::MetacontactJIDRecord rec;
		
		rec["jid"] = jid;
		rec["tag"] = _tagsByJID[jid];
		if (_orderByJID.contains(jid)) {
			rec["order"] = QString::number(_orderByJID[jid]);
		}
		
		metacontacts += rec;
	}
	
	// Upload the list to the server
	JT_StorageMetacontacts *task = new JT_StorageMetacontacts(client()->rootTask());
	
	connect(task, SIGNAL(finished()), SLOT(storageMetacontacts_finishedSaveToServer()));
	task->set(metacontacts);
	task->go(true);
	
	setNeedsToSaveToServer(false);
	
#ifdef METACONTACTS_DEBUG
	fprintf(stderr,	"    ** MetacontactsDirectory::saveToServer(void)\n");
#endif
}

void MetacontactsDirectory::storageMetacontacts_finishedSaveToServer(void)
{
	JT_StorageMetacontacts *task = (JT_StorageMetacontacts *)sender();
	
	emit finishedSaveToServer(task->success(), _dirtyJIDs.toList());
	
	if (task->success()) {
		_dirtyJIDs.clear();
		
#ifdef METACONTACTS_DEBUG
		fprintf(stderr, "    ** _dirtyJIDs.clear() in MetacontactsDirectory::storageMetacontacts_finishedSaveToServer()\n");
#endif
	}
}

void MetacontactsDirectory::saveToServerIfNeeded(void)
{
	if (needsToSaveToServer())
		saveToServer();
}

bool MetacontactsDirectory::needsToSaveToServer(void)
{
	return _needsToSaveToServer;
}

void MetacontactsDirectory::setNeedsToSaveToServer(bool flag)
{
	_needsToSaveToServer = flag;
	
	if (_saveTimer.isActive()) {
		_saveTimer.stop();
	}
	
	if (_needsToSaveToServer) {
		_saveTimer.setSingleShot(true);
		// Save only some seconds from now in order to try to get several changes
		// coalesced into a single larger update.
		_saveTimer.start(4000);
	}
}

bool MetacontactsDirectory::needsToUpdateFromServer (void)
{
	return _needsToUpdateFromServer;
}

void MetacontactsDirectory::setNeedsToUpdateFromServer (bool flag)
{
	_needsToUpdateFromServer = flag;
	
	if (_updateTimer.isActive()) {
		_updateTimer.stop();
	}
	
	if (_needsToUpdateFromServer) {
		_updateTimer.setSingleShot(true);
		// Update only some (mili)seconds from now in order to try to get several consecutive changes at once.
		_updateTimer.start(500);
		
#ifdef METACONTACTS_DEBUG
		fprintf(stderr,
				"    << MetacontactsDirectory::setNeedsToUpdateFromServer( flag = %s )\n", (flag ? "true" : "false"));
#endif
	}
}

const QString &	MetacontactsDirectory::tagForJID(const QString &jid)
{
	return _tagsByJID[jid];
}

void MetacontactsDirectory::setTagForJID(const QString &jid, const QString &tag)
{
	if (tag.compare(_tagsByJID[jid]) != 0) {
		if (tag.isEmpty()) {
			_tagsByJID.remove(jid);
		} else {
			_tagsByJID[jid] = tag;
		}
		setNeedsToSaveToServer(true);
		_dirtyJIDs << jid;
		
#ifdef METACONTACTS_DEBUG
		fprintf(stderr, "    ** _dirtyJIDs << %s in MetacontactsDirectory::setTagForJID(...)\n", qPrintable(jid));
		fprintf(stderr, "    -- _dirtyJIDs = ");
		foreach (QString str, _dirtyJIDs) {
			fprintf(stderr, "%s ", qPrintable(str));
		}
		fprintf(stderr, "\n");
#endif	
		
		emit metacontactInfoForJIDDidChange(jid, tag, orderForJID(jid));
	}
}

int MetacontactsDirectory::orderForJID(const QString &jid)
{
	return _orderByJID[jid];
}

void MetacontactsDirectory::setOrderForJID(const QString &jid, int order)
{
	if (order != _orderByJID[jid]) {
		if (order <= 0) {
			_orderByJID.remove(jid);
		} else {
			_orderByJID[jid] = order;
		}
		setNeedsToSaveToServer(true);
		_dirtyJIDs << jid;
		
#ifdef METACONTACTS_DEBUG
		fprintf(stderr, "    ** _dirtyJIDs << %s in MetacontactsDirectory::setOrderForJID(...)\n", qPrintable(jid));
		fprintf(stderr, "    -- _dirtyJIDs = ");
		foreach (QString str, _dirtyJIDs) {
			fprintf(stderr, "%s ", qPrintable(str));
		}
		fprintf(stderr, "\n");
#endif	
		
		emit metacontactInfoForJIDDidChange(jid, tagForJID(jid), order);
	}
}

void MetacontactsDirectory::setTagAndOrderForJID(const QString &jid, const QString &tag, int order)
{
	bool didChange = false;
	
	if (tag.compare(_tagsByJID[jid]) != 0) {
		if (tag.isEmpty()) {
			_tagsByJID.remove(jid);
		} else {
			_tagsByJID[jid] = tag;
		}
		didChange = true;
	}
	
	if (order != _orderByJID[jid]) {
		if (order <= 0) {
			_orderByJID.remove(jid);
		} else {
			_orderByJID[jid] = order;
		}
		didChange = true;
	}
	
	if (didChange) {
		setNeedsToSaveToServer(true);
		_dirtyJIDs << jid;
		
#ifdef METACONTACTS_DEBUG
		fprintf(stderr, "    ** _dirtyJIDs << %s in MetacontactsDirectory::setTagAndOrderForJID(...)\n", qPrintable(jid));
		fprintf(stderr, "    -- _dirtyJIDs = ");
		foreach (QString str, _dirtyJIDs) {
			fprintf(stderr, "%s ", qPrintable(str));
		}
		fprintf(stderr, "\n");
#endif	
		
		emit metacontactInfoForJIDDidChange(jid, tag, order);
	}
}

void MetacontactsDirectory::removeEntryForJID(const QString &jid)
{
	setTagAndOrderForJID(jid, "", 0);
}


