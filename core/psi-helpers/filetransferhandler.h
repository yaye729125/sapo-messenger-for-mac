#ifndef FILETRANSDLG_H
#define FILETRANSDLG_H

#include "im.h"
#include "s5b.h"


namespace XMPP
{
	class FileTransfer;
}
using namespace XMPP;


class FileTransferHandler : public QObject
{
	Q_OBJECT
public:
	enum { ErrReject, ErrTransfer, ErrFile };
	enum { Sending, Receiving };
	FileTransferHandler(FileTransferManager *ftm, FileTransfer *ft = 0, Jid proxy = Jid());
	~FileTransferHandler();

	int mode() const;
	Jid peer() const;
	QString fileName() const;
	qlonglong fileSize() const;
	QString description() const;
	qlonglong offset() const;
	int totalSteps() const;
	bool resumeSupported() const;
	QString saveName() const;

	void send(const Jid &to, const QString &fname, const QString &desc, const Jid &proxy = Jid());
	void accept(const QString &saveName, const QString &fileName, qlonglong offset=0);

signals:
	void accepted();
	void statusMessage(const QString &s);
	void connected();
	void progress(int p, qlonglong sent);
	void error(int, int, const QString &s);

private slots:
	// s5b status
	void s5b_proxyQuery();
	void s5b_proxyResult(bool b);
	void s5b_requesting();
	void s5b_accepted();
	void s5b_tryingHosts(const StreamHostList &hosts);
	void s5b_proxyConnect();
	void s5b_waitingForActivation();

	// ft
	void ft_accepted();
	void ft_connected();
	void ft_readyRead(const QByteArray &);
	void ft_bytesWritten(int);
	void ft_error(int);
	void trySend();
	void doFinish();

private:
	class Private;
	Private *d;

	void mapSignals();
};


#endif
