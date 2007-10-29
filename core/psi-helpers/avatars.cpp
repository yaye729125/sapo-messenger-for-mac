/*
 * avatars.cpp 
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

/*
 * TODO:
 * - Be more efficient about storing avatars in memory
 * - Move ovotorChanged() to Avatar, and only listen to the active avatars
 *   being changed.
 */

#include <QDomElement>
#include <QtCrypto>
#include <QPixmap>
#include <QDateTime>
#include <QFile>
#include <QBuffer>
#include <QPainter>

#include <zlib.h>

#include "xmpp.h"
#include "xmpp_xmlcommon.h"
#include "xmpp_vcard.h"
#include "avatars.h"
#include "vcardfactory.h"
//#include "pepmanager.h"
#include "sapo/sapo_photo.h"

#include "psi-core/src/pixmaputil.h"

#define MAX_AVATAR_SIZE 96
#define MAX_AVATAR_DISPLAY_SIZE 64

using namespace QCA;

//------------------------------------------------------------------------------

static QByteArray scaleAvatar(const QByteArray& b)	
{
	//int maxSize = (option.avatarsSize > MAX_AVATAR_SIZE ? MAX_AVATAR_SIZE : option.avatarsSize);
	int maxSize = MAX_AVATAR_SIZE;
	QImage i(b);
	if (i.isNull()) {
		qWarning("AvatarFactory::scaleAvatar(): Null image (unrecognized format?)");
		return QByteArray();
	}
	else if (i.width() > maxSize || i.height() > maxSize) {
		QImage image = i.scaled(maxSize,maxSize,Qt::KeepAspectRatio,Qt::SmoothTransformation);
		QByteArray ba;
		QBuffer buffer(&ba);
		buffer.open(QIODevice::WriteOnly);
		image.save(&buffer, "PNG");
		return ba;
	}
	else {
		return b;
	}
}

//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//  Avatar: Base class for avatars.
//------------------------------------------------------------------------------

Avatar::Avatar(AvatarFactory* factory)
	: QObject(factory), factory_(factory)
{
}


Avatar::~Avatar()
{
}

void Avatar::setImage(const QImage& i)
{
	if (i.isNull())
		pixmap_ = QPixmap();
	else if (i.width() > MAX_AVATAR_DISPLAY_SIZE || i.height() > MAX_AVATAR_DISPLAY_SIZE)
		pixmap_.convertFromImage(i.scaled(MAX_AVATAR_DISPLAY_SIZE,MAX_AVATAR_DISPLAY_SIZE,Qt::KeepAspectRatio,Qt::SmoothTransformation));
	else
		pixmap_.convertFromImage(i);
}

void Avatar::setImage(const QByteArray& ba)
{
	setImage(QImage(ba));
}

void Avatar::setImage(const QPixmap& p)
{
	if (p.width() > MAX_AVATAR_DISPLAY_SIZE || p.height() > MAX_AVATAR_DISPLAY_SIZE)
		pixmap_ = p.scaled(MAX_AVATAR_DISPLAY_SIZE,MAX_AVATAR_DISPLAY_SIZE,Qt::KeepAspectRatio,Qt::SmoothTransformation);
	else
		pixmap_ = p;
}

void Avatar::resetImage()
{
	pixmap_ = QPixmap();
}

AvatarFactory* Avatar::factory() const
{
	return factory_;
}

//------------------------------------------------------------------------------
// CachedAvatar: Base class for avatars which are requested and are to be cached
//------------------------------------------------------------------------------

class CachedAvatar : public Avatar
{
public:
	CachedAvatar(AvatarFactory* factory)
		: Avatar(factory)
	{ };
	virtual void updateHash(const QString& h);

protected:
	virtual const QString& currentHash() const { return currentHash_; }
	virtual const QString& targetHash() const { return targetHash_; }
	
	virtual void setCurrentHash(const QString & hash) { currentHash_ = hash; }
	
	virtual void requestAvatar() { }
	virtual void avatarUpdated() { }
	
	virtual bool isCached(const QString& hash);
	virtual void loadFromCache(const QString& hash);
	virtual void saveToCache(const QString& hash, const QByteArray& data);

private:
	QString currentHash_;
	QString targetHash_;
};


void CachedAvatar::updateHash(const QString& h)
{
	if (currentHash_ != h)	{
		if (h.isEmpty()) {
			currentHash_ = "";
			targetHash_ = "";
			resetImage();
			avatarUpdated();
		}
		else if (isCached(h)) {
			currentHash_ = h;
			targetHash_ = h;
			loadFromCache(h);
			avatarUpdated();
		}
		else {
			/*
			 * Psi contains the following two lines, but it's better to keep the previous avatar
			 * until the new one is received. This is needed for sapo:photo avatars because they
			 * are only stored in the avatars iconset and are not available anywhere else in the
			 * application. If we reset the image, then we would temporarily get a generic icon
			 * in the GUI while the new icon was requested and received.
			 */
			// resetImage();
			// avatarUpdated();
			
			targetHash_ = h;
			requestAvatar();
		}
	}
}

