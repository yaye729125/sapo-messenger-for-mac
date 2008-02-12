/*
 *  transport_registration.h
 *
 *	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jpavao@co.sapo.pt>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informações sobre o licenciamento, leia o ficheiro README.
 */

#ifndef TRANSPORT_REGISTRATION_H
#define TRANSPORT_REGISTRATION_H


#include "im.h"


using namespace XMPP;


class JT_CheckTransportRegistration : public Task
{
public:
	JT_CheckTransportRegistration(Task *parent, const Jid & transport_jid);
	~JT_CheckTransportRegistration();
	
	Jid & transportJid (void) {
		return _transport_jid;
	}
	
	bool isRegistered (void) {
		return _isRegistered;
	}
	
	const QString & registeredUsername (void) {
		return _registeredUsername;
	}
	
private:
	void onGo();
	bool take(const QDomElement &elem);
	
	Jid _transport_jid;
	QDomElement _iq;
	bool _isRegistered;
	QString _registeredUsername;
};


namespace XMPP {
	class JT_Register;
}


class TransportRegistrationManager : public QObject
{
	Q_OBJECT
public:
	TransportRegistrationManager(Client *client, const QString &transportHost);
	~TransportRegistrationManager();
	
	const QString & transportHost (void)	{ return _transportHost;	}
	bool isRegistered (void)				{ return _registered;		}
	
	void checkRegistrationState (void);
	void registerTransport (const QString &username, const QString &password);
	void unregisterTransport (void);
	
signals:
	void registrationStatusChanged(bool newStatus, const QString &registeredUsername);
	void registrationFinished();
	void unregistrationFinished();

private slots:
	void transportRegistrationCheckFinished();
	void transportRegistrationFinished();
	void transportUnRegistrationFinished();

private:
	Client		*_client;
	QString		_transportHost;
	bool		_registered;
	QMap<JT_Register*,QString>	_usernamesForTasks;
};


#endif
