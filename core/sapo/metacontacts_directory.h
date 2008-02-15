/*
 *  metacontacts_directory.h
 *
 *	Copyright (C) 2008 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jpavao@co.sapo.pt>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informações sobre o licenciamento, leia o ficheiro README.
 */

#ifndef METACONTACTS_DIRECTORY_H
#define METACONTACTS_DIRECTORY_H


#include <QtCore>
#include "im.h"


using namespace XMPP;


class JT_StorageMetacontacts : public Task
{
public:
	JT_StorageMetacontacts(Task *parent);
	~JT_StorageMetacontacts();
	
	typedef QMap<QString,QString> MetacontactJIDRecord;
	
	void get();
	void set(const QList<MetacontactJIDRecord> &metacontacts_list);
	
	const QList<MetacontactJIDRecord> &	metacontacts_list() { return _metacontacts_list; }
	
	bool take(const QDomElement &x);
	
protected:
	void onGo();
	
private:
	QString							_type;
	QDomElement						_iq;
	QList<MetacontactJIDRecord>		_metacontacts_list;
};


class MetacontactsDirectory : public QObject
{
	Q_OBJECT
	
public:
	MetacontactsDirectory(Client *c);
	~MetacontactsDirectory();
	
	void clear(void);
	void updateFromServer(void);
	void saveToServer(void);
	void saveToServerIfNeeded(void);
	
	const QString &	tagForJID(const QString &jid);
	void setTagForJID(const QString &jid, const QString &tag);
	int orderForJID(const QString &jid);
	void setOrderForJID(const QString &jid, int order);
	
protected:
	Client *client() { return _client; }
	
	Client					*_client;
	QMap<QString,QString>	_tagsByJID;
	QMap<QString,int>		_orderByJID;
	bool					_needsToSaveToServer;
	
protected slots:
	void storageMetacontacts_finishedUpdateFromServer (void);
	void storageMetacontacts_finishedSaveToServer (void);
	
signals:
	void finishedUpdateFromServer(bool success);
	void finishedSaveToServer(bool success);
	
	void metacontactInfoForJIDDidChange(const QString &jid, const QString &tag, int order);
};


#endif
