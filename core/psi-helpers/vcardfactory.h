/*
 * vcardfactory.h - class for caching vCards
 * Copyright (C) 2003  Michail Pishchagin
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

#ifndef VCARDFACTORY_H
#define VCARDFACTORY_H

#include <QObject>
#include <QMap>
#include <QStringList>

#include "im.h"
#include "xmpp_vcard.h"
#include "xmpp_tasks.h"

using namespace XMPP;

class VCardFactory : public QObject
{
	Q_OBJECT
	
public:
	static VCardFactory* instance();
	
	VCardFactory(Client *c = 0);
	~VCardFactory();

	const VCard *vcard(const Jid &);
	void setVCard(const Jid &, const VCard &);
	JT_VCard *getVCard(const Jid &, Task *rootTask, const QObject *, const char *slot, bool cacheVCard = true);
	
	void setVCardsDir(const QString &vCardsDir);
	
	void setClient(Client *);

	VCard selfVCard();
	void setSelfVCard(const VCard &myVCard);
	void resetSelfVCard();
	bool selfVCardIsAvailable();
	
protected slots:
	void clientActivated();
	void selfVCardTaskFinished();

signals:
	void vcardChanged(const Jid&);
	void selfVCardChanged();
	
protected:
	void startSelfVCardUpdate();
	void checkLimit(QString jid, VCard *vcard);
	
private slots:
	void taskFinished();
	
private:
	QString vCardsDir_;
	
	VCard myVCard_;
	bool isFetchingMyVCard_;
	bool hasFetchedMyVCard_;
	Client *client_;
	
	static VCardFactory* instance_;
	const int dictSize_;
	QStringList vcardList_;
	QMap<QString,VCard*> vcardDict_;
};

#endif