bool CachedAvatar::isCached(const QString& h)
{
	return QDir(AvatarFactory::getCacheDir()).exists(h);
}

void CachedAvatar::loadFromCache(const QString& h)
{
	// printf("Loading avatar from cache\n");
	setImage(QImage(QDir(AvatarFactory::getCacheDir()).filePath(h)));
	
//	if (pixmap().isNull()) {
//		qWarning("CachedAvatar::loadFromCache(): Null pixmap. Unsupported format ?");
//	}
}

void CachedAvatar::saveToCache(const QString& hash, const QByteArray& data)
{
	// Write file to cache
	// printf("Saving %s to cache.\n",hash.latin1());
	QString fn = QDir(AvatarFactory::getCacheDir()).filePath(hash);
	QFile f(fn);
	if (f.open(IO_WriteOnly)) {
		f.writeBlock(data);
		f.close();
	}
	else
		printf("Error opening \"%s\" for writing.\n",f.name().latin1());
	
}

//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//  PEPAvatar: PEP Avatars
//------------------------------------------------------------------------------

//class PEPAvatar : public CachedAvatar
//{
//	Q_OBJECT
//
//public:
//	PEPAvatar(AvatarFactory* factory, const Jid& jid)
//		: CachedAvatar(factory), jid_(jid)
//	{ };
//	
//	void setData(const QString& h, const QString& data) {
//		if (h == hash()) {
//			QByteArray ba = Base64().stringToArray(data).toByteArray();
//			if (!ba.isEmpty()) {
//				saveToCache(hash(),ba);
//				setImage(ba);
//				if (pixmap().isNull()) {
//					qWarning("PEPAvatar::setData(): Null pixmap. Unsupported format ?");
//				}
//				emit avatarChanged(jid_);
//			}
//			else 
//				qWarning("PEPAvatar::setData(): Received data is empty. Bad encoding ?");
//		}
//	}
//	
//signals:
//	void avatarChanged(const Jid&);
//
//protected:
//	void requestAvatar() {
//		factory()->account()->pepManager()->get(jid_,"http://jabber.org/protocol/avatar#data",hash());
//	}
//
//	void avatarUpdated() 
//		{ emit avatarChanged(jid_); }
//
//private:
//	Jid jid_;
//};

//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// VCardAvatar: Avatars coming from VCards of contacts.
//------------------------------------------------------------------------------

class VCardAvatar : public CachedAvatar
{
	Q_OBJECT

public:
	VCardAvatar(AvatarFactory* factory, const Jid& jid);

signals:
	void avatarChanged(const Jid&);

public slots:
	void receivedVCard();

protected:
	void requestAvatar();
	void avatarUpdated() 
		{ emit avatarChanged(jid_); }

private:
	Jid jid_;
	
	QMap<JT_VCard*, QString> pendingTasksHashes_;
};


VCardAvatar::VCardAvatar(AvatarFactory* factory, const Jid& jid)
	: CachedAvatar(factory), jid_(jid)
{
}

void VCardAvatar::requestAvatar()
{
	// Are we already downloading the requested avatar? If so, bail out.
	foreach (QString hashInProgress, pendingTasksHashes_.values())
		if (hashInProgress == targetHash())
			return;
	
	
	JT_VCard *vCardTask = factory()->vCardFactory()->getVCard(jid_.bare(),factory()->client()->rootTask(), this, SLOT(receivedVCard()));
	pendingTasksHashes_[vCardTask] = targetHash();
}

void VCardAvatar::receivedVCard()
{
	JT_VCard *vCardTask = (JT_VCard *)sender();
	
	const VCard* vcard = factory()->vCardFactory()->vcard(jid_);
	if (vcard && !vcard->photo().isEmpty()) {
		QString &hash = pendingTasksHashes_[vCardTask];
		
		saveToCache(hash, vcard->photo());
		
		if (hash == targetHash()) {
			setCurrentHash(hash);
			setImage(vcard->photo());
			emit avatarChanged(jid_);
		}
	}
	
	pendingTasksHashes_.remove(vCardTask);
}

//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// VCardStaticAvatar: VCard static photo avatar (not published through presence)
//------------------------------------------------------------------------------

class VCardStaticAvatar : public Avatar
{
	Q_OBJECT

public:
	VCardStaticAvatar(AvatarFactory* factory, const Jid& j);

public slots:
	void vcardChanged(const Jid&);

signals:
	void avatarChanged(const Jid&);

private:
	Jid jid_;
};


VCardStaticAvatar::VCardStaticAvatar(AvatarFactory* factory, const Jid& j)
	: Avatar(factory), jid_(j.bare())
{ 
	const VCard* vcard = Avatar::factory()->vCardFactory()->vcard(jid_);
	if (vcard && !vcard->photo().isEmpty())
		setImage(vcard->photo());
	connect(Avatar::factory()->vCardFactory(), SIGNAL(vcardChanged(const Jid&)), SLOT(vcardChanged(const Jid&)));
}

