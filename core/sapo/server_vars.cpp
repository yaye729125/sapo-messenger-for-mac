/*
 *  server_vars.cpp
 *
 *	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jppavao@criticalsoftware.com>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
 */

#include "server_vars.h"
#include "xmpp_xmlcommon.h"


JT_ServerVars::JT_ServerVars(Task *parent, const Jid & to)
: Task(parent)
{
	_jid = to;
	_iq = createIQ(doc(), "get", _jid.bare(), id());
	QDomElement query = doc()->createElement("query");
	query.setAttribute("xmlns", "http://messenger.sapo.pt/protocols/server-vars");
	query.setAttribute("appbrand", "SAPO");
	query.setAttribute("version", "1");
	_iq.appendChild(query);
}

JT_ServerVars::~JT_ServerVars()
{
}

void JT_ServerVars::onGo()
{
	send(_iq);
}

bool JT_ServerVars::take(const QDomElement &elem)
{
	if(!iqVerify(elem, _jid, id()))
		return false;
	
	if(elem.attribute("type") == "result") {
		QDomElement q = queryTag(elem);
		
		// Save all the variables
		for(QDomElement var = q.firstChildElement("variable");
			!var.isNull();
			var = var.nextSiblingElement("variable"))
		{
			QString variableName = var.attribute("name");
			QString variableValue = var.text();
			
			// Save it
			_varsValues[variableName] = QVariant(variableValue);
		}
		
		setSuccess(true);
	}
	else {
		setError(elem);
	}
	
	return true;
}
