/*
 *  sapo_agents.cpp
 *
 *	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jpavao@co.sapo.pt>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informações sobre o licenciamento, leia o ficheiro README.
 */

#include "sapo_agents.h"
#include "xmpp_xmlcommon.h"
#include "im.h"


JT_SapoAgents::JT_SapoAgents(Task *parent)
: Task(parent)
{
}

void JT_SapoAgents::get(const Jid &jid)
{
	_jid = jid;
	_iq = createIQ(doc(), "get", jid.full(), id());
	QDomElement query = doc()->createElement("query");
	query.setAttribute("xmlns", "sapo:agents");
	query.setAttribute("version", "1");
	_iq.appendChild(query);
}

// return value structure: agentJIDStr -> propertyName -> value
const QMap<QString, QMap<QString, QString> > & JT_SapoAgents::agentsInfo() const
{
	return _agentsInfo;
}

void JT_SapoAgents::onGo()
{
	send(_iq);
}

bool JT_SapoAgents::take(const QDomElement &elem)
{
	if(!iqVerify(elem, _jid, id()))
		return false;
	
	if(elem.attribute("type") == "result") {
		QDomElement q = queryTag(elem);
		
		// agents
		for(QDomNode n1 = q.firstChild(); !n1.isNull(); n1 = n1.nextSibling()) {
			QDomElement i1 = n1.toElement();
			if(i1.isNull())
				continue;
			
			if(i1.tagName() == "agent") {
				QString agentJid = i1.attribute("jid");
				
				// agent properties
				for(QDomNode n2 = i1.firstChild(); !n2.isNull(); n2 = n2.nextSibling()) {
					QDomElement i2 = n2.toElement();
					if(i2.isNull())
						continue;
					
					_agentsInfo[agentJid][i2.tagName()] = ( i2.hasChildNodes() ?
															i2.firstChild().toText().data() :
															QString() );
				}
			}
		}
		setSuccess(true);
	} else {
		setError(elem);
	}
	
	return true;
}


#pragma mark -


SapoAgents::SapoAgents(ServerItemsInfo *serverInfo, Task *parentTask)
: _serverItemsInfo(serverInfo), _parentTask(parentTask)
{
	connect(serverInfo, SIGNAL(serverItemInfoUpdated(const QString &, const QString &, const QVariantList &, const QVariantList &)),
			SLOT(serverItemInfoUpdated(const QString &, const QString &, const QVariantList &, const QVariantList &)));
}

SapoAgents::~SapoAgents()
{
}

void SapoAgents::serverItemInfoUpdated(const QString &item, const QString &name, const QVariantList &identities, const QVariantList &features)
{
	Q_UNUSED(name);
	Q_UNUSED(identities);
	
	if (_cachedAgents.isEmpty() && features.contains("sapo:agents")) {
		// We don't have the sapo:agents map yet
		JT_SapoAgents *sapoAgents_task = new JT_SapoAgents(_parentTask);
		connect(sapoAgents_task, SIGNAL(finished()), SLOT(sapoAgentsTaskFinished()));
		sapoAgents_task->get(item);
		sapoAgents_task->go(true);
	}
}

void SapoAgents::sapoAgentsTaskFinished(void)
{
	JT_SapoAgents *task = (JT_SapoAgents *)sender();
	
	if (task->success()) {
		_cachedAgents.clear();
		
		const QMap<QString, QMap<QString, QString> > & agentsInfo = task->agentsInfo();
		
		// Convert the agents info to a QVariantMap
		foreach (QString agentName, agentsInfo.keys()) {
			_cachedAgents[agentName] = QVariantMap();
			QVariantMap &propsMap = (QVariantMap &)(_cachedAgents[agentName]);
			
			foreach (QString propertyKey, agentsInfo[agentName].keys()) {
				propsMap[propertyKey] = QVariant(agentsInfo[agentName][propertyKey]);
			}
		}
		
		emit sapoAgentsUpdated(_cachedAgents);
	}
}