void VCardStaticAvatar::vcardChanged(const Jid& j)
{
	if (j.compare(jid_,false)) {
		const VCard* vcard = factory()->vCardFactory()->vcard(jid_);
		if (vcard && !vcard->photo().isEmpty())
			setImage(vcard->photo());
		else
			resetImage();
		emit avatarChanged(jid_);
	}
}

//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// FileAvatar: Avatars coming from local files.
//------------------------------------------------------------------------------

class FileAvatar : public Avatar
{
public:
	FileAvatar(AvatarFactory* factory, const Jid& jid);
	void import(const QString& file);
	void removeFromDisk();
	bool exists();
	QPixmap getPixmap();
	const Jid& getJid() const
		{ return jid_; }

protected:
	bool isDirty() const;
	QString getFileName() const;
	void refresh();
	QDateTime lastModified() const
		{ return lastModified_; }

private:
	QDateTime lastModified_;
	Jid jid_;
};


FileAvatar::FileAvatar(AvatarFactory* factory, const Jid& jid)
	: Avatar(factory), jid_(jid)
{
}

void FileAvatar::import(const QString& file)
{
	if (QFileInfo(file).exists()) {
		QFile source_file(file);
		QFile target_file(getFileName());
		if (source_file.open(QIODevice::ReadOnly) && target_file.open(QIODevice::WriteOnly)) {
			QByteArray ba = source_file.readAll();
			QByteArray data = scaleAvatar(ba);
			target_file.write(data);
		}
	}
}

void FileAvatar::removeFromDisk()
{
	QFile f(getFileName());
	f.remove();
}

bool FileAvatar::exists()
{
	return QFileInfo(getFileName()).exists();
}

QPixmap FileAvatar::getPixmap()
{
	refresh();
	return pixmap();
}

void FileAvatar::refresh()
{
	if (isDirty()) {
		if (QFileInfo(getFileName()).exists()) {
			QImage img(getFileName());
			setImage(QImage(getFileName()));
		}
		else
			resetImage();
	}
}


QString FileAvatar::getFileName() const
{
	QString f = getJid().bare();
	f.replace('@',"_at_");
	return QDir(AvatarFactory::getManualDir()).filePath(f);
}


bool FileAvatar::isDirty() const
{
	return (pixmap().isNull()
			|| !QFileInfo(getFileName()).exists()
			|| QFileInfo(getFileName()).lastModified() > lastModified());
}


//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// SapoPhotoAvatar: sapo:photo-based avatars
//------------------------------------------------------------------------------


class SapoPhotoAvatar : public CachedAvatar
{
	Q_OBJECT
	
public:
	SapoPhotoAvatar(AvatarFactory* factory, const Jid& jid);
	
	const QString & resource() {
		return jid_.resource();
	}
	void setResource(const QString & newResource) {
		jid_ = jid_.withResource(newResource);
	}
	
signals:
	void avatarChanged(const Jid&);
	
public slots:
	void receivedSapoPhoto();
	
protected:
	void requestAvatar();
	void avatarUpdated() 
	{ emit avatarChanged(jid_); }
	
private:
	Jid jid_;
	QMap<JT_SapoPhoto*, QString> pendingTasksHashes_;
};


SapoPhotoAvatar::SapoPhotoAvatar(AvatarFactory* factory, const Jid& jid) : CachedAvatar(factory), jid_(jid)
{
}

void SapoPhotoAvatar::requestAvatar()
{
	// Do we have a resource yet? We need it for sapo:photo.
	if (jid_.resource().isEmpty())
		return;
	
	// Are we already downloading the requested avatar? If so, bail out.
	foreach (QString hashInProgress, pendingTasksHashes_.values())
		if (hashInProgress == targetHash())
			return;
	
	
	JT_SapoPhoto *sapoPhotoTask = new JT_SapoPhoto(factory()->client()->rootTask());
	
	pendingTasksHashes_[sapoPhotoTask] = targetHash();
	
	connect(sapoPhotoTask, SIGNAL(finished()), SLOT(receivedSapoPhoto()));
	sapoPhotoTask->get(jid_);
	sapoPhotoTask->go(true);
}

void SapoPhotoAvatar::receivedSapoPhoto()
{
	JT_SapoPhoto *sapoPhotoTask = (JT_SapoPhoto *)sender();
	QByteArray receivedAvatarData = sapoPhotoTask->receivedAvatarData();
	
	if (!(receivedAvatarData.isEmpty())) {
		QString &hash = pendingTasksHashes_[sapoPhotoTask];
		
		saveToCache(hash, receivedAvatarData);
		
		if (hash == targetHash()) {
			setCurrentHash(hash);
			setImage(receivedAvatarData);
			emit avatarChanged(jid_);
		}
	}
	
	pendingTasksHashes_.remove(sapoPhotoTask);
}


