/*
 *  sapo_photo.h
 *
 *	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
 *	Author: Joao Pavao <jpavao@co.sapo.pt>
 *
 *	For more information on licensing, read the README file.
 *	Para mais informações sobre o licenciamento, leia o ficheiro README.
 */

#ifndef SAPO_PHOTO_H
#define SAPO_PHOTO_H

#include <QByteArray>

#include "im.h"
#include "psi-helpers/avatars.h"


/* Listener that replies to sapo:photo avatar requests from other peers */
class JT_PushSapoPhoto : public Task
{
	Q_OBJECT
public:
	JT_PushSapoPhoto(Task *parent);
	~JT_PushSapoPhoto();
	
	bool take(const QDomElement &x);
	void setSelfAvatar(const QPixmap &newAvatar);
	void setSelfAvatar(const QByteArray &newAvatarData);
	
	const QByteArray & selfAvatarBytes()		{ return _selfAvatarBytes;		 }
	const QString	 & encodedSelfAvatarText()	{ return _encodedSelfAvatarText; }
	
private:
	QByteArray	_selfAvatarBytes;
	QString		_encodedSelfAvatarText;
};


/* To make sapo:photo avatar requests to other peers */
class JT_SapoPhoto : public Task
{
	Q_OBJECT
	
	typedef enum {
		RequestFromJid,
		RequestOwnAvatar,
		SetOwnAvatar
	} OpType;
	
public:
	JT_SapoPhoto(Task *parent);
	~JT_SapoPhoto();
	
	// Define the operation that is to be performed
	void get(const Jid &to);
	void getSelf();
	void setSelf(const QByteArray &avatarData);
	void setSelf(const QString &encodedAvatarData);
	
	void onGo();
	bool take(const QDomElement &x);
	
	Jid			toJid()				 { return _to; }
	QByteArray	receivedAvatarData() { return _receivedAvatarData; }
	
private:
	OpType		_opType;
	Jid			_to;
	QString		_encodedAvatar;
	QByteArray	_receivedAvatarData;
};


#endif
