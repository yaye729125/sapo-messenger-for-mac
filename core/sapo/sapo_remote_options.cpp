/*
 *  sapo_remote_options.cpp
 *
 *	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jpavao@co.sapo.pt>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informações sobre o licenciamento, leia o ficheiro README.
 */

#include "sapo_remote_options.h"



JT_SapoRemoteOptions::JT_SapoRemoteOptions(Task *parent) : Task(parent)
{
}

JT_SapoRemoteOptions::~JT_SapoRemoteOptions()
{
}

void JT_SapoRemoteOptions::get()
{
	QDomElement iq = doc()->createElement("iq");
	QDomElement query = doc()->createElement("query");
	QDomElement x = doc()->createElement("x");
	
	iq.setAttribute("id", id());
	iq.setAttribute("type", "get");
	iq.appendChild(query);
	
	query.setAttribute("xmlns", "jabber:iq:private");
	query.appendChild(x);
	
	x.setAttribute("xmlns", "sapo:remote:options");
	
	_type = "get";
	_iq = iq;
}

void JT_SapoRemoteOptions::set(const QDomElement &xml)
{
	if (xml.tagName() == "x" && xml.attribute("xmlns") == "sapo:remote:options") {
		QDomElement iq = doc()->createElement("iq");
		QDomElement query = doc()->createElement("query");
		
		iq.setAttribute("id", id());
		iq.setAttribute("type", "set");
		iq.appendChild(query);
		
		query.setAttribute("xmlns", "jabber:iq:private");
		query.appendChild(xml);
		
		_type = "set";
		_iq = iq;
		_savedXML = xml;
	}
}

void JT_SapoRemoteOptions::onGo()
{
	send(_iq);
}

bool JT_SapoRemoteOptions::take (const QDomElement &stanza)
{
	if (stanza.tagName() == "iq" && stanza.attribute("id") == id()) {
		if (stanza.attribute("type") == "result") {
			if (_type == "get") {
				QDomElement query = stanza.firstChildElement("query");
				
				if (!query.isNull() && query.attribute("xmlns") == "jabber:iq:private") {
					QDomElement x = query.firstChildElement("x");
					
					if (!x.isNull() && x.attribute("xmlns") == "sapo:remote:options") {
						
						_savedXML = x;
						
						setSuccess();
						return true;
					}
				}
				setError();
			}
			else {
				setSuccess();
			}
		}
		else {
			setError();
		}
		return true;
	}
	return false;
}


#pragma mark -


SapoRemoteOptionsMgr::SapoRemoteOptionsMgr(Client *c)
{
	_client = c;
	connect(c, SIGNAL(activated()), SLOT(client_activated()));
}

SapoRemoteOptionsMgr::~SapoRemoteOptionsMgr()
{
}

void SapoRemoteOptionsMgr::setStatusMessage(const QString &status)
{
	if (!_remotelySavedXML.isNull() && status != _remotelySavedStatus) {
		_remotelySavedStatus = status;
		
		QDomElement presenceNode = _remotelySavedXML.firstChildElement("mod_presence");
		QDomElement oldStatusNode = presenceNode.firstChildElement("var_status");
		
		QDomElement newStatusNode = _client->doc()->createElement("var_status");
		QDomText newStatusNodeContents = _client->doc()->createTextNode(status);
		newStatusNode.appendChild(newStatusNodeContents);
		
		presenceNode.replaceChild(newStatusNode, oldStatusNode);
		
		setRemoteOptions(_remotelySavedXML);
	}
}

void SapoRemoteOptionsMgr::setStatus(const QString &show)
{
	if (!_remotelySavedXML.isNull() && show != _remotelySavedShow) {
		_remotelySavedShow = show;
		
		QDomElement presenceNode = _remotelySavedXML.firstChildElement("mod_presence");
		QDomElement oldShowNode = presenceNode.firstChildElement("var_show");
		
		QDomElement newShowNode = _client->doc()->createElement("var_show");
		QDomText newShowNodeContents = _client->doc()->createTextNode(show);
		newShowNode.appendChild(newShowNodeContents);
		
		presenceNode.replaceChild(newShowNode, oldShowNode);
		
		setRemoteOptions(_remotelySavedXML);
	}
}

void SapoRemoteOptionsMgr::setStatusAndMessage(const QString &show, const QString &status)
{
	if (!_remotelySavedXML.isNull() && (show != _remotelySavedShow || status != _remotelySavedStatus)) {
		_remotelySavedShow = show;
		_remotelySavedStatus = status;
		
		QDomElement presenceNode = _remotelySavedXML.firstChildElement("mod_presence");
		QDomElement oldStatusNode = presenceNode.firstChildElement("var_status");
		QDomElement oldShowNode = presenceNode.firstChildElement("var_show");
		
		QDomElement newShowNode = _client->doc()->createElement("var_show");
		QDomText newShowNodeContents = _client->doc()->createTextNode(show);
		newShowNode.appendChild(newShowNodeContents);
		
		presenceNode.replaceChild(newShowNode, oldShowNode);
		
		QDomElement newStatusNode = _client->doc()->createElement("var_status");
		QDomText newStatusNodeContents = _client->doc()->createTextNode(status);
		newStatusNode.appendChild(newStatusNodeContents);
		
		presenceNode.replaceChild(newStatusNode, oldStatusNode);
		
		
		setRemoteOptions(_remotelySavedXML);
	}
}

const QString & SapoRemoteOptionsMgr::statusMessage()
{
	return _remotelySavedStatus;
}

const QString & SapoRemoteOptionsMgr::status()
{
	return _remotelySavedShow;
}

void SapoRemoteOptionsMgr::client_activated()
{
	_remotelySavedXML.clear();
	_remotelySavedShow.clear();
	_remotelySavedStatus.clear();
	
	getRemoteOptions();
}

void SapoRemoteOptionsMgr::sapoRemoteOptions_get_finished()
{
	JT_SapoRemoteOptions *remoteOptionsTask = (JT_SapoRemoteOptions *)sender();
	
	if (remoteOptionsTask->success()) {
		_remotelySavedXML = remoteOptionsTask->savedXML();
		
		QDomElement presenceNode = _remotelySavedXML.firstChildElement("mod_presence");
		if (presenceNode.isNull()) {
			presenceNode = _client->doc()->createElement("mod_presence");
			_remotelySavedXML.appendChild(presenceNode);
		}
		
		QDomElement statusNode = presenceNode.firstChildElement("var_status");
		if (statusNode.isNull()) {
			statusNode = _client->doc()->createElement("var_status");
			presenceNode.appendChild(statusNode);
		}
		
		QDomElement showNode = presenceNode.firstChildElement("var_show");
		if (showNode.isNull()) {
			showNode = _client->doc()->createElement("var_show");
			presenceNode.appendChild(showNode);
		}
		
		
		_remotelySavedStatus = statusNode.text();
		_remotelySavedShow = showNode.text();
		
		emit remoteOptionsUpdated();
	}
}

void SapoRemoteOptionsMgr::getRemoteOptions ()
{
	JT_SapoRemoteOptions *task = new JT_SapoRemoteOptions(_client->rootTask());
	
	connect(task, SIGNAL(finished()), SLOT(sapoRemoteOptions_get_finished()));
	task->get();
	task->go(true);
}

void SapoRemoteOptionsMgr::setRemoteOptions (const QDomElement & xmlToSave)
{
	JT_SapoRemoteOptions *task = new JT_SapoRemoteOptions(_client->rootTask());
	
	task->set(xmlToSave);
	task->go(true);
}