//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// Avatar factory
//------------------------------------------------------------------------------

AvatarFactory::AvatarFactory(Client* c, VCardFactory *vcf) : client_(c), vCardFactory_(vcf)
{
	_isSapoPhotoPublishingEnabled = false;
	
	// Register iconset
	iconset_.addToFactory();

	// Connect signals
	connect(vCardFactory_, SIGNAL(vcardChanged(const Jid&)), SLOT(updateAvatar(const Jid&)));
	connect(vCardFactory_, SIGNAL(selfVCardChanged()), SLOT(selfVCardChanged()));

	connect(client_, SIGNAL(activated()), SLOT(clientActivated()));
	connect(client_, SIGNAL(disconnected()), SLOT(clientDisconnected()));
	connect(client_, SIGNAL(rosterItemAdded(const RosterItem &)), SLOT(clientRosterItemAdded(const RosterItem &)));
	connect(client_, SIGNAL(rosterItemRemoved(const RosterItem &)), SLOT(clientRosterItemRemoved(const RosterItem &)));
	connect(client_, SIGNAL(resourceAvailable(const Jid &, const Resource &)),
			SLOT(clientResourceAvailable(const Jid &, const Resource &)));
	
	reloadCachedHashes();
	
	// sapo:photo
	_sapoPhotoPushTask = new JT_PushSapoPhoto(client()->rootTask());
	
	pendingSelfAvatarVCardPhoto_ = QByteArray();
	selfAvatarVCardHash_ = "";
	selfAvatarSapoPhotoHash_ = "";
	
//	// PEP
//	QStringList nodes;
//	nodes += "http://jabber.org/protocol/avatar#data";
//	nodes += "http://jabber.org/protocol/avatar#metadata";
//	pa_->pepManager()->registerNodes(nodes);
//	connect(pa_->pepManager(),SIGNAL(itemPublished(const Jid&, const QString&, const PubSubItem&)),SLOT(itemPublished(const Jid&, const QString&, const PubSubItem&)));
//	connect(pa_->pepManager(),SIGNAL(publish_success(const QString&, const PubSubItem&)),SLOT(publish_success(const QString&,const PubSubItem&)));
}

bool AvatarFactory::isSapoPhotoPublishingEnabled()
{
	return _isSapoPhotoPublishingEnabled;
}

void AvatarFactory::setSapoPhotoPublishingEnabled(bool flag)
{
	_isSapoPhotoPublishingEnabled = flag;
}

inline static QPixmap ensureSquareAvatar(const QPixmap& original)
{
	if (original.isNull() || original.width() == original.height())
		return original;

	int size = qMax(original.width(), original.height());
	QPixmap square = PixmapUtil::createTransparentPixmap(size, size);

	QPainter p(&square);
	p.drawPixmap((size - original.width()) / 2, (size - original.height()) / 2, original);

	return square;
}

Client* AvatarFactory::client() const
{
	return client_;
}

VCardFactory* AvatarFactory::vCardFactory() const
{
	return vCardFactory_;
}

void AvatarFactory::reloadCachedHashes ()
{
	QFile sapoPhoto_hashes_file(QDir(AvatarFactory::getCacheDir()).filePath("SapoPhoto_cached_hashes.map"));
	if (sapoPhoto_hashes_file.open(IO_ReadOnly)) {
		QDataStream sapoPhoto_hashes_in(&sapoPhoto_hashes_file);
		sapoPhoto_hashes_in >> cached_sapoPhoto_hashes_;
		sapoPhoto_hashes_file.close();
	}
	
	QFile vcard_hashes_file(QDir(AvatarFactory::getCacheDir()).filePath("vCard_cached_hashes.map"));
	if (vcard_hashes_file.open(IO_ReadOnly)) {
		QDataStream vcard_hashes_in(&vcard_hashes_file);
		vcard_hashes_in >> cached_vcard_hashes_;
		vcard_hashes_file.close();
	}
}

void AvatarFactory::saveCachedHashes ()
{
	QFile sapoPhoto_hashes_file(QDir(AvatarFactory::getCacheDir()).filePath("SapoPhoto_cached_hashes.map"));
	if (sapoPhoto_hashes_file.open(IO_WriteOnly)) {
		QDataStream sapoPhoto_hashes_out(&sapoPhoto_hashes_file);
		sapoPhoto_hashes_out << cached_sapoPhoto_hashes_;
		sapoPhoto_hashes_file.close();
	}
	
	QFile vcard_hashes_file(QDir(AvatarFactory::getCacheDir()).filePath("vCard_cached_hashes.map"));
	if (vcard_hashes_file.open(IO_WriteOnly)) {
		QDataStream vcard_hashes_out(&vcard_hashes_file);
		vcard_hashes_out << cached_vcard_hashes_;
		vcard_hashes_file.close();
	}
}


