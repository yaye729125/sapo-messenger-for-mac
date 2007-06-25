/*
 *  sms.h
 *
 *	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jppavao@criticalsoftware.com>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informações sobre o licenciamento, leia o ficheiro README.
 */

#ifndef SMS_H
#define SMS_H


#include "im.h"

using namespace XMPP;


class JT_PushSMSCredit : public Task
{
	Q_OBJECT
	
public:
	JT_PushSMSCredit(Task *parent);
	~JT_PushSMSCredit();
	
private:
	bool take(const QDomElement &elem);
	
signals:
	void credit_updated (const QVariantMap &creditProperties);
};


class JT_GetSMSCredit : public Task
{
public:
	JT_GetSMSCredit(Task *parent, const Jid & to);
	~JT_GetSMSCredit();
	
	QVariantMap & creditProperties (void) {
		return _creditProperties;
	}
	
private:
	void onGo();
	bool take(const QDomElement &elem);
	
	Jid _jid;
	QDomElement _iq;
	QVariantMap _creditProperties;
};


class SapoSMSCreditManager : public QObject
{
	Q_OBJECT
	
public:
	SapoSMSCreditManager(Client *client);
	~SapoSMSCreditManager();
	
	const Jid & destinationJid() const;
	void setDestinationJid(const Jid &jid);
	
signals:
	void creditUpdated(const QVariantMap & creditProperties);
	
private slots:
	void startCreditFetchProcess();
	void clientDisconnected();
	void performNewRequestAttempt();
	void getCreditTask_finished();
	void pushSMSCredit_updated(const QVariantMap &creditProperties);
	
private:
	Client *_client;
	QTimer *_requestTimer;
	Jid _destinationJid;
	
	JT_PushSMSCredit *_pushSMSCreditListener;
	
	int _nrOfRequestAttemps;
	bool _alreadyKnowsCredit;
	
	void cleanupTimer();
};


#endif
