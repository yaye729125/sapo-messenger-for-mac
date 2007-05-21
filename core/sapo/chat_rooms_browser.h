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

using namespace XMPP;


/*
 * Similar to the ServerItemsInfo class in functionality (ChatRoomsBrowser also sends disco#items and disco#info requests to a given host)
 * but featuring an API specialized in dealing with the list of chat rooms.
*/
class ChatRoomsBrowser : public QObject
{
	Q_OBJECT
	
public:
	ChatRoomsBrowser(const QString &serverHost, Task *rootTask);
	~ChatRoomsBrowser();
	
	void getChatRoomsList(void);
	
signals:
	void chatRoomsListUpdated(const QVariantList &);
	void serverItemFeaturesUpdated(const QString &, const QVariantList &);
	
private:
	QString		_serverHost;
	Task		*_rootTask;
	
	void getDiscoItems(const QString &jid);
	void getDiscoInfo(DiscoItem &item);
	
private slots:
	void discoItems_finished();
	void discoInfo_finished();
};


#endif