QPixmap AvatarFactory::getAvatar(const Jid& jid)
{
	// Compute the avatar of the user
	Avatar* av = retrieveAvatar(jid);

	// If the avatar changed since the previous request, notify everybody of this
	if (av != active_avatars_[jid.full()]) {
		active_avatars_[jid.full()] = av;
		active_avatars_[jid.bare()] = av;
		emit avatarChanged(jid);
	}

	QPixmap pm = (av ? av->getPixmap() : QPixmap());
	pm = ensureSquareAvatar(pm);

	// Update iconset
	PsiIcon icon;
	icon.setImpix(pm);
	iconset_.setIcon(QString("avatars/%1").arg(jid.bare()),icon);

	return pm;
}

void AvatarFactory::removeAvatars(const Jid& jid)
{
	active_avatars_.remove(jid.full());
	active_avatars_.remove(jid.bare());
	
	QList< QMap<QString, void *> * > mapsList;
	
	mapsList
		/* << (QMap<QString, void *> *)&pep_avatars_ */
		<< (QMap<QString, void *> *)&file_avatars_
		<< (QMap<QString, void *> *)&vcard_avatars_
		<< (QMap<QString, void *> *)&vcard_static_avatars_
		<< (QMap<QString, void *> *)&sapoPhoto_avatars_;
	
	QList< QMap<QString, void *> * >::ConstIterator mapIterator;
	
	for (mapIterator = mapsList.constBegin(); mapIterator != mapsList.constEnd(); mapIterator++) {
		QMap<QString, void *> *avatarsMap = *mapIterator;
		Avatar *av1, *av2;
		
		av1 = (Avatar *)((*avatarsMap)[jid.full()]);
		avatarsMap->remove(jid.full());
		if (av1 != NULL)
			delete av1;
		
		av2 = (Avatar *)((*avatarsMap)[jid.bare()]);
		avatarsMap->remove(jid.bare());
		if (av2 != NULL && av1 != av2)
			delete av2;
	}
	
	emit avatarChanged(jid);
}

Avatar* AvatarFactory::retrieveAvatar(const Jid& jid)
{
	//printf("Retrieving avatar of %s\n", jid.full().latin1());

	// Try finding a file avatar.
	//printf("File avatar\n");
	if (!file_avatars_.contains(jid.bare())) {
		//printf("File avatar not yet loaded\n");
		file_avatars_[jid.bare()] = new FileAvatar(this, jid);
	}
	//printf("Trying file avatar\n");
	if (!file_avatars_[jid.bare()]->isEmpty())
		return file_avatars_[jid.bare()];
	
//	//printf("PEP avatar\n");
//	if (pep_avatars_.contains(jid.bare()) && !pep_avatars_[jid.bare()]->isEmpty()) {
//		return pep_avatars_[jid.bare()];
//	}

	// Try finding a vcard avatar
	//printf("VCard avatar\n");
	if (vcard_avatars_.contains(jid.bare()) && !vcard_avatars_[jid.bare()]->isEmpty()) {
		return vcard_avatars_[jid.bare()];
	}
	
	// Try finding a sapo:photo avatar
	//printf("sapo:photo avatar\n");
	if (sapoPhoto_avatars_.contains(jid.bare()) && !sapoPhoto_avatars_[jid.bare()]->isEmpty()) {
		return sapoPhoto_avatars_[jid.bare()];
	}
	
	// Try finding a static vcard avatar
	//printf("Static VCard avatar\n");
	if (!vcard_static_avatars_.contains(jid.bare())) {
		//printf("Static vcard avatar not yet loaded\n");
		vcard_static_avatars_[jid.bare()] = new VCardStaticAvatar(this, jid);
		connect(vcard_static_avatars_[jid.bare()],SIGNAL(avatarChanged(const Jid&)),this,SLOT(updateAvatar(const Jid&)));
	}
	if (!vcard_static_avatars_[jid.bare()]->isEmpty()) {
		return vcard_static_avatars_[jid.bare()];
	}

	return 0;
}

QString	AvatarFactory::selfSapoPhotoHash() const
{
	return selfAvatarSapoPhotoHash_;
}

QString	AvatarFactory::selfVCardPhotoHash() const
{
	return selfAvatarVCardHash_;
}

