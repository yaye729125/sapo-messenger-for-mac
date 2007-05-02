/*
 *  server_vars.h
 *
 *	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jppavao@criticalsoftware.com>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informações sobre o licenciamento, leia o ficheiro README.
 */

#ifndef SERVERVARS_H
#define SERVERVARS_H


#include "im.h"

using namespace XMPP;


class JT_ServerVars : public Task
{
public:
	JT_ServerVars(Task *parent, const Jid & to);
	~JT_ServerVars();
	
	QVariantMap & variablesValues (void) {
		return _varsValues;
	}
	
private:
	void onGo();
	bool take(const QDomElement &elem);
	
	Jid _jid;
	QDomElement _iq;
	QVariantMap _varsValues;
};


#endif
