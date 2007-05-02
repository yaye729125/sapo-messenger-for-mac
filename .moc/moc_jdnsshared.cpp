/****************************************************************************
** Meta object code from reading C++ file 'jdnsshared.h'
**
** Created: Thu Jul 20 17:53:28 2006
**      by: The Qt Meta Object Compiler version 59 (Qt 4.1.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../src/ambrosia/iris/irisnet/jdnsshared.h"
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'jdnsshared.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 59
#error "This file was generated using the moc from 4.1.1. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

static const uint qt_meta_data_XMPP__JDnsSharedDebug[] = {

 // content:
       1,       // revision
       0,       // classname
       0,    0, // classinfo
       2,   10, // methods
       0,    0, // properties
       0,    0, // enums/sets

 // signals: signature, parameters, type, tag, flags
      29,   23,   22,   22, 0x05,

 // slots: signature, parameters, type, tag, flags
      48,   22,   22,   22, 0x08,

       0        // eod
};

static const char qt_meta_stringdata_XMPP__JDnsSharedDebug[] = {
    "XMPP::JDnsSharedDebug\0\0lines\0debug(QStringList)\0doUpdate()\0"
};

const QMetaObject XMPP::JDnsSharedDebug::staticMetaObject = {
    { &QObject::staticMetaObject, qt_meta_stringdata_XMPP__JDnsSharedDebug,
      qt_meta_data_XMPP__JDnsSharedDebug, 0 }
};

const QMetaObject *XMPP::JDnsSharedDebug::metaObject() const
{
    return &staticMetaObject;
}

void *XMPP::JDnsSharedDebug::qt_metacast(const char *_clname)
{
    if (!_clname) return 0;
    if (!strcmp(_clname, qt_meta_stringdata_XMPP__JDnsSharedDebug))
	return static_cast<void*>(const_cast<JDnsSharedDebug*>(this));
    return QObject::qt_metacast(_clname);
}

int XMPP::JDnsSharedDebug::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: debug(*reinterpret_cast< const QStringList(*)>(_a[1])); break;
        case 1: doUpdate(); break;
        }
        _id -= 2;
    }
    return _id;
}

// SIGNAL 0
void XMPP::JDnsSharedDebug::debug(const QStringList & _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 0, _a);
}
static const uint qt_meta_data_XMPP__JDnsSharedRequest[] = {

 // content:
       1,       // revision
       0,       // classname
       0,    0, // classinfo
       1,   10, // methods
       0,    0, // properties
       0,    0, // enums/sets

 // signals: signature, parameters, type, tag, flags
      25,   24,   24,   24, 0x05,

       0        // eod
};

static const char qt_meta_stringdata_XMPP__JDnsSharedRequest[] = {
    "XMPP::JDnsSharedRequest\0\0resultsReady()\0"
};

const QMetaObject XMPP::JDnsSharedRequest::staticMetaObject = {
    { &QObject::staticMetaObject, qt_meta_stringdata_XMPP__JDnsSharedRequest,
      qt_meta_data_XMPP__JDnsSharedRequest, 0 }
};

const QMetaObject *XMPP::JDnsSharedRequest::metaObject() const
{
    return &staticMetaObject;
}

void *XMPP::JDnsSharedRequest::qt_metacast(const char *_clname)
{
    if (!_clname) return 0;
    if (!strcmp(_clname, qt_meta_stringdata_XMPP__JDnsSharedRequest))
	return static_cast<void*>(const_cast<JDnsSharedRequest*>(this));
    return QObject::qt_metacast(_clname);
}

int XMPP::JDnsSharedRequest::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: resultsReady(); break;
        }
        _id -= 1;
    }
    return _id;
}

// SIGNAL 0
void XMPP::JDnsSharedRequest::resultsReady()
{
    QMetaObject::activate(this, &staticMetaObject, 0, 0);
}
static const uint qt_meta_data_XMPP__JDnsShared[] = {

 // content:
       1,       // revision
       0,       // classname
       0,    0, // classinfo
       7,   10, // methods
       0,    0, // properties
       0,    0, // enums/sets

 // signals: signature, parameters, type, tag, flags
      18,   17,   17,   17, 0x05,
      43,   37,   17,   17, 0x05,

 // slots: signature, parameters, type, tag, flags
      73,   62,   17,   17, 0x08,
     115,  112,   17,   17, 0x08,
     140,  135,   17,   17, 0x08,
     169,   17,   17,   17, 0x08,
     193,   17,   17,   17, 0x08,

       0        // eod
};

static const char qt_meta_stringdata_XMPP__JDnsShared[] = {
    "XMPP::JDnsShared\0\0shutdownFinished()\0lines\0debug(QStringList)\0"
    "id,results\0jdns_resultsReady(int,QJDns::Response)\0id\0"
    "jdns_published(int)\0id,e\0jdns_error(int,QJDns::Error)\0"
    "jdns_shutdownFinished()\0jdns_debugLinesReady()\0"
};

const QMetaObject XMPP::JDnsShared::staticMetaObject = {
    { &QObject::staticMetaObject, qt_meta_stringdata_XMPP__JDnsShared,
      qt_meta_data_XMPP__JDnsShared, 0 }
};

const QMetaObject *XMPP::JDnsShared::metaObject() const
{
    return &staticMetaObject;
}

void *XMPP::JDnsShared::qt_metacast(const char *_clname)
{
    if (!_clname) return 0;
    if (!strcmp(_clname, qt_meta_stringdata_XMPP__JDnsShared))
	return static_cast<void*>(const_cast<JDnsShared*>(this));
    return QObject::qt_metacast(_clname);
}

int XMPP::JDnsShared::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: shutdownFinished(); break;
        case 1: debug(*reinterpret_cast< const QStringList(*)>(_a[1])); break;
        case 2: jdns_resultsReady(*reinterpret_cast< int(*)>(_a[1]),*reinterpret_cast< const QJDns::Response(*)>(_a[2])); break;
        case 3: jdns_published(*reinterpret_cast< int(*)>(_a[1])); break;
        case 4: jdns_error(*reinterpret_cast< int(*)>(_a[1]),*reinterpret_cast< QJDns::Error(*)>(_a[2])); break;
        case 5: jdns_shutdownFinished(); break;
        case 6: jdns_debugLinesReady(); break;
        }
        _id -= 7;
    }
    return _id;
}

// SIGNAL 0
void XMPP::JDnsShared::shutdownFinished()
{
    QMetaObject::activate(this, &staticMetaObject, 0, 0);
}

// SIGNAL 1
void XMPP::JDnsShared::debug(const QStringList & _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 1, _a);
}
