/*
 *  audibles.h
 *
 *	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jppavao@criticalsoftware.com>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informações sobre o licenciamento, leia o ficheiro README.
 */

#ifndef AUDIBLES_H
#define AUDIBLES_H


#include "im.h"

using namespace XMPP;


/* To send a sapo:audible */
class JT_SapoAudible : public Task
{
	Q_OBJECT
	
public:
	JT_SapoAudible(Task *parent);
	~JT_SapoAudible();
	
	void prepareIQBasedAudible(const Jid & toJID, const QString & audibleResourceName);
	
	void onGo();
	bool take(const QDomElement &elem);
	
private:
	Jid			_toJID;
	QDomElement _iq;
};


/* Listener that handles received sapo:audibles */
class JT_PushSapoAudible : public Task
{
	Q_OBJECT
public:
	JT_PushSapoAudible(Task *parent);
	~JT_PushSapoAudible();
	
	bool take(const QDomElement &x);
	
signals:
	void audibleReceived(const Jid & from, const QString & audibleResourceName);
};


#endif
