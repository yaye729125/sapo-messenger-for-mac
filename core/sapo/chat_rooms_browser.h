/*
 *  chat_rooms_browser.h
 *
 *	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jppavao@criticalsoftware.com>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informações sobre o licenciamento, leia o ficheiro README.
 */

#ifndef CHAT_ROOMS_BROWSER_H
#define CHAT_ROOMS_BROWSER_H

#include "im.h"
#include "xmpp_tasks.h"


using namespace XMPP;


class ChatRooms_DiscoInfo : public JT_DiscoInfo
{
public:
	ChatRooms_DiscoInfo(Task *t) : JT_DiscoInfo(t) { }
	bool take(const QDomElement &);
	const XData & xdata() const;
	
private:
	XData _xdata;
};


/*
 * Gets info about Chat rooms available on a given MUC services provider.
 */
class ChatRoomsBrowser : public QObject
{
	Q_OBJECT
	
public:
	ChatRoomsBrowser(Task *rootTask);
	~ChatRoomsBrowser();
	
	void getChatRoomsListOnHost(const QString &host);
	void getChatRoomInfo(const QString &room_jid);
	
signals:
	void chatRoomsListReceived(const QString &host, const QVariantList &rooms);
	void chatRoomInfoReceived(const QString &room_jid, const QVariantMap &info);
	
private:
	Task *_rootTask;
	
	void getDiscoItems(const QString &jid, const char *completion_callback_slot);
	void getDiscoInfo(const QString &jid, const char *completion_callback_slot);
	
private slots:
	void chatRoomsList_discoItems_finished();
	void chatRooms_discoInfo_finished();
};


#endif
