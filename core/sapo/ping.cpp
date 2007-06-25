/*
 *  ping.cpp
 *
 *	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jppavao@criticalsoftware.com>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
 */

#include "ping.h"
#include "xmpp_xmlcommon.h"


JT_PushXmppPing::JT_PushXmppPing(Task *parent) : Task(parent)
{
}

JT_PushXmppPing::~JT_PushXmppPing()
{
}


bool JT_PushXmppPing::take (const QDomElement &stanza)
{
	if (stanza.tagName() == "iq" && stanza.attribute("type") == "get"
		&& client()->jid().compare(Jid(stanza.attribute("to")), true))
	{
		QDomElement pingElem = stanza.firstChildElement("ping");
		
		if (pingElem.attribute("xmlns") == "urn:xmpp:ping") {
			
			// Send the reply (IQ result)
			QDomElement resultIQ = createIQ(doc(), "result", stanza.attribute("from"), stanza.attribute("id"));
			resultIQ.setAttribute("from", stanza.attribute("to"));
			
			send(resultIQ);
			return true;
		}
	}
	return false;
}