void AvatarFactory::setSelfAvatar(const QByteArray& avatarData)
{
	QString prev_sapoPhotoHash = selfSapoPhotoHash();
	QString prev_vCardHash = selfVCardPhotoHash();
	
	if (!avatarData.isEmpty()) {
		QByteArray	scaled_avatar = scaleAvatar(avatarData);
		
		// Sapo:Photo
		if (isSapoPhotoPublishingEnabled()) {
			unsigned long crc32_val = crc32(0, (const Bytef *)(scaled_avatar.constData()), scaled_avatar.size());
			
			selfAvatarSapoPhotoHash_ = QString().sprintf("%08lX", crc32_val);
			_sapoPhotoPushTask->setSelfAvatar(scaled_avatar);
			
			if (client()->isActive()) {
				JT_SapoPhoto *iqPrivateSet = new JT_SapoPhoto(client()->rootTask());
				
				iqPrivateSet->setSelf(scaled_avatar);
				iqPrivateSet->go(true);
			}
		}
		
		// VCard
		if (client()->isActive()) {
			VCardFactory *vcf = vCardFactory();
			VCard vCard = vcf->selfVCard();
			
			// If the vCard is not available, the VCardFactory will get it automatically and we will be notified when it's done. This is all triggered by the call to VCardFactory::selfVCard() above.
			if (!vcf->selfVCardIsAvailable()) {
				pendingSelfAvatarVCardPhoto_ = scaled_avatar;
			}
			else {
				// we can set it right away
				vCard.setPhoto(scaled_avatar);
				vcf->setSelfVCard(vCard);
			}
		}
		
		//		QImage		avatar_image(scaled_avatar);
//		
//		if(!scaled_avatar.isNull()) {
//			// PEP Stuff:
//			// Publish data
//			QDomDocument* doc = client()->doc();
//			QString hash = SHA1().hashToString(avatar_data);
//			QDomElement el = doc->createElement("data");
//			el.setAttribute("xmlns","http://jabber.org/protocol/avatar#data");
//			el.appendChild(doc->createTextNode(Base64().arrayToString(avatar_data)));
//			selfAvatarData_ = avatar_data;
//			selfAvatarHash_ = hash;
//			account()->pepManager()->publish("http://jabber.org/protocol/avatar#data",PubSubItem(hash,el));
//		}
	}
	else {
		// Sapo:Photo
		if (isSapoPhotoPublishingEnabled()) {
			selfAvatarSapoPhotoHash_ = "";
			_sapoPhotoPushTask->setSelfAvatar(avatarData);
		}
		
		// VCard
		selfAvatarVCardHash_ = "";

//		// PEP Stuff:
//		QDomDocument* doc = client()->doc();
//		QDomElement meta_el =  doc->createElement("metadata");
//		meta_el.setAttribute("xmlns","http://jabber.org/protocol/avatar#metadata");
//		meta_el.appendChild(doc->createElement("stop"));
//		account()->pepManager()->publish("http://jabber.org/protocol/avatar#metadata",PubSubItem("current",meta_el));
	}
	
	// Avoid notifying about an avatar whose "fetch request" was sent prior to a more recent "set request".
	canProcessSelfSapoPhotoAvatar_ = false;
	
	if (prev_sapoPhotoHash != selfAvatarSapoPhotoHash_ || prev_vCardHash != selfAvatarVCardHash_)
		emit selfAvatarHashValuesChanged();
}

void AvatarFactory::setSelfAvatar(const QString& fileName)
{
	if (!fileName.isEmpty()) {
		QFile avatar_file(fileName);
		
		if (avatar_file.open(QIODevice::ReadOnly))
			setSelfAvatar(avatar_file.readAll());
	}
	else {
		setSelfAvatar(QByteArray());
	}
}

void AvatarFactory::selfVCardChanged()
{
	VCardFactory *vcf = vCardFactory();
	VCard myVCard = vcf->selfVCard();
	
	QString prev_vCardHash = selfVCardPhotoHash();
	
	selfAvatarVCardHash_ = (myVCard.photo().isEmpty() ? "" : Hash("sha1").hashToString(myVCard.photo()));
	
	if (prev_vCardHash != selfAvatarVCardHash_) {
		// Always try to use the vCard avatar
		if (!selfAvatarVCardHash_.isEmpty() || selfAvatarSapoPhotoHash_.isEmpty()) {
			emit selfAvatarChanged(myVCard.photo());
		}
		else {
			// Fallback to the last sapo:photo avatar
			emit selfAvatarChanged(_sapoPhotoPushTask->selfAvatarBytes());
		}
		
		emit selfAvatarHashValuesChanged();
	}
	
	
	if (!pendingSelfAvatarVCardPhoto_.isEmpty()) {
		// We had an avatar change operation hanged waiting for our vcard to arrive from the server
		myVCard.setPhoto(pendingSelfAvatarVCardPhoto_);
		vcf->setSelfVCard(myVCard);
		
		pendingSelfAvatarVCardPhoto_ = QByteArray();
	}
}

void AvatarFactory::updateAvatar(const Jid& j)
{
	getAvatar(j);
	// FIXME: This signal might be emitted twice (first time from getAvatar()).
	emit avatarChanged(j);
}

void AvatarFactory::importManualAvatar(const Jid& j, const QString& fileName)
{
	FileAvatar(this, j).import(fileName);
	emit avatarChanged(j);
}

void AvatarFactory::removeManualAvatar(const Jid& j)
{
	FileAvatar(this, j).removeFromDisk();
	// TODO: Remove from caches. Maybe create a clearManualAvatar() which
	// removes the file but doesn't remove the avatar from caches (since it'll
	// be created again whenever the FileAvatar is requested)
	emit avatarChanged(j);
}

bool AvatarFactory::hasManualAvatar(const Jid& j)
{
	return FileAvatar(this, j).exists();
}

