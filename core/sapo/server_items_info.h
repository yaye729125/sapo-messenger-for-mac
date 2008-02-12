/*
 *  server_items_info.h
 *
 *	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jpavao@co.sapo.pt>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informações sobre o licenciamento, leia o ficheiro README.
 */

#ifndef SERVER_ITEMS_INFO_H
#define SERVER_ITEMS_INFO_H

#include "im.h"

using namespace XMPP;


/* Receiver for server disco#items and their disco#info */
class ServerItemsInfo : public QObject
{
	Q_OBJECT
	
public:
	ServerItemsInfo(const QString &serverHost, Task *rootTask);
	~ServerItemsInfo();
	
	void getServerItemsInfo(void);
	
signals:
	void serverItemsUpdated(const QVariantList &);
	void serverItemInfoUpdated(const QString &, const QString &, const QVariantList &, const QVariantList &);
	
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
