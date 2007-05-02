/*
 *  sapo_photo.cpp
 *
 *	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jppavao@criticalsoftware.com>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informações sobre o licenciamento, leia o ficheiro README.
 */

#include "sapo_photo.h"




// Long lines of encoded binary data SHOULD BE folded to 75 characters using the folding method defined in [MIME-DIR].
static QString foldString(const QString &s)
{
	QString ret;
	
	for (int i = 0; i < (int)s.length(); i++) {
		if ( !(i % 75) )
			ret += '\n';
		ret += s[i];
	}
	
	return ret;
}




JT_PushSapoPhoto::JT_PushSapoPhoto(Task *parent) : Task(parent)
{
}

JT_PushSapoPhoto::~JT_PushSapoPhoto()
{
}

bool JT_PushSapoPhoto::take (const QDomElement &stanza)
{
	if (stanza.tagName() == "iq" && stanza.attribute("type") == "get") {
		QDomElement queryElem = stanza.firstChildElement("query");
		
		if (queryElem.attribute("xmlns") == "sapo:photo") {
			// Send the reply
			QDomElement reply = doc()->createElement("iq");
			QDomElement query = doc()->createElement("query");
			QDomElement binary = doc()->createElement("binary");
			QDomText binaryText = doc()->createTextNode(_encodedSelfAvatarText);
			
			reply.setAttribute("from", stanza.attribute("to"));
			reply.setAttribute("to", stanza.attribute("from"));
			reply.setAttribute("type", "result");
			reply.setAttribute("id", stanza.attribute("id"));
			query.setAttribute("xmlns", "sapo:photo");
			
			reply.appendChild(query);
			query.appendChild(binary);
			binary.appendChild(binaryText);
			
			send(reply);
			return true;
		}
	}
	return false;
}


void JT_PushSapoPhoto::setSelfAvatar(const QPixmap &newAvatar)
{
	// Make a QByteArray out of our avatar pixmap
	QByteArray	avatarData;
	QBuffer		buffer(&avatarData);
	
	buffer.open(QIODevice::WriteOnly);
	newAvatar.save(&buffer, "PNG");
	
	setSelfAvatar(avatarData);
}


void JT_PushSapoPhoto::setSelfAvatar(const QByteArray &newAvatarData)
{
	_selfAvatarBytes = newAvatarData;
	
	// Save it encoded in base64, ready to be sent in replies
	_encodedSelfAvatarText = (newAvatarData.isEmpty() ? "" : foldString(newAvatarData.toBase64()));
}

JT_SapoPhoto::JT_SapoPhoto(Task *parent) : Task(parent)
{
}


JT_SapoPhoto::~JT_SapoPhoto()
{
}


void JT_SapoPhoto::get(const Jid &to)
{
	_opType = RequestFromJid;
	_to = to;
}

void JT_SapoPhoto::getSelf()
{
	_opType = RequestOwnAvatar;
}

void JT_SapoPhoto::setSelf(const QByteArray &avatarData)
{
	setSelf(foldString(avatarData.toBase64()));
}

void JT_SapoPhoto::setSelf(const QString &encodedAvatarData)
{
	_opType = SetOwnAvatar;
	_encodedAvatar = encodedAvatarData;
}


void JT_SapoPhoto::onGo()
{
	QDomElement iq = doc()->createElement("iq");
	QDomElement query = doc()->createElement("query");
	
	iq.setAttribute("id", id());
	iq.appendChild(query);
	
	if (_opType == RequestFromJid) {
		/*
		 <iq id='2' type='get' to='mramos29@sapo.pt/Picoas'> 
		 <query xmlns='sapo:photo' />
		 </iq> 
		 */
		iq.setAttribute("type", "get");
		iq.setAttribute("to", _to.full());
		query.setAttribute("xmlns", "sapo:photo");
	}
	else if (_opType == RequestOwnAvatar) {
		/*
		 <iq id="1" type="get">
		 <query xmlns="jabber:iq:private">
		 <x xmlns="sapo:photo" />
		 </query>
		 </iq>
		 */
		iq.setAttribute("type", "get");
		query.setAttribute("xmlns", "jabber:iq:private");
		
		QDomElement x = doc()->createElement("x");
		x.setAttribute("xmlns", "sapo:photo");
		
		query.appendChild(x);
	}
	else if (_opType == SetOwnAvatar) {
		/*
		 <iq id="1" type="set">
		 <query xmlns="jabber:iq:private">
		 <x xmlns="sapo:photo">
		 <binary>iVBORw0KG...</binary>
		 </x>
		 </query>
		 </iq> 
		 */
		iq.setAttribute("type", "set");
		query.setAttribute("xmlns", "jabber:iq:private");
		
		QDomElement x = doc()->createElement("x");
		x.setAttribute("xmlns", "sapo:photo");
		
		QDomElement binary = doc()->createElement("binary");
		QDomText binaryText = doc()->createTextNode(_encodedAvatar);
		
		query.appendChild(x);
		x.appendChild(binary);
		binary.appendChild(binaryText);
	}
	
	send(iq);
}


bool JT_SapoPhoto::take(const QDomElement &stanza)
{
	if (stanza.tagName() != "iq" || stanza.attribute("id") != id())
		return false;
	
	if (stanza.attribute("type") == "result") {
		if (_opType == RequestFromJid) {
			QDomElement	binaryElem = stanza.firstChildElement("query").firstChildElement("binary");
			QString		base64AvatarText = binaryElem.text();
			
			_receivedAvatarData = QByteArray::fromBase64(base64AvatarText.toAscii());
		}
		else if (_opType == RequestOwnAvatar) {
			QDomElement	binaryElem = stanza.firstChildElement("query").firstChildElement("x").firstChildElement("binary");
			QString		base64AvatarText = binaryElem.text();
			
			_receivedAvatarData = QByteArray::fromBase64(base64AvatarText.toAscii());
		}
		else if (_opType == SetOwnAvatar) {
			// do we need to do anything?
		}

		setSuccess();
		return true;
	}
	else if (stanza.attribute("type") == "error") {
		setError();
		return true;
	}
	else {
		return false;
	}
}

