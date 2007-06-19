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


bool ChatRooms_DiscoInfo::take(const QDomElement &x)
{
	if(!iqVerify(x, jid(), id()))
		return false;
	
	if(x.attribute("type") == "result") {
		
		// Grab XData form data in addition to what's already parsed by JT_DiscoInfo
		
		for (QDomElement xdata_elem = x.firstChildElement("query").firstChildElement("x");
			 !xdata_elem.isNull();
			 xdata_elem = xdata_elem.nextSiblingElement("x"))
		{
			if (xdata_elem.attribute("xmlns") == "jabber:x:data") {
				_xdata.fromXml(xdata_elem);
				break;
			}
		}
	}
	
	return JT_DiscoInfo::take(x);
}

const XData & ChatRooms_DiscoInfo::xdata() const
{
	return _xdata;
}


#pragma mark -


ChatRoomsBrowser::ChatRoomsBrowser(Task *rootTask)
: _rootTask(rootTask)
{
}

ChatRoomsBrowser::~ChatRoomsBrowser()
{
}

void ChatRoomsBrowser::getChatRoomsListOnHost(const QString &host)
{
	getDiscoItems(host, SLOT(chatRoomsList_discoItems_finished()));
}

void ChatRoomsBrowser::getChatRoomInfo(const QString &room_jid)
{
	getDiscoInfo(room_jid, SLOT(chatRooms_discoInfo_finished()));
}

#pragma mark -

void ChatRoomsBrowser::getDiscoItems(const QString &jid, const char *completion_callback_slot)
{
	JT_DiscoItems *ditems_task = new JT_DiscoItems(_rootTask);
	connect(ditems_task, SIGNAL(finished()), completion_callback_slot);
	ditems_task->get(Jid(jid));
	ditems_task->go(true);
}

void ChatRoomsBrowser::chatRoomsList_discoItems_finished()
{
	JT_DiscoItems *ditems_task = (JT_DiscoItems *)sender();
	
	if (ditems_task->success()) {
		QVariantList items;
		QString host;
		
		// We assume that all the rooms are on the very same host where the disco#items result
		// is coming from:
		if (ditems_task->items().count() > 0)
			host = ditems_task->items().first().jid().domain();
		
		foreach (DiscoItem ditem, ditems_task->items()) {
			QVariantMap roomInfo;
			roomInfo["name"] = ditem.name();
			roomInfo["jid"] = ditem.jid().full();
			
			items << QVariant(roomInfo);
			
			// Kick off a disco#info request for this chat room right away
			getChatRoomInfo(ditem.jid().full());
		}
		emit chatRoomsListReceived(host, items);
	}
}

#pragma mark -

void ChatRoomsBrowser::getDiscoInfo(const QString &jid, const char *completion_callback_slot)
{
	ChatRooms_DiscoInfo *dinfo_task = new ChatRooms_DiscoInfo(_rootTask);
	connect(dinfo_task, SIGNAL(finished()), completion_callback_slot);
	dinfo_task->get(jid);
	dinfo_task->go(true);
}

void ChatRoomsBrowser::chatRooms_discoInfo_finished()
{
	ChatRooms_DiscoInfo *dinfo_task = (ChatRooms_DiscoInfo *)sender();
	
	if (dinfo_task->success()) {
		const DiscoItem &item = dinfo_task->item();
		QVariantMap roomInfo;
		
		roomInfo["name"]     = item.name();
		roomInfo["jid"]      = item.jid().full();
		roomInfo["category"] = item.identities().first().category;
		roomInfo["type"]     = item.identities().first().type;
		
		// Compile a list of features
		QVariantList features;
		foreach (QString feature, item.features().list()) {
			features << feature;
		}
		roomInfo["features"] = features;
		
		// Get stuff from the XData form
		foreach (XData::Field field, dinfo_task->xdata().fields()) {
			QString		key(QString(field.var()).replace("muc#", "muc_"));
			QString		value(field.value().first());
			bool		is_int = false;
			int			int_value = value.toInt(&is_int);
			
			if (is_int)
				roomInfo[key] = int_value;
			else
				roomInfo[key] = value;
		}
		
		emit chatRoomInfoReceived(item.jid().full(), roomInfo);
	}
}
