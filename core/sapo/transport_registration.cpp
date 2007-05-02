/*
 *  transport_registration.cpp
 *
 *	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jppavao@criticalsoftware.com>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
 */

#include "transport_registration.h"
#include "xmpp_xmlcommon.h"
#include "xmpp_tasks.h"

JT_CheckTransportRegistration::JT_CheckTransportRegistration(Task *parent, const Jid & transport_jid)
: Task(parent)
{
	_transport_jid = transport_jid;
	_iq = createIQ(doc(), "get", _transport_jid.bare(), id());
	QDomElement query = doc()->createElement("query");
	query.setAttribute("xmlns", "jabber:iq:register");
	_iq.appendChild(query);
	_isRegistered = false;
	_registeredUsername = "";
}

JT_CheckTransportRegistration::~JT_CheckTransportRegistration()
{
}

void JT_CheckTransportRegistration::onGo()
{
	send(_iq);
}

bool JT_CheckTransportRegistration::take(const QDomElement &elem)
{
	if(!iqVerify(elem, _transport_jid, id()))
		return false;
	
	if(elem.attribute("type") == "result") {
		QDomElement q = queryTag(elem);
		QDomElement registered = q.firstChildElement("registered");
		QDomElement username = q.firstChildElement("username");
		
		_isRegistered = (!registered.isNull());
		_registeredUsername = (_isRegistered ? username.text() : "");
		
		setSuccess(true);
	}
	else {
		setError(elem);
	}
	
	return true;
}



TransportRegistrationManager::TransportRegistrationManager(Client *client, const QString &transportHost)
: QObject()
{
	_client = client;
	_transportHost = transportHost;
	_registered = false;
}

TransportRegistrationManager::~TransportRegistrationManager()
{
}

void TransportRegistrationManager::checkRegistrationState (void)
{
	JT_CheckTransportRegistration *registrationCheck = new JT_CheckTransportRegistration(_client->rootTask(), Jid(_transportHost));
	connect(registrationCheck, SIGNAL(finished()), SLOT(transportRegistrationCheckFinished()));
	registrationCheck->go(true);
}

void TransportRegistrationManager::transportRegistrationCheckFinished()
{
	JT_CheckTransportRegistration *registrationCheck = (JT_CheckTransportRegistration *)sender();
	
	if (registrationCheck->success()) {
		_registered = registrationCheck->isRegistered();
		emit registrationStatusChanged(_registered, registrationCheck->registeredUsername());
	}
}

void TransportRegistrationManager::registerTransport (const QString &username, const QString &password)
{
	JT_Register *registrationTask = new JT_Register(_client->rootTask());
	
	connect(registrationTask, SIGNAL(finished()), SLOT(transportRegistrationFinished()));
	
	registrationTask->reg(Jid(_transportHost), username, password);
	registrationTask->go(true);
	
	_usernamesForTasks[registrationTask] = username;
}

void TransportRegistrationManager::transportRegistrationFinished()
{
	JT_Register *task = (JT_Register *)sender();
	
	if (task->success()) {
		_registered = true;
		emit registrationStatusChanged(_registered, _usernamesForTasks[task]);
		emit registrationFinished();
	}
	
	_usernamesForTasks.remove(task);
}

void TransportRegistrationManager::unregisterTransport (void)
{
	JT_Register *registrationTask = new JT_Register(_client->rootTask());
	
	connect(registrationTask, SIGNAL(finished()), SLOT(transportUnRegistrationFinished()));
	
	registrationTask->unreg(Jid(_transportHost));
	registrationTask->go(true);
}

void TransportRegistrationManager::transportUnRegistrationFinished()
{
	JT_Register *task = (JT_Register *)sender();
	
	if (task->success()) {
		_registered = false;
		emit registrationStatusChanged(_registered, "");
		emit unregistrationFinished();
	}
}
