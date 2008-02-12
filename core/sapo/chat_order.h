/*
 *  chat_order.h
 *
 *	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jpavao@co.sapo.pt>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informações sobre o licenciamento, leia o ficheiro README.
 */

#ifndef CHAT_ORDER_H
#define CHAT_ORDER_H


#include "im.h"

using namespace XMPP;


class JT_SapoChatOrder : public Task
{
public:
	JT_SapoChatOrder(Task *parent, const Jid & to);
	~JT_SapoChatOrder();
	
	QVariantMap & orderMap (void) {
		return _orderMap;
	}
	
private:
	void onGo();
	bool take(const QDomElement &elem);
	
	Jid _jid;
	QDomElement _iq;
	QVariantMap _orderMap;
};


#endif
