/*
 *  audibles.cpp
 *
 *	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jppavao@criticalsoftware.com>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
 */

#include "audibles.h"
#include "xmpp_xmlcommon.h"


JT_SapoAudible::JT_SapoAudible(Task *parent) : Task(parent)
{
}


JT_SapoAudible::~JT_SapoAudible()
{
}


void JT_SapoAudible::prepareIQBasedAudible(const Jid & toJID, const QString & audibleResourceName)
{
	_toJID = toJID;
	_iq = createIQ(doc(), "set", toJID.full(), id());
	QDomElement query = doc()->createElement("query");
	query.setAttribute("xmlns", "sapo:audible");
	QDomElement resNode = doc()->createElement("resource");
	QDomNode resText = doc()->createTextNode(audibleResourceName);
	
	_iq.appendChild(query);
	query.appendChild(resNode);
	resNode.appendChild(resText);
}


void JT_SapoAudible::onGo()
{
	send(_iq);
}


bool JT_SapoAudible::take(const QDomElement &elem)
{
	if(!iqVerify(elem, _toJID, id()))
		return false;
	
	if(elem.attribute("type") == "result") {
		setSuccess(true);
	} else {
		setError(elem);
	}
	
	return true;
}


#pragma mark -


JT_PushSapoAudible::JT_PushSapoAudible(Task *parent) : Task(parent)
{
}

JT_PushSapoAudible::~JT_PushSapoAudible()
{
}


bool JT_PushSapoAudible::take (const QDomElement &stanza)
{
	if (stanza.tagName() == "iq" && stanza.attribute("type") == "set") {
		QDomElement queryElem = stanza.firstChildElement("query");
		
		if (queryElem.attribute("xmlns") == "sapo:audible") {
			// Get the audible resource name
			QDomElement resElem = queryElem.firstChildElement("resource");
			QString audibleResourceName = resElem.text();
			
			emit audibleReceived(Jid(stanza.attribute("from")), audibleResourceName);
			
			// Send the reply (IQ result)
			QDomElement resultIQ = createIQ(doc(), "result", stanza.attribute("from"), stanza.attribute("id"));
			QDomElement query = doc()->createElement("query");
			query.setAttribute("xmlns", "sapo:audible");
			
			resultIQ.appendChild(query);
			
			send(resultIQ);
			return true;
		}
	}
	return false;
}

