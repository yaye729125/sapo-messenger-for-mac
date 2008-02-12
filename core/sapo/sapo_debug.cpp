/*
 *  sapo_debug.cpp
 *
 *	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jpavao@co.sapo.pt>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informações sobre o licenciamento, leia o ficheiro README.
 */

#include "sapo_debug.h"



JT_SapoDebug::JT_SapoDebug(Task *parent) : Task(parent)
{
	_isDebugger = false;
}

JT_SapoDebug::~JT_SapoDebug()
{
}

void JT_SapoDebug::getDebuggerStatus(const Jid &toJID)
{
	QDomElement iq = doc()->createElement("iq");
	QDomElement query = doc()->createElement("query");
	
	iq.setAttribute("id", id());
	iq.setAttribute("type", "get");
	iq.setAttribute("to", toJID.bare());
	iq.appendChild(query);
	
	query.setAttribute("xmlns", "sapo:debug");
	query.setAttribute("version", "1");
	
	_iq = iq;
	_toJID = toJID;
}

void JT_SapoDebug::onGo()
{
	send(_iq);
}

bool JT_SapoDebug::take (const QDomElement &stanza)
{
	if (stanza.tagName() == "iq" && stanza.attribute("id") == id()
		&& _toJID.compare(Jid(stanza.attribute("from")), false))
	{
		QDomElement query = stanza.firstChildElement("query");
		
		if (!query.isNull() && query.attribute("xmlns") == "sapo:debug") {
			if (stanza.attribute("type") == "result") {
				_isDebugger = true;
			}
			else if (stanza.attribute("type") == "error") {
				_isDebugger = false;
			}
			setSuccess();
		}
		else {
			setError();
		}
		return true;
	}
	else {
		return false;
	}
}

