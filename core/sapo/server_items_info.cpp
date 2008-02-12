/*
 *  server_items_info.cpp
 *
 *	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jpavao@co.sapo.pt>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informações sobre o licenciamento, leia o ficheiro README.
 */

#include "server_items_info.h"
#include "xmpp_tasks.h"


ServerItemsInfo::ServerItemsInfo(const QString &serverHost, Task *rootTask)
: _serverHost(serverHost), _rootTask(rootTask)
{
}

ServerItemsInfo::~ServerItemsInfo()
{
}

void ServerItemsInfo::getServerItemsInfo(void)
{
	getDiscoItems(_serverHost);
}

void ServerItemsInfo::getDiscoItems(const QString &jid)
{
	JT_DiscoItems *ditems_task = new JT_DiscoItems(_rootTask);
	connect(ditems_task, SIGNAL(finished()), SLOT(discoItems_finished()));
	ditems_task->get(Jid(jid));
	ditems_task->go(true);
}

void ServerItemsInfo::discoItems_finished()
{
	JT_DiscoItems *ditems_task = (JT_DiscoItems *)sender();
	
	if (ditems_task->success()) {
		QVariantList items;
		foreach (DiscoItem ditem, ditems_task->items()) {
			getDiscoInfo(ditem);
			items << QVariant(ditem.jid().full());
		}
		emit serverItemsUpdated(items);
	}
}

void ServerItemsInfo::getDiscoInfo(DiscoItem &item)
{
	JT_DiscoInfo *dinfo_task = new JT_DiscoInfo(_rootTask);
	connect(dinfo_task, SIGNAL(finished()), SLOT(discoInfo_finished()));
	dinfo_task->get(item);
	dinfo_task->go(true);
}

void ServerItemsInfo::discoInfo_finished()
{
	JT_DiscoInfo *dinfo_task = (JT_DiscoInfo *)sender();
	
	if (dinfo_task->success()) {
		
		// Pack the identities in a variant list of variant maps
		QVariantList identities;
		foreach (struct DiscoItem::Identity identity, dinfo_task->item().identities()) {
			QVariantMap identityMap;
			
			identityMap["name"] = identity.name;
			identityMap["category"] = identity.category;
			identityMap["type"] = identity.type;
			
			identities << identityMap;
		}
		
		// Pack the features in a variant list
		QVariantList features;
		foreach (QString feature, dinfo_task->item().features().list()) {
			features << feature;
		}
		
		emit serverItemInfoUpdated(dinfo_task->item().jid().full(), dinfo_task->item().name(), identities, features);
	}
}
