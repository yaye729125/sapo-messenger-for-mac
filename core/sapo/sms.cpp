/*
 *  sms.cpp
 *
 *	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jppavao@criticalsoftware.com>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
 */

#include "sms.h"
#include "xmpp_xmlcommon.h"


JT_GetSMSCredit::JT_GetSMSCredit(Task *parent, const Jid & to)
: Task(parent)
{
	_jid = to;
	_iq = createIQ(doc(), "get", _jid.full(), id());
	QDomElement query = doc()->createElement("query");
	query.setAttribute("xmlns", "sapo:sms");
	_iq.appendChild(query);
}

JT_GetSMSCredit::~JT_GetSMSCredit()
{
}

void JT_GetSMSCredit::onGo()
{
	send(_iq);
}

bool JT_GetSMSCredit::take(const QDomElement &elem)
{
	if(!iqVerify(elem, _jid, id()))
		return false;
	
	if(elem.attribute("type") == "result") {
		QDomElement q = queryTag(elem);
		
		// properties
		for(QDomNode node = q.firstChild(); !node.isNull(); node = node.nextSibling()) {
			QDomElement nodeElem = node.toElement();
			if(nodeElem.isNull())
				continue;
			
			_creditProperties[nodeElem.tagName()] = ( nodeElem.hasChildNodes() ?
													  nodeElem.firstChild().toText().data() :
													  QString() );
		}
		setSuccess(true);
	}
	else {
		setError(elem);
	}
	
	return true;
}


#pragma mark -


SapoSMSCreditManager::SapoSMSCreditManager(Client *client)
: _client(client)
{
	_requestTimer = 0;
	
	connect(client, SIGNAL(activated()), SLOT(startCreditFetchProcess()));
	connect(client, SIGNAL(disconnected()), SLOT(clientDisconnected()));
}


SapoSMSCreditManager::~SapoSMSCreditManager()
{
	cleanupTimer();
}


const Jid & SapoSMSCreditManager::destinationJid() const
{
	return _destinationJid;
}


void SapoSMSCreditManager::setDestinationJid(const Jid &jid)
{
	if (!_destinationJid.isValid() || !(_destinationJid.compare(jid, false))) {
		_destinationJid = jid;
		startCreditFetchProcess();
	}
}


void SapoSMSCreditManager::cleanupTimer()
{
	if (_requestTimer) {
		delete _requestTimer;
		_requestTimer = 0;
	}
}


void SapoSMSCreditManager::startCreditFetchProcess()
{
	_nrOfRequestAttemps = 0;
	cleanupTimer();
	
	if (_destinationJid.isValid()) {
		_requestTimer = new QTimer();
		connect(_requestTimer, SIGNAL(timeout()), SLOT(performNewRequestAttempt()));	
		_requestTimer->setSingleShot(true);
		_requestTimer->start(3000);
	}
}


void SapoSMSCreditManager::clientDisconnected()
{
	cleanupTimer();
}


void SapoSMSCreditManager::performNewRequestAttempt()
{
	if (_client->isActive() && _requestTimer && _nrOfRequestAttemps < 3) {
		// Send the request
		++_nrOfRequestAttemps;
		
		JT_GetSMSCredit *getCreditTask = new JT_GetSMSCredit(_client->rootTask(), _destinationJid);
		connect(getCreditTask, SIGNAL(finished()), SLOT(getCreditTask_finished()));
		getCreditTask->go(true);
		
		// Setup the timer for a retry attempt some time from now
		_requestTimer->start(60000);
	}
}


void SapoSMSCreditManager::getCreditTask_finished()
{
	JT_GetSMSCredit *task = (JT_GetSMSCredit *)sender();
	
	if (task->success()) {
		cleanupTimer();
		emit creditUpdated(task->creditProperties());
	}
	else {
		// Delay this so that if we got an error because the client disconnected, the new attempt
		// will only try to run when everybody has already cleaned up.
		QTimer::singleShot(0, this, SLOT(performNewRequestAttempt()));
	}
}

