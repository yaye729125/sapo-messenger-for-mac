/*
 *  chat_rooms_browser.cpp
 *
 *	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jppavao@criticalsoftware.com>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
 */

#include "chat_rooms_browser.h"
#include "xmpp_tasks.h"


ChatRoomsBrowser::ChatRoomsBrowser(const QString &serverHost, Task *rootTask)
: _serverHost(serverHost), _rootTask(rootTask)
{
}

ChatRoomsBrowser::~ChatRoomsBrowser()
{
}

void ChatRoomsBrowser::getChatRoomsList(void)
{
	getDiscoItems(_serverHost);
}

void ChatRoomsBrowser::getDiscoItems(const QString &jid)
{
	JT_DiscoItems *ditems_task = new JT_DiscoItems(_rootTask);
	connect(ditems_task, SIGNAL(finished()), SLOT(discoItems_finished()));
	ditems_task->get(Jid(jid));
	ditems_task->go(true);
}

void ChatRoomsBrowser::discoItems_finished()
{
	JT_DiscoItems *ditems_task = (JT_DiscoItems *)sender();
	
	if (ditems_task->success()) {
		QVariantList items;
		foreach (DiscoItem ditem, ditems_task->items()) {
			//getDiscoInfo(ditem);
			
			QVariantMap roomInfo;
			roomInfo["name"] = ditem.name();
			roomInfo["jid"] = ditem.jid().full();
			
			items << QVariant(roomInfo);
		}
		emit chatRoomsListUpdated(items);
	}
}

void ChatRoomsBrowser::getDiscoInfo(DiscoItem &item)
{
	JT_DiscoInfo *dinfo_task = new JT_DiscoInfo(_rootTask);
	connect(dinfo_task, SIGNAL(finished()), SLOT(discoInfo_finished()));
	dinfo_task->get(item);
	dinfo_task->go(true);
}

void ChatRoomsBrowser::discoInfo_finished()
{
	JT_DiscoInfo *dinfo_task = (JT_DiscoInfo *)sender();
	
	if (dinfo_task->success()) {
		QVariantList features;
		foreach (QString feature, dinfo_task->item().features().list()) {
			features << feature;
		}
		emit serverItemFeaturesUpdated(dinfo_task->item().jid().full(), features);
	}
}
