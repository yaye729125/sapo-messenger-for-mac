#include "filetransferhandler.h"
#include "filetransfer.h"


typedef Q_UINT64 LARGE_TYPE;

#define CSMAX (sizeof(LARGE_TYPE)*8)
#define CSMIN 16
static int calcShift(qlonglong big)
{
	LARGE_TYPE val = 1;
	val <<= CSMAX - 1;
	for(int n = CSMAX - CSMIN; n > 0; --n) {
		if(big & val)
			return n;
		val >>= 1;
	}
	return 0;
}

static int calcComplement(qlonglong big, int shift)
{
	int block = 1 << shift;
	qlonglong rem = big % block;
	if(rem == 0)
		return 0;
	else
		return (block - (int)rem);
}

static int calcTotalSteps(qlonglong big, int shift)
{
	if(big < 1)
		return 0;
	return ((big - 1) >> shift) + 1;
}

static int calcProgressStep(qlonglong big, int complement, int shift)
{
	return ((big + complement) >> shift);
}

static QStringList *activeFiles = 0;

static void active_file_add(const QString &s)
{
	if(!activeFiles)
		activeFiles = new QStringList;
	activeFiles->append(s);
	//printf("added: [%s]\n", s.latin1());
}

static void active_file_remove(const QString &s)
{
	if(!activeFiles)
		return;
	activeFiles->remove(s);
	//printf("removed: [%s]\n", s.latin1());
}

// [jpp] gcc: defined but not used
//static bool active_file_check(const QString &s)
//{
//	if(!activeFiles)
//		return false;
//	return activeFiles->contains(s);
//}

static QString clean_filename(const QString &s)
{
//#ifdef Q_OS_WIN
	QString badchars = "\\/|?*:\"<>";
	QString str;
	for(int n = 0; n < s.length(); ++n) {
		bool found = false;
		for(int b = 0; b < badchars.length(); ++b) {
			if(s.at(n) == badchars.at(b)) {
				found = true;
				break;
			}
		}
		str += (found ? '_' : s.at(n));
	}
	if(str.isEmpty())
		str = "unnamed";
	return str;
//#else
//	return s;
//#endif
}

//----------------------------------------------------------------------------
// FileTransferHandler
//----------------------------------------------------------------------------
class FileTransferHandler::Private
{
public:
	FileTransferManager *ftm;
	FileTransfer *ft;
	S5BConnection *c;
	Jid peer;
	Jid proxy;
	QString fileName, saveName;
	qlonglong fileSize, sent, offset, length;
	QString desc;
	bool sending;
	QFile f;
	int shift;
	int complement;
	QString activeFile;
};

FileTransferHandler::FileTransferHandler(FileTransferManager *ftm, FileTransfer *ft, Jid proxy)
{
	d = new Private;
	d->ftm = ftm;
	d->proxy = proxy;
	d->c = 0;

	if(ft) {
		d->sending = false;
		d->peer = ft->peer();
		d->fileName = clean_filename(ft->fileName());
		d->fileSize = ft->fileSize();
		d->desc = ft->description();
		d->shift = calcShift(d->fileSize);
		d->complement = calcComplement(d->fileSize, d->shift);
		d->ft = ft;
		if(d->proxy.isValid())
			d->ft->setProxy(d->proxy);
		mapSignals();
	}
	else {
		d->sending = true;
		d->ft = 0;
	}
}

FileTransferHandler::~FileTransferHandler()
{
	if(!d->activeFile.isEmpty())
		active_file_remove(d->activeFile);

	if(d->ft) {
		d->ft->close();
		delete d->ft;
	}
	delete d;
}