void AvatarFactory::clientActivated()
{
	// sapo:photo
	canProcessSelfSapoPhotoAvatar_ = true;
	
	if (isSapoPhotoPublishingEnabled()) {
		JT_SapoPhoto *myAvatarFetcher = new JT_SapoPhoto(client()->rootTask());
		connect(myAvatarFetcher, SIGNAL(finished()), SLOT(receivedSelfSapoPhotoAvatar()));
		myAvatarFetcher->getSelf();
		myAvatarFetcher->go(true);
	}
	
	// vcard-temp: the initial vCard fetch should be performed from some central place, since it's probably
	// needed by several modules simultaneously.
}

void AvatarFactory::clientDisconnected()
{
	saveCachedHashes();
}

void AvatarFactory::receivedSelfSapoPhotoAvatar()
{
	// Avoid notifying about an avatar whose "fetch request" was sent prior to a more recent "set request".
	if (canProcessSelfSapoPhotoAvatar_) {
		QString		prev_sapoPhotoHash = selfSapoPhotoHash();
		QByteArray	receivedData = ((JT_SapoPhoto *)sender())->receivedAvatarData();
		
		if (!receivedData.isEmpty()) {
			unsigned long crc32_val = crc32(0, (const Bytef *)(receivedData.constData()), receivedData.size());
			selfAvatarSapoPhotoHash_ = QString().sprintf("%08lX", crc32_val);
		}
		else {
			selfAvatarSapoPhotoHash_ = "";
		}
		_sapoPhotoPushTask->setSelfAvatar(receivedData);
		
		if (prev_sapoPhotoHash != selfAvatarSapoPhotoHash_) {
			// Use sapo:photo only if we don't have a vCard avatar
			if (selfAvatarVCardHash_.isEmpty()) {
				emit selfAvatarChanged(receivedData);
			}
			emit selfAvatarHashValuesChanged();
		}
	}
}

void AvatarFactory::clientRosterItemAdded(const RosterItem &rosterItem)
{
	const Jid &jid = rosterItem.jid();
	
	if (!rosterItem.jid().compare( client()->jid() , false)) {
		// It's not me
		
		const QString &jidKey = jid.bare();
		
		if (cached_vcard_hashes_.contains(jidKey)) {
			QString hash = cached_vcard_hashes_[jidKey];
			if (!vcard_avatars_.contains(jidKey)) {
				vcard_avatars_[jidKey] = new VCardAvatar(this, jid);
				connect(vcard_avatars_[jidKey],SIGNAL(avatarChanged(const Jid&)),this,SLOT(updateAvatar(const Jid&)));
			}
			vcard_avatars_[jidKey]->updateHash(hash);
		}
		
		if (cached_sapoPhoto_hashes_.contains(jidKey)) {
			QString hash = cached_sapoPhoto_hashes_[jidKey];
			if (!sapoPhoto_avatars_.contains(jidKey)) {
				sapoPhoto_avatars_[jidKey] = new SapoPhotoAvatar(this, jid);
				connect(sapoPhoto_avatars_[jidKey],SIGNAL(avatarChanged(const Jid&)),this,SLOT(updateAvatar(const Jid&)));
			}
			sapoPhoto_avatars_[jidKey]->updateHash(hash);
		}
	}
}

void AvatarFactory::clientRosterItemRemoved(const RosterItem &rosterItem)
{
	removeAvatars(rosterItem.jid());
}

