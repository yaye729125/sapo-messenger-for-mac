/*
 *  sapo_agents.h
 *
 *	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jpavao@co.sapo.pt>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informações sobre o licenciamento, leia o ficheiro README.
 */

#ifndef SAPO_AGENTS_H
#define SAPO_AGENTS_H

#include "im.h"
#include "server_items_info.h"

using namespace XMPP;


class JT_SapoAgents : public Task
{
	Q_OBJECT
	
public:
	JT_SapoAgents(Task *parent);
	void get(const Jid &);
	
	// return value structure: agentJIDStr -> propertyName -> value
	const QMap<QString, QMap<QString, QString> > & agentsInfo() const;
	
	void onGo();
	bool take(const QDomElement &elem);
	
private:
	QDomElement		_iq;
	Jid				_jid;
	QMap<QString, QMap<QString, QString> >  _agentsInfo;
};


/* Manager for the SAPO:AGENTS info */
class SapoAgents : public QObject
{
	Q_OBJECT
	
public:
	SapoAgents(ServerItemsInfo *serverInfo, Task *parentTask);
	~SapoAgents();
	
public slots:
	void serverItemInfoUpdated(const QString &item, const QString &name, const QVariantList &identities, const QVariantList &features);
	void sapoAgentsTaskFinished(void);
	
signals:
	void sapoAgentsUpdated(const QVariantMap &agents);
	
private:
	ServerItemsInfo *_serverItemsInfo;
	Task *_parentTask;
	QVariantMap _cachedAgents;
};


#endif
