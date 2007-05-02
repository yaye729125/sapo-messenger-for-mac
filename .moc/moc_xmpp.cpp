/****************************************************************************
** Meta object code from reading C++ file 'xmpp.h'
**
** Created: Thu Jul 20 17:53:46 2006
**      by: The Qt Meta Object Compiler version 59 (Qt 4.1.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../src/ambrosia/iris/include/xmpp.h"
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'xmpp.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 59
#error "This file was generated using the moc from 4.1.1. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

static const uint qt_meta_data_XMPP__Connector[] = {

 // content:
       1,       // revision
       0,       // classname
       0,    0, // classinfo
       2,   10, // methods
       0,    0, // properties
       0,    0, // enums/sets

 // signals: signature, parameters, type, tag, flags
      17,   16,   16,   16, 0x05,
      29,   16,   16,   16, 0x05,

       0        // eod
};

static const char qt_meta_stringdata_XMPP__Connector[] = {
    "XMPP::Connector\0\0connected()\0error()\0"
};

const QMetaObject XMPP::Connector::staticMetaObject = {
    { &QObject::staticMetaObject, qt_meta_stringdata_XMPP__Connector,
      qt_meta_data_XMPP__Connector, 0 }
};

const QMetaObject *XMPP::Connector::metaObject() const
{
    return &staticMetaObject;
}

void *XMPP::Connector::qt_metacast(const char *_clname)
{
    if (!_clname) return 0;
    if (!strcmp(_clname, qt_meta_stringdata_XMPP__Connector))
	return static_cast<void*>(const_cast<Connector*>(this));
    return QObject::qt_metacast(_clname);
}

int XMPP::Connector::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: connected(); break;
        case 1: error(); break;
        }
        _id -= 2;
    }
    return _id;
}

// SIGNAL 0
void XMPP::Connector::connected()
{
    QMetaObject::activate(this, &staticMetaObject, 0, 0);
}

// SIGNAL 1
void XMPP::Connector::error()
{
    QMetaObject::activate(this, &staticMetaObject, 1, 0);
}
static const uint qt_meta_data_XMPP__AdvancedConnector[] = {

 // content:
       1,       // revision
       0,       // classname
       0,    0, // classinfo
       6,   10, // methods
       0,    0, // properties
       0,    0, // enums/sets

 // signals: signature, parameters, type, tag, flags
      32,   25,   24,   24, 0x05,
      59,   51,   24,   24, 0x05,

 // slots: signature, parameters, type, tag, flags
      75,   24,   24,   24, 0x08,
      86,   24,   24,   24, 0x08,
      97,   24,   24,   24, 0x08,
     112,   24,   24,   24, 0x08,

       0        // eod
};

static const char qt_meta_stringdata_XMPP__AdvancedConnector[] = {
    "XMPP::AdvancedConnector\0\0server\0srvLookup(QString)\0success\0"
    "srvResult(bool)\0dns_done()\0srv_done()\0bs_connected()\0bs_error(int)\0"
};

const QMetaObject XMPP::AdvancedConnector::staticMetaObject = {
    { &Connector::staticMetaObject, qt_meta_stringdata_XMPP__AdvancedConnector,
      qt_meta_data_XMPP__AdvancedConnector, 0 }
};

const QMetaObject *XMPP::AdvancedConnector::metaObject() const
{
    return &staticMetaObject;
}

void *XMPP::AdvancedConnector::qt_metacast(const char *_clname)
{
    if (!_clname) return 0;
    if (!strcmp(_clname, qt_meta_stringdata_XMPP__AdvancedConnector))
	return static_cast<void*>(const_cast<AdvancedConnector*>(this));
    return Connector::qt_metacast(_clname);
}

int XMPP::AdvancedConnector::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = Connector::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: srvLookup(*reinterpret_cast< const QString(*)>(_a[1])); break;
        case 1: srvResult(*reinterpret_cast< bool(*)>(_a[1])); break;
        case 2: dns_done(); break;
        case 3: srv_done(); break;
        case 4: bs_connected(); break;
        case 5: bs_error(*reinterpret_cast< int(*)>(_a[1])); break;
        }
        _id -= 6;
    }
    return _id;
}

// SIGNAL 0
void XMPP::AdvancedConnector::srvLookup(const QString & _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 0, _a);
}

// SIGNAL 1
void XMPP::AdvancedConnector::srvResult(bool _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 1, _a);
}
static const uint qt_meta_data_XMPP__TLSHandler[] = {

 // content:
       1,       // revision
       0,       // classname
       0,    0, // classinfo
       5,   10, // methods
       0,    0, // properties
       0,    0, // enums/sets

 // signals: signature, parameters, type, tag, flags
      18,   17,   17,   17, 0x05,
      28,   17,   17,   17, 0x05,
      35,   17,   17,   17, 0x05,
      46,   44,   17,   17, 0x05,
      81,   68,   17,   17, 0x05,

       0        // eod
};

static const char qt_meta_stringdata_XMPP__TLSHandler[] = {
    "XMPP::TLSHandler\0\0success()\0fail()\0closed()\0a\0"
    "readyRead(QByteArray)\0a,plainBytes\0readyReadOutgoing(QByteArray,int)\0"
};

const QMetaObject XMPP::TLSHandler::staticMetaObject = {
    { &QObject::staticMetaObject, qt_meta_stringdata_XMPP__TLSHandler,
      qt_meta_data_XMPP__TLSHandler, 0 }
};

const QMetaObject *XMPP::TLSHandler::metaObject() const
{
    return &staticMetaObject;
}

void *XMPP::TLSHandler::qt_metacast(const char *_clname)
{
    if (!_clname) return 0;
    if (!strcmp(_clname, qt_meta_stringdata_XMPP__TLSHandler))
	return static_cast<void*>(const_cast<TLSHandler*>(this));
    return QObject::qt_metacast(_clname);
}

int XMPP::TLSHandler::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: success(); break;
        case 1: fail(); break;
        case 2: closed(); break;
        case 3: readyRead(*reinterpret_cast< const QByteArray(*)>(_a[1])); break;
        case 4: readyReadOutgoing(*reinterpret_cast< const QByteArray(*)>(_a[1]),*reinterpret_cast< int(*)>(_a[2])); break;
        }
        _id -= 5;
    }
    return _id;
}

// SIGNAL 0
void XMPP::TLSHandler::success()
{
    QMetaObject::activate(this, &staticMetaObject, 0, 0);
}

// SIGNAL 1
void XMPP::TLSHandler::fail()
{
    QMetaObject::activate(this, &staticMetaObject, 1, 0);
}

// SIGNAL 2
void XMPP::TLSHandler::closed()
{
    QMetaObject::activate(this, &staticMetaObject, 2, 0);
}

// SIGNAL 3
void XMPP::TLSHandler::readyRead(const QByteArray & _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 3, _a);
}

// SIGNAL 4
void XMPP::TLSHandler::readyReadOutgoing(const QByteArray & _t1, int _t2)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)), const_cast<void*>(reinterpret_cast<const void*>(&_t2)) };
    QMetaObject::activate(this, &staticMetaObject, 4, _a);
}
static const uint qt_meta_data_XMPP__QCATLSHandler[] = {

 // content:
       1,       // revision
       0,       // classname
       0,    0, // classinfo
       7,   10, // methods
       0,    0, // properties
       0,    0, // enums/sets

 // signals: signature, parameters, type, tag, flags
      21,   20,   20,   20, 0x05,

 // slots: signature, parameters, type, tag, flags
      37,   20,   20,   20, 0x0a,
      62,   20,   20,   20, 0x08,
      79,   20,   20,   20, 0x08,
      95,   20,   20,   20, 0x08,
     122,   20,   20,   20, 0x08,
     135,   20,   20,   20, 0x08,

       0        // eod
};

static const char qt_meta_stringdata_XMPP__QCATLSHandler[] = {
    "XMPP::QCATLSHandler\0\0tlsHandshaken()\0continueAfterHandshake()\0"
    "tls_handshaken()\0tls_readyRead()\0tls_readyReadOutgoing(int)\0"
    "tls_closed()\0tls_error(int)\0"
};

const QMetaObject XMPP::QCATLSHandler::staticMetaObject = {
    { &TLSHandler::staticMetaObject, qt_meta_stringdata_XMPP__QCATLSHandler,
      qt_meta_data_XMPP__QCATLSHandler, 0 }
};

const QMetaObject *XMPP::QCATLSHandler::metaObject() const
{
    return &staticMetaObject;
}

void *XMPP::QCATLSHandler::qt_metacast(const char *_clname)
{
    if (!_clname) return 0;
    if (!strcmp(_clname, qt_meta_stringdata_XMPP__QCATLSHandler))
	return static_cast<void*>(const_cast<QCATLSHandler*>(this));
    return TLSHandler::qt_metacast(_clname);
}

int XMPP::QCATLSHandler::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = TLSHandler::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: tlsHandshaken(); break;
        case 1: continueAfterHandshake(); break;
        case 2: tls_handshaken(); break;
        case 3: tls_readyRead(); break;
        case 4: tls_readyReadOutgoing(*reinterpret_cast< int(*)>(_a[1])); break;
        case 5: tls_closed(); break;
        case 6: tls_error(*reinterpret_cast< int(*)>(_a[1])); break;
        }
        _id -= 7;
    }
    return _id;
}

// SIGNAL 0
void XMPP::QCATLSHandler::tlsHandshaken()
{
    QMetaObject::activate(this, &staticMetaObject, 0, 0);
}
static const uint qt_meta_data_XMPP__Stream[] = {

 // content:
       1,       // revision
       0,       // classname
       0,    0, // classinfo
       5,   10, // methods
       0,    0, // properties
       0,    0, // enums/sets

 // signals: signature, parameters, type, tag, flags
      14,   13,   13,   13, 0x05,
      33,   13,   13,   13, 0x05,
      56,   13,   13,   13, 0x05,
      68,   13,   13,   13, 0x05,
      84,   13,   13,   13, 0x05,

       0        // eod
};

static const char qt_meta_stringdata_XMPP__Stream[] = {
    "XMPP::Stream\0\0connectionClosed()\0delayedCloseFinished()\0readyRead()\0"
    "stanzaWritten()\0error(int)\0"
};

const QMetaObject XMPP::Stream::staticMetaObject = {
    { &QObject::staticMetaObject, qt_meta_stringdata_XMPP__Stream,
      qt_meta_data_XMPP__Stream, 0 }
};

const QMetaObject *XMPP::Stream::metaObject() const
{
    return &staticMetaObject;
}

void *XMPP::Stream::qt_metacast(const char *_clname)
{
    if (!_clname) return 0;
    if (!strcmp(_clname, qt_meta_stringdata_XMPP__Stream))
	return static_cast<void*>(const_cast<Stream*>(this));
    return QObject::qt_metacast(_clname);
}

int XMPP::Stream::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: connectionClosed(); break;
        case 1: delayedCloseFinished(); break;
        case 2: readyRead(); break;
        case 3: stanzaWritten(); break;
        case 4: error(*reinterpret_cast< int(*)>(_a[1])); break;
        }
        _id -= 5;
    }
    return _id;
}

// SIGNAL 0
void XMPP::Stream::connectionClosed()
{
    QMetaObject::activate(this, &staticMetaObject, 0, 0);
}

// SIGNAL 1
void XMPP::Stream::delayedCloseFinished()
{
    QMetaObject::activate(this, &staticMetaObject, 1, 0);
}

// SIGNAL 2
void XMPP::Stream::readyRead()
{
    QMetaObject::activate(this, &staticMetaObject, 2, 0);
}

// SIGNAL 3
void XMPP::Stream::stanzaWritten()
{
    QMetaObject::activate(this, &staticMetaObject, 3, 0);
}

// SIGNAL 4
void XMPP::Stream::error(int _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 4, _a);
}
static const uint qt_meta_data_XMPP__ClientStream[] = {

 // content:
       1,       // revision
       0,       // classname
       0,    0, // classinfo
      30,   10, // methods
       0,    0, // properties
       0,    0, // enums/sets

 // signals: signature, parameters, type, tag, flags
      20,   19,   19,   19, 0x05,
      32,   19,   19,   19, 0x05,
      76,   60,   19,   19, 0x05,
     107,   19,   19,   19, 0x05,
     123,   19,   19,   19, 0x05,
     148,  136,   19,   19, 0x05,
     189,  181,   19,   19, 0x05,
     229,  214,   19,   19, 0x05,
     276,  181,   19,   19, 0x05,
     309,  307,   19,   19, 0x05,
     330,  307,   19,   19, 0x05,

 // slots: signature, parameters, type, tag, flags
     351,   19,   19,   19, 0x0a,
     374,   19,   19,   19, 0x08,
     389,   19,   19,   19, 0x08,
     400,   19,   19,   19, 0x08,
     422,   19,   19,   19, 0x08,
     448,   19,   19,   19, 0x08,
     462,   19,   19,   19, 0x08,
     477,   19,   19,   19, 0x08,
     498,   19,   19,   19, 0x08,
     517,   19,   19,   19, 0x08,
     532,   19,   19,   19, 0x08,
     562,  546,   19,   19, 0x08,
     619,  610,   19,   19, 0x08,
     669,  645,   19,   19, 0x08,
     719,  706,   19,   19, 0x08,
     751,   19,   19,   19, 0x08,
     772,   19,   19,   19, 0x08,
     788,   19,   19,   19, 0x08,
     797,   19,   19,   19, 0x08,

       0        // eod
};

static const char qt_meta_stringdata_XMPP__ClientStream[] = {
    "XMPP::ClientStream\0\0connected()\0securityLayerActivated(int)\0"
    "user,pass,realm\0needAuthParams(bool,bool,bool)\0authenticated()\0"
    "warning(int)\0to,from,key\0dialbackRequest(Jid,Jid,QString)\0from,ok\0"
    "dialbackResult(Jid,bool)\0to,from,id,key\0"
    "dialbackVerifyRequest(Jid,Jid,QString,QString)\0"
    "dialbackVerifyResult(Jid,bool)\0s\0incomingXml(QString)\0"
    "outgoingXml(QString)\0continueAfterWarning()\0cr_connected()\0"
    "cr_error()\0bs_connectionClosed()\0bs_delayedCloseFinished()\0"
    "bs_error(int)\0ss_readyRead()\0ss_bytesWritten(int)\0ss_tlsHandshaken()\0"
    "ss_tlsClosed()\0ss_error(int)\0mech,clientInit\0"
    "sasl_clientFirstStep(QString,const QByteArray*)\0stepData\0"
    "sasl_nextStep(QByteArray)\0user,authzid,pass,realm\0"
    "sasl_needParams(bool,bool,bool,bool)\0user,authzid\0"
    "sasl_authCheck(QString,QString)\0sasl_authenticated()\0sasl_error(int)\0"
    "doNoop()\0doReadyRead()\0"
};

const QMetaObject XMPP::ClientStream::staticMetaObject = {
    { &Stream::staticMetaObject, qt_meta_stringdata_XMPP__ClientStream,
      qt_meta_data_XMPP__ClientStream, 0 }
};

const QMetaObject *XMPP::ClientStream::metaObject() const
{
    return &staticMetaObject;
}

void *XMPP::ClientStream::qt_metacast(const char *_clname)
{
    if (!_clname) return 0;
    if (!strcmp(_clname, qt_meta_stringdata_XMPP__ClientStream))
	return static_cast<void*>(const_cast<ClientStream*>(this));
    return Stream::qt_metacast(_clname);
}

int XMPP::ClientStream::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = Stream::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: connected(); break;
        case 1: securityLayerActivated(*reinterpret_cast< int(*)>(_a[1])); break;
        case 2: needAuthParams(*reinterpret_cast< bool(*)>(_a[1]),*reinterpret_cast< bool(*)>(_a[2]),*reinterpret_cast< bool(*)>(_a[3])); break;
        case 3: authenticated(); break;
        case 4: warning(*reinterpret_cast< int(*)>(_a[1])); break;
        case 5: dialbackRequest(*reinterpret_cast< const Jid(*)>(_a[1]),*reinterpret_cast< const Jid(*)>(_a[2]),*reinterpret_cast< const QString(*)>(_a[3])); break;
        case 6: dialbackResult(*reinterpret_cast< const Jid(*)>(_a[1]),*reinterpret_cast< bool(*)>(_a[2])); break;
        case 7: dialbackVerifyRequest(*reinterpret_cast< const Jid(*)>(_a[1]),*reinterpret_cast< const Jid(*)>(_a[2]),*reinterpret_cast< const QString(*)>(_a[3]),*reinterpret_cast< const QString(*)>(_a[4])); break;
        case 8: dialbackVerifyResult(*reinterpret_cast< const Jid(*)>(_a[1]),*reinterpret_cast< bool(*)>(_a[2])); break;
        case 9: incomingXml(*reinterpret_cast< const QString(*)>(_a[1])); break;
        case 10: outgoingXml(*reinterpret_cast< const QString(*)>(_a[1])); break;
        case 11: continueAfterWarning(); break;
        case 12: cr_connected(); break;
        case 13: cr_error(); break;
        case 14: bs_connectionClosed(); break;
        case 15: bs_delayedCloseFinished(); break;
        case 16: bs_error(*reinterpret_cast< int(*)>(_a[1])); break;
        case 17: ss_readyRead(); break;
        case 18: ss_bytesWritten(*reinterpret_cast< int(*)>(_a[1])); break;
        case 19: ss_tlsHandshaken(); break;
        case 20: ss_tlsClosed(); break;
        case 21: ss_error(*reinterpret_cast< int(*)>(_a[1])); break;
        case 22: sasl_clientFirstStep(*reinterpret_cast< const QString(*)>(_a[1]),*reinterpret_cast< const QByteArray*(*)>(_a[2])); break;
        case 23: sasl_nextStep(*reinterpret_cast< const QByteArray(*)>(_a[1])); break;
        case 24: sasl_needParams(*reinterpret_cast< bool(*)>(_a[1]),*reinterpret_cast< bool(*)>(_a[2]),*reinterpret_cast< bool(*)>(_a[3]),*reinterpret_cast< bool(*)>(_a[4])); break;
        case 25: sasl_authCheck(*reinterpret_cast< const QString(*)>(_a[1]),*reinterpret_cast< const QString(*)>(_a[2])); break;
        case 26: sasl_authenticated(); break;
        case 27: sasl_error(*reinterpret_cast< int(*)>(_a[1])); break;
        case 28: doNoop(); break;
        case 29: doReadyRead(); break;
        }
        _id -= 30;
    }
    return _id;
}

// SIGNAL 0
void XMPP::ClientStream::connected()
{
    QMetaObject::activate(this, &staticMetaObject, 0, 0);
}

// SIGNAL 1
void XMPP::ClientStream::securityLayerActivated(int _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 1, _a);
}

// SIGNAL 2
void XMPP::ClientStream::needAuthParams(bool _t1, bool _t2, bool _t3)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)), const_cast<void*>(reinterpret_cast<const void*>(&_t2)), const_cast<void*>(reinterpret_cast<const void*>(&_t3)) };
    QMetaObject::activate(this, &staticMetaObject, 2, _a);
}

// SIGNAL 3
void XMPP::ClientStream::authenticated()
{
    QMetaObject::activate(this, &staticMetaObject, 3, 0);
}

// SIGNAL 4
void XMPP::ClientStream::warning(int _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 4, _a);
}

// SIGNAL 5
void XMPP::ClientStream::dialbackRequest(const Jid & _t1, const Jid & _t2, const QString & _t3)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)), const_cast<void*>(reinterpret_cast<const void*>(&_t2)), const_cast<void*>(reinterpret_cast<const void*>(&_t3)) };
    QMetaObject::activate(this, &staticMetaObject, 5, _a);
}

// SIGNAL 6
void XMPP::ClientStream::dialbackResult(const Jid & _t1, bool _t2)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)), const_cast<void*>(reinterpret_cast<const void*>(&_t2)) };
    QMetaObject::activate(this, &staticMetaObject, 6, _a);
}

// SIGNAL 7
void XMPP::ClientStream::dialbackVerifyRequest(const Jid & _t1, const Jid & _t2, const QString & _t3, const QString & _t4)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)), const_cast<void*>(reinterpret_cast<const void*>(&_t2)), const_cast<void*>(reinterpret_cast<const void*>(&_t3)), const_cast<void*>(reinterpret_cast<const void*>(&_t4)) };
    QMetaObject::activate(this, &staticMetaObject, 7, _a);
}

// SIGNAL 8
void XMPP::ClientStream::dialbackVerifyResult(const Jid & _t1, bool _t2)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)), const_cast<void*>(reinterpret_cast<const void*>(&_t2)) };
    QMetaObject::activate(this, &staticMetaObject, 8, _a);
}

// SIGNAL 9
void XMPP::ClientStream::incomingXml(const QString & _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 9, _a);
}

// SIGNAL 10
void XMPP::ClientStream::outgoingXml(const QString & _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 10, _a);
}