void AvatarFactory::clientResourceAvailable(const Jid& jid, const Resource& r)
{
	if (jid.compare( client()->jid() , false)) {
		// It's me. Reload self avatar if needed.
		
		bool vCardAvatarChanged = ( (r.status().hasPhotoHash() && (selfVCardPhotoHash() != r.status().photoHash()))
									|| (!r.status().hasPhotoHash() && !selfVCardPhotoHash().isEmpty()) );
		bool sapoPhotoAvatarChanged = ( (r.status().hasSapoPhotoHash() && (selfSapoPhotoHash() != r.status().sapoPhotoHash()))
										|| (!r.status().hasSapoPhotoHash() && !selfSapoPhotoHash().isEmpty()) );
		
		if (vCardAvatarChanged) {
			VCardFactory *vcf = vCardFactory();
			vcf->resetSelfVCard();
		}
		
		if (sapoPhotoAvatarChanged) {
			canProcessSelfSapoPhotoAvatar_ = true;
			
			if (isSapoPhotoPublishingEnabled()) {
				JT_SapoPhoto *myAvatarFetcher = new JT_SapoPhoto(client()->rootTask());
				connect(myAvatarFetcher, SIGNAL(finished()), SLOT(receivedSelfSapoPhotoAvatar()));
				myAvatarFetcher->getSelf();
				myAvatarFetcher->go(true);
			}
		}
	}
	else {
		// It's not me
		
		bool emitAvatarChanged = false;
		const QString & bareJid = jid.bare();

		// vCard-based
		if (r.status().hasPhotoHash()) {
			QString hash = r.status().photoHash();
			
			cached_vcard_hashes_[bareJid] = hash;
			
			if (!vcard_avatars_.contains(bareJid)) {
				vcard_avatars_[bareJid] = new VCardAvatar(this, jid);
				connect(vcard_avatars_[bareJid],SIGNAL(avatarChanged(const Jid&)),this,SLOT(updateAvatar(const Jid&)));
			}
			vcard_avatars_[bareJid]->updateHash(hash);
		}
		else {
			cached_vcard_hashes_.remove(bareJid);
			
			if (vcard_avatars_.contains(bareJid)) {
				Avatar *av = vcard_avatars_[bareJid];
				vcard_avatars_.remove(bareJid);
				
				if (av != NULL)
					delete av;
				
				emitAvatarChanged = true;
			}
		}
		
		// Sapo:Photo
		if (r.status().hasSapoPhotoHash()) {
			QString hash = r.status().sapoPhotoHash();
			
			cached_sapoPhoto_hashes_[bareJid] = hash;
			
			if (!sapoPhoto_avatars_.contains(bareJid)) {
				sapoPhoto_avatars_[bareJid] = new SapoPhotoAvatar(this, jid);
				connect(sapoPhoto_avatars_[bareJid],SIGNAL(avatarChanged(const Jid&)),this,SLOT(updateAvatar(const Jid&)));
			}
			sapoPhoto_avatars_[bareJid]->setResource(r.name());
			sapoPhoto_avatars_[bareJid]->updateHash(hash);
		}
		else {
			cached_sapoPhoto_hashes_.remove(bareJid);
			
			if (sapoPhoto_avatars_.contains(bareJid)) {
				Avatar *av = sapoPhoto_avatars_[bareJid];
				sapoPhoto_avatars_.remove(bareJid);
				
				if (av != NULL)
					delete av;
				
				emitAvatarChanged = true;
			}
		}
		
		if (emitAvatarChanged)
			emit avatarChanged(jid);
	}
}

void AvatarFactory::setAvatarsDirs(const QString &customAvatarsDir, const QString &cachedAvatarsDir)
{
	customAvatarsDir_ = customAvatarsDir;
	cachedAvatarsDir_ = cachedAvatarsDir;
	
	// Ensure that they exist
	QDir().mkpath(customAvatarsDir);
	QDir().mkpath(cachedAvatarsDir);
}

QString AvatarFactory::getManualDir()
{
	return customAvatarsDir_;
}

QString AvatarFactory::getCacheDir()
{
	return cachedAvatarsDir_;
}

QString AvatarFactory::customAvatarsDir_;
QString AvatarFactory::cachedAvatarsDir_;

//void AvatarFactory::itemPublished(const Jid& jid, const QString& n, const PubSubItem& item)
//{
//	if (n == "http://jabber.org/protocol/avatar#data") {
//		if (item.payload().tagName() == "data") {
//			pep_avatars_[jid.bare()]->setData(item.id(),item.payload().text());
//		}
//		else {
//			qWarning("avatars.cpp: Unexpected item payload");
//		}
//	}
//	else if (n == "http://jabber.org/protocol/avatar#metadata") {
//		if (!pep_avatars_.contains(jid.bare())) {
//			pep_avatars_[jid.bare()] = new PEPAvatar(this, jid.bare());
//			connect(pep_avatars_[jid.bare()],SIGNAL(avatarChanged(const Jid&)),this, SLOT(updateAvatar(const Jid&)));
//		}
//		QDomElement e;
//		bool found;
//		e = findSubTag(item.payload(), "stop", &found);
//		if (found) {
//			pep_avatars_[jid.bare()]->updateHash("");
//		}
//		else {
//			pep_avatars_[jid.bare()]->updateHash(item.id());
//		}
//	}	
//}

//void AvatarFactory::publish_success(const QString& n, const PubSubItem& item)
//{
//	if (n == "http://jabber.org/protocol/avatar#data" && item.id() == selfAvatarHash_) {
//		// Publish metadata
//		QDomDocument* doc = client()->doc();
//		QImage avatar_image(selfAvatarData_);
//		QDomElement meta_el = doc->createElement("metadata");
//		meta_el.setAttribute("xmlns","http://jabber.org/protocol/avatar#metadata");
//		QDomElement info_el = doc->createElement("info");
//		info_el.setAttribute("id",selfAvatarHash_);
//		info_el.setAttribute("bytes",avatar_image.numBytes());
//		info_el.setAttribute("height",avatar_image.height());
//		info_el.setAttribute("width",avatar_image.width());
//		info_el.setAttribute("type",image2type(selfAvatarData_));
//		meta_el.appendChild(info_el);
//		account()->pepManager()->publish("http://jabber.org/protocol/avatar#metadata",PubSubItem(selfAvatarHash_,meta_el));
//	}
//}

//------------------------------------------------------------------------------

#include "avatars.moc"
