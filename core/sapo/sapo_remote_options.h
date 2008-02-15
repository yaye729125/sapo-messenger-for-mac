/*
 *  sapo_remote_options.h
 *
 *	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jpavao@co.sapo.pt>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informações sobre o licenciamento, leia o ficheiro README.
 */

#ifndef SAPO_REMOTE_OPTIONS_H
#define SAPO_REMOTE_OPTIONS_H

#include "im.h"

using namespace XMPP;


class JT_SapoRemoteOptions : public Task
{
public:
	JT_SapoRemoteOptions(Task *parent);
	~JT_SapoRemoteOptions();
	
	void get();
	void set(const QDomElement &xml);
	
	const QDomElement &	savedXML() { return _savedXML; }
	
	bool take(const QDomElement &x);
	
protected:
	void onGo();
	
private:
	QString		_type;
	QDomElement	_iq;
	QDomElement	_savedXML;
};


class SapoRemoteOptionsMgr : public QObject
{
	Q_OBJECT
	
public:
	SapoRemoteOptionsMgr(Client *c);
	~SapoRemoteOptionsMgr();
	
	void setStatusMessage(const QString &status);
	void setStatus(const QString &show);
	void setStatusAndMessage(const QString &show, const QString &status);
	
	const QString & statusMessage();
	const QString & status();
	
signals:
	void remoteOptionsUpdated();
	
protected slots:
	void client_activated();
	void sapoRemoteOptions_get_finished();
	
protected:
	void getRemoteOptions ();
	void setRemoteOptions (const QDomElement & xmlToSave);
	
private:
	Client *_client;
	
	QDomElement _remotelySavedXML;
	QString _remotelySavedStatus;
	QString _remotelySavedShow;
};


#endif