void FileTransferHandler::send(const XMPP::Jid &to, const QString &fname, const QString &desc, const XMPP::Jid &proxy)
{
	if(!d->sending)
		return;
	
	d->peer = to;
	d->proxy = proxy;
	QFileInfo fi(fname);
	d->fileName = fi.fileName();
	d->fileSize = fi.size();
	d->desc = desc;
	d->shift = calcShift(d->fileSize);
	d->complement = calcComplement(d->fileSize, d->shift);

	d->ft = d->ftm->createTransfer();
	if(d->proxy.isValid())
		d->ft->setProxy(d->proxy);
	mapSignals();

	d->f.setFileName(fname);
	d->ft->sendFile(d->peer, d->fileName, d->fileSize, desc);
}

int FileTransferHandler::mode() const
{
	return (d->sending ? Sending : Receiving);
}

Jid FileTransferHandler::peer() const
{
	return d->peer;
}

QString FileTransferHandler::fileName() const
{
	return d->fileName;
}

qlonglong FileTransferHandler::fileSize() const
{
	return d->fileSize;
}

QString FileTransferHandler::description() const
{
	return d->desc;
}

qlonglong FileTransferHandler::offset() const
{
	return d->offset;
}

int FileTransferHandler::totalSteps() const
{
	return calcTotalSteps(d->fileSize, d->shift);
}

bool FileTransferHandler::resumeSupported() const
{
	if(d->ft)
		return d->ft->rangeSupported();
	else
		return false;
}

QString FileTransferHandler::saveName() const
{
	return d->saveName;
}

void FileTransferHandler::accept(const QString &saveName, const QString &fileName, qlonglong offset)
{
	if(d->sending)
		return;
	d->fileName = fileName;
	d->saveName = saveName;
	d->offset = offset;
	d->length = d->fileSize;
	d->f.setFileName(saveName);
	d->ft->accept(offset);
}

void FileTransferHandler::s5b_proxyQuery()
{
	statusMessage(tr("Quering proxy..."));
}

void FileTransferHandler::s5b_proxyResult(bool b)
{
	if(b)
		statusMessage(tr("Proxy query successful."));
	else
		statusMessage(tr("Proxy query failed!"));
}

void FileTransferHandler::s5b_requesting()
{
	statusMessage(tr("Requesting data transfer channel..."));
}

void FileTransferHandler::s5b_accepted()
{
	statusMessage(tr("Peer accepted request."));
}

void FileTransferHandler::s5b_tryingHosts(const StreamHostList &)
{
	statusMessage(tr("Connecting to peer..."));
}

void FileTransferHandler::s5b_proxyConnect()
{
	statusMessage(tr("Connecting to proxy..."));
}

void FileTransferHandler::s5b_waitingForActivation()
{
	statusMessage(tr("Waiting for peer activation..."));
}

void FileTransferHandler::ft_accepted()
{
	d->offset = d->ft->offset();
	d->length = d->ft->length();

	d->c = d->ft->s5bConnection();
	connect(d->c, SIGNAL(proxyQuery()), SLOT(s5b_proxyQuery()));
	connect(d->c, SIGNAL(proxyResult(bool)), SLOT(s5b_proxyResult(bool)));
	connect(d->c, SIGNAL(requesting()), SLOT(s5b_requesting()));
	connect(d->c, SIGNAL(accepted()), SLOT(s5b_accepted()));
	connect(d->c, SIGNAL(tryingHosts(const StreamHostList &)), SLOT(s5b_tryingHosts(const StreamHostList &)));
	connect(d->c, SIGNAL(proxyConnect()), SLOT(s5b_proxyConnect()));
	connect(d->c, SIGNAL(waitingForActivation()), SLOT(s5b_waitingForActivation()));

	if(d->sending)
		accepted();
}

