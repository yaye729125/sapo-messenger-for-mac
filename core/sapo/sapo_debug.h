/*
 *  sapo_debug.h
 *
 *	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jpavao@co.sapo.pt>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informações sobre o licenciamento, leia o ficheiro README.
 */

#ifndef SAPO_DEBUG_H
#define SAPO_DEBUG_H

#include "im.h"

using namespace XMPP;


class JT_SapoDebug : public Task
{
public:
	JT_SapoDebug(Task *parent);
	~JT_SapoDebug();
	
	void getDebuggerStatus(const Jid &toJID);
	
	bool isDebugger () { return _isDebugger; }
	
	bool take(const QDomElement &x);
	
protected:
	void onGo();
	
private:
	bool		_isDebugger;
	Jid			_toJID;
	QDomElement	_iq;
};


#endif
