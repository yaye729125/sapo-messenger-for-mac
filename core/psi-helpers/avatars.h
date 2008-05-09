/*
 * avatars.h
 * Copyright (C) 2006  Remko Troncon
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */

#ifndef AVATARS_H
#define AVATARS_H

#include <QPixmap>
#include <QMap>
#include <QByteArray>
#include <QString>

#include "iconset.h"
#include "vcardfactory.h"

class Avatar;
class VCardAvatar;
class VCardStaticAvatar;
class FileAvatar;
class SapoPhotoAvatar;
//class PEPAvatar;

class JT_PushSapoPhoto;


namespace XMPP {
	class Client;
	class Jid;
	class Resource;
	class RosterItem;
//	class PubSubItem;
}

using namespace XMPP;

//------------------------------------------------------------------------------

class AvatarFactory : public QObject
{
	Q_OBJECT

public:
	AvatarFactory(Client *c, VCardFactory *vcf);
	
	bool isSapoPhotoPublishingEnabled();
	void setSapoPhotoPublishingEnabled(bool flag);
	
	void reloadCachedHashes ();
	void saveCachedHashes ();
	
	QPixmap getAvatar(const Jid& jid);
	void removeAvatars(const Jid& jid);
	Client* client() const;
	VCardFactory* vCardFactory() const;
	void setSelfAvatar(const QByteArray& avatarData);
	void setSelfAvatar(const QString& fileName);

	void importManualAvatar(const Jid& j, const QString& fileName);
	void removeManualAvatar(const Jid& j);
	bool hasManualAvatar(const Jid& j);
	
	void setAvatarsDirs(const QString &customAvatarsDir, const QString &cachedAvatarsDir);
	QString getManualDir();
	QString getCacheDir();
	
	QString	selfSapoPhotoHash() const;
	QString	selfVCardPhotoHash() const;
	
signals:
	void avatarChanged(const Jid&);
	// Emitted when our avatar is received from the server, most probably right after getting connected.
	void selfAvatarChanged(const QByteArray &avatarData);
	void selfAvatarHashValuesChanged();

public slots:
	void updateAvatar(const Jid&);

protected slots:
//	void itemPublished(const Jid&, const QString&, const PubSubItem&);
//	void publish_success(const QString&, const PubSubItem&);
	void clientActivated();
	void receivedSelfSapoPhotoAvatar();
	void clientRosterItemAdded(const RosterItem &);
	void clientRosterItemRemoved(const RosterItem &);
	void clientResourceAvailable(const Jid&, const Resource&);
	void selfVCardChanged();

protected:
	Avatar* retrieveAvatar(const Jid& jid);


private:
	bool _isSapoPhotoPublishingEnabled;
	
	// This is used as temporary storage while we're waiting for our vCard to arrive for the first time
	// before we can change its photo.
	QByteArray pendingSelfAvatarVCardPhoto_;

	QString selfAvatarVCardHash_;
	QString selfAvatarSapoPhotoHash_;
	
	JT_PushSapoPhoto *_sapoPhotoPushTask;
	bool canProcessSelfSapoPhotoAvatar_;
	
	QMap<QString,QString> cached_sapoPhoto_hashes_;
	QMap<QString,QString> cached_vcard_hashes_;
	
	QMap<QString,Avatar*> active_avatars_;
//	QMap<QString,PEPAvatar*> pep_avatars_;
	QMap<QString,FileAvatar*> file_avatars_;
	QMap<QString,VCardAvatar*> vcard_avatars_;
	QMap<QString,VCardStaticAvatar*> vcard_static_avatars_;
	QMap<QString,SapoPhotoAvatar*> sapoPhoto_avatars_;
	Iconset iconset_;
	Client* client_;
	VCardFactory* vCardFactory_;

	QString customAvatarsDir_;
	QString cachedAvatarsDir_;
};

//------------------------------------------------------------------------------

class Avatar : public QObject
{
	Q_OBJECT
public:
	Avatar(AvatarFactory* factory);
	virtual ~Avatar();
	virtual QPixmap getPixmap()
		{ return pixmap(); }
	virtual bool isEmpty()
		{ return getPixmap().isNull(); }

protected:
	AvatarFactory* factory() const;
	virtual const QPixmap& pixmap() const 
		{ return pixmap_; }

	virtual void setImage(const QImage&);
	virtual void setImage(const QByteArray&);
	virtual void setImage(const QPixmap&);
	virtual void resetImage();

private:
	QPixmap pixmap_;
	AvatarFactory* factory_;
};


#endif