void FileTransferHandler::ft_connected()
{
	d->sent = d->offset;

	if(d->sending) {
		// open the file, and set the correct offset
		bool ok = false;
		if(d->f.open(QIODevice::ReadOnly)) {
			if(d->offset == 0) {
				ok = true;
			}
			else {
				if(d->f.at(d->offset))
					ok = true;
			}
		}
		if(!ok) {
			delete d->ft;
			d->ft = 0;
			error(ErrFile, 0, d->f.errorString());
			return;
		}

		if(d->sent == d->fileSize)
			QTimer::singleShot(0, this, SLOT(doFinish()));
		else
			QTimer::singleShot(0, this, SLOT(trySend()));
	}
	else {
		// open the file, truncating if offset is zero, otherwise set the correct offset
		QIODevice::OpenMode m = QIODevice::ReadWrite;
		if(d->offset == 0)
			m |= QIODevice::Truncate;
		bool ok = false;
		if(d->f.open(m)) {
			if(d->offset == 0) {
				ok = true;
			}
			else {
				if(d->f.at(d->offset))
					ok = true;
			}
		}
		if(!ok) {
			delete d->ft;
			d->ft = 0;
			error(ErrFile, 0, d->f.errorString());
			return;
		}

		d->activeFile = d->f.name();
		active_file_add(d->activeFile);

		// done already?  this means a file size of zero
		if(d->sent == d->fileSize)
			QTimer::singleShot(0, this, SLOT(doFinish()));
	}

	connected();
}

void FileTransferHandler::ft_readyRead(const QByteArray &a)
{
	if(!d->sending) {
		//printf("%d bytes read\n", a.size());
		int r = d->f.writeBlock(a.data(), a.size());
		if(r < 0) {
			d->f.close();
			delete d->ft;
			d->ft = 0;
			error(ErrFile, 0, d->f.errorString());
			return;
		}
		d->sent += a.size();
		doFinish();
	}
}

void FileTransferHandler::ft_bytesWritten(int x)
{
	if(d->sending) {
		//printf("%d bytes written\n", x);
		d->sent += x;
		if(d->sent == d->fileSize) {
			d->f.close();
			delete d->ft;
			d->ft = 0;
		}
		else
			QTimer::singleShot(0, this, SLOT(trySend()));
		progress(calcProgressStep(d->sent, d->complement, d->shift), d->sent);
	}
}

void FileTransferHandler::ft_error(int x)
{
	if(d->f.isOpen())
		d->f.close();
	delete d->ft;
	d->ft = 0;

	if(x == FileTransfer::ErrReject)
		error(ErrReject, x, tr("Rejected by peer"));
	else if(x == FileTransfer::ErrNeg)
		error(ErrTransfer, x, tr("Unable to negotiate transfer."));
	else if(x == FileTransfer::ErrConnect)
		error(ErrTransfer, x, tr("Unable to connect to peer for data transfer."));
	else if(x == FileTransfer::ErrProxy)
		error(ErrTransfer, x, tr("Unable to connect to proxy for data transfer."));
	else if(x == FileTransfer::ErrStream)
		error(ErrTransfer, x, tr("Lost connection / Cancelled."));
}

void FileTransferHandler::trySend()
{
	int blockSize = d->ft->dataSizeNeeded();
	QByteArray a(blockSize, 0);
	int r = 0;
	if(blockSize > 0)
		r = d->f.read(a.data(), a.size());
	if(r < 0) {
		d->f.close();
		delete d->ft;
		d->ft = 0;
		error(ErrFile, 0, d->f.errorString());
		return;
	}
	if(r < (int)a.size())
		a.resize(r);
	d->ft->writeFileData(a);
}

void FileTransferHandler::doFinish()
{
	if(d->sent == d->fileSize) {
		d->f.close();
		delete d->ft;
		d->ft = 0;
	}
	progress(calcProgressStep(d->sent, d->complement, d->shift), d->sent);
}

void FileTransferHandler::mapSignals()
{
	connect(d->ft, SIGNAL(accepted()), SLOT(ft_accepted()));
	connect(d->ft, SIGNAL(connected()), SLOT(ft_connected()));
	connect(d->ft, SIGNAL(readyRead(const QByteArray &)), SLOT(ft_readyRead(const QByteArray &)));
	connect(d->ft, SIGNAL(bytesWritten(int)), SLOT(ft_bytesWritten(int)));
	connect(d->ft, SIGNAL(error(int)), SLOT(ft_error(int)),Qt::QueuedConnection);
}

