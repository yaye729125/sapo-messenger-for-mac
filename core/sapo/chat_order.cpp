/*
 *  chat_order.cpp
 *
 *	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jpavao@co.sapo.pt>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informações sobre o licenciamento, leia o ficheiro README.
 */

#include "chat_order.h"
#include "xmpp_xmlcommon.h"


JT_SapoChatOrder::JT_SapoChatOrder(Task *parent, const Jid & to)
: Task(parent)
{
	_jid = to;
	_iq = createIQ(doc(), "get", _jid.bare(), id());
	QDomElement query = doc()->createElement("query");
	query.setAttribute("xmlns", "sapo:chat-order");
	query.setAttribute("version", "1");
	_iq.appendChild(query);
}

JT_SapoChatOrder::~JT_SapoChatOrder()
{
}

void JT_SapoChatOrder::onGo()
{
	send(_iq);
}

bool JT_SapoChatOrder::take(const QDomElement &elem)
{
	if(!iqVerify(elem, _jid, id()))
		return false;
	
	if(elem.attribute("type") == "result") {
		QDomElement q = queryTag(elem);
		
		_orderMap.clear();
		
		for (QDomElement domainNode = q.firstChildElement("domain");
			 !domainNode.isNull();
			 domainNode = domainNode.nextSiblingElement("domain"))
		{
			int weight = domainNode.attribute("weight").toInt();
			QString domainName = domainNode.text();
			
			_orderMap[domainName] = QVariant(weight);
		}
		
		setSuccess(true);
	}
	else {
		setError(elem);
	}
	
	return true;
}
