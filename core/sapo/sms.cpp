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


JT_PushSMSCredit::JT_PushSMSCredit(Task *parent) : Task(parent)
{
}

JT_PushSMSCredit::~JT_PushSMSCredit()
{
}

bool JT_PushSMSCredit::take(const QDomElement &elem)
{
	if (elem.tagName() == "iq" && elem.attribute("type") == "set") {
		QDomElement q = elem.firstChildElement("query");
		
		if (q.attribute("xmlns") == "sapo:sms") {
			
			QVariantMap creditProperties;
			
			// properties
			for(QDomNode node = q.firstChild(); !node.isNull(); node = node.nextSibling()) {
				QDomElement nodeElem = node.toElement();
				if(nodeElem.isNull())
					continue;
				
				creditProperties[nodeElem.tagName()] = ( nodeElem.hasChildNodes() ?
														 nodeElem.firstChild().toText().data() :
														 QString() );
			}
			
			emit credit_updated(creditProperties);
			
			// Send the reply (IQ result)
			QDomElement resultIQ = createIQ(doc(), "result", elem.attribute("from"), elem.attribute("id"));
			resultIQ.setAttribute("from", elem.attribute("to"));
			
			send(resultIQ);
			return true;
		}
	}
	
	return false;
}


#pragma mark -


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
	_pushSMSCreditListener = new JT_PushSMSCredit(client->rootTask());
	connect(_pushSMSCreditListener,
			SIGNAL(credit_updated(const QVariantMap &)),
			SLOT(pushSMSCredit_updated(const QVariantMap &)));
	
	_requestTimer = 0;
	
	_nrOfRequestAttemps = 0;
	_alreadyKnowsCredit = false;
	
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
	if (!_alreadyKnowsCredit) {
		_nrOfRequestAttemps = 0;
		cleanupTimer();
		
		if (_destinationJid.isValid()) {
			_requestTimer = new QTimer();
			connect(_requestTimer, SIGNAL(timeout()), SLOT(performNewRequestAttempt()));	
			_requestTimer->setSingleShot(true);
			_requestTimer->start(3000);
		}
	}
}


void SapoSMSCreditManager::clientDisconnected()
{
	cleanupTimer();
	_alreadyKnowsCredit = false;
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
		_alreadyKnowsCredit = true;
		
		emit creditUpdated(task->creditProperties());
	}
	else {
		// Delay this so that if we got an error because the client disconnected, the new attempt
		// will only try to run when everybody has already cleaned up.
		QTimer::singleShot(0, this, SLOT(performNewRequestAttempt()));
	}
}

void SapoSMSCreditManager::pushSMSCredit_updated(const QVariantMap &creditProperties)
{
	cleanupTimer();
	_alreadyKnowsCredit = true;
	
	emit creditUpdated(creditProperties);
}

