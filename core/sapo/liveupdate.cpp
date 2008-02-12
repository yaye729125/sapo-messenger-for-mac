/*
 *  liveupdate.cpp
 *
 *	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jpavao@co.sapo.pt>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informações sobre o licenciamento, leia o ficheiro README.
 */

#include "liveupdate.h"
#include "xmpp_xmlcommon.h"


JT_SapoLiveUpdate::JT_SapoLiveUpdate(Task *parent, const Jid & to)
: Task(parent)
{
	_jid = to;
	_iq = createIQ(doc(), "get", _jid.bare(), id());
	QDomElement query = doc()->createElement("query");
	query.setAttribute("xmlns", "sapo:liveupdate");
	query.setAttribute("appbrand", "SAPO");
	query.setAttribute("platform", "MacOS");
	_iq.appendChild(query);
}

JT_SapoLiveUpdate::~JT_SapoLiveUpdate()
{
}

void JT_SapoLiveUpdate::onGo()
{
	send(_iq);
}

bool JT_SapoLiveUpdate::take(const QDomElement &elem)
{
	if(!iqVerify(elem, _jid, id()))
		return false;
	
	if(elem.attribute("type") == "result") {
		QDomElement q = queryTag(elem);
		QDomElement url = q.firstChildElement("url");
		
		_url = url.text();
		setSuccess(true);
	}
	else {
		setError(elem);
	}
	
	return true;
}
