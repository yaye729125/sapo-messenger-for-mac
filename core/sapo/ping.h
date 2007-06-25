/*
 *  ping.h
 *
 *	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jppavao@criticalsoftware.com>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informações sobre o licenciamento, leia o ficheiro README.
 */

#ifndef PING_H
#define PING_H


#include "im.h"

using namespace XMPP;


class JT_PushXmppPing : public Task
{
public:
	JT_PushXmppPing(Task *parent);
	~JT_PushXmppPing();
	
private:
	bool take(const QDomElement &elem);
};


#endif
