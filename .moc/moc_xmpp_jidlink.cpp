/****************************************************************************
** Meta object code from reading C++ file 'xmpp_jidlink.h'
**
** Created: Thu Jul 20 17:53:44 2006
**      by: The Qt Meta Object Compiler version 59 (Qt 4.1.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../src/ambrosia/iris/jabber/xmpp_jidlink.h"
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'xmpp_jidlink.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 59
#error "This file was generated using the moc from 4.1.1. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

static const uint qt_meta_data_XMPP__JidLink[] = {

 // content:
       1,       // revision
       0,       // classname
       0,    0, // classinfo
      14,   10, // methods
       0,    0, // properties
       0,    0, // enums/sets

 // signals: signature, parameters, type, tag, flags
      15,   14,   14,   14, 0x05,
      27,   14,   14,   14, 0x05,
      46,   14,   14,   14, 0x05,
      58,   14,   14,   14, 0x05,
      76,   14,   14,   14, 0x05,
      87,   14,   14,   14, 0x05,

 // slots: signature, parameters, type, tag, flags
      99,   14,   14,   14, 0x08,
     116,   14,   14,   14, 0x08,
     132,   14,   14,   14, 0x08,
     148,   14,   14,   14, 0x08,
     170,   14,   14,   14, 0x08,
     184,   14,   14,   14, 0x08,
     199,   14,   14,   14, 0x08,
     220,   14,   14,   14, 0x08,

       0        // eod
};

static const char qt_meta_stringdata_XMPP__JidLink[] = {
    "XMPP::JidLink\0\0connected()\0connectionClosed()\0readyRead()\0"
    "bytesWritten(int)\0error(int)\0status(int)\0dtcp_connected()\0"
    "dtcp_accepted()\0ibb_connected()\0bs_connectionClosed()\0bs_error(int)\0"
    "bs_readyRead()\0bs_bytesWritten(int)\0doRealAccept()\0"
};

const QMetaObject XMPP::JidLink::staticMetaObject = {
    { &QObject::staticMetaObject, qt_meta_stringdata_XMPP__JidLink,
      qt_meta_data_XMPP__JidLink, 0 }
};

const QMetaObject *XMPP::JidLink::metaObject() const
{
    return &staticMetaObject;
}

void *XMPP::JidLink::qt_metacast(const char *_clname)
{
    if (!_clname) return 0;
    if (!strcmp(_clname, qt_meta_stringdata_XMPP__JidLink))
	return static_cast<void*>(const_cast<JidLink*>(this));
    return QObject::qt_metacast(_clname);
}

int XMPP::JidLink::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: connected(); break;
        case 1: connectionClosed(); break;
        case 2: readyRead(); break;
        case 3: bytesWritten(*reinterpret_cast< int(*)>(_a[1])); break;
        case 4: error(*reinterpret_cast< int(*)>(_a[1])); break;
        case 5: status(*reinterpret_cast< int(*)>(_a[1])); break;
        case 6: dtcp_connected(); break;
        case 7: dtcp_accepted(); break;
        case 8: ibb_connected(); break;
        case 9: bs_connectionClosed(); break;
        case 10: bs_error(*reinterpret_cast< int(*)>(_a[1])); break;
        case 11: bs_readyRead(); break;
        case 12: bs_bytesWritten(*reinterpret_cast< int(*)>(_a[1])); break;
        case 13: doRealAccept(); break;
        }
        _id -= 14;
    }
    return _id;
}

// SIGNAL 0
void XMPP::JidLink::connected()
{
    QMetaObject::activate(this, &staticMetaObject, 0, 0);
}

// SIGNAL 1
void XMPP::JidLink::connectionClosed()
{
    QMetaObject::activate(this, &staticMetaObject, 1, 0);
}

// SIGNAL 2
void XMPP::JidLink::readyRead()
{
    QMetaObject::activate(this, &staticMetaObject, 2, 0);
}

// SIGNAL 3
void XMPP::JidLink::bytesWritten(int _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 3, _a);
}

// SIGNAL 4
void XMPP::JidLink::error(int _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 4, _a);
}

// SIGNAL 5
void XMPP::JidLink::status(int _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 5, _a);
}
static const uint qt_meta_data_XMPP__JidLinkManager[] = {

 // content:
       1,       // revision
       0,       // classname
       0,    0, // classinfo
       0,    0, // methods
       0,    0, // properties
       0,    0, // enums/sets

       0        // eod
};

static const char qt_meta_stringdata_XMPP__JidLinkManager[] = {
    "XMPP::JidLinkManager\0"
};

const QMetaObject XMPP::JidLinkManager::staticMetaObject = {
    { &QObject::staticMetaObject, qt_meta_stringdata_XMPP__JidLinkManager,
      qt_meta_data_XMPP__JidLinkManager, 0 }
};

const QMetaObject *XMPP::JidLinkManager::metaObject() const
{
    return &staticMetaObject;
}

void *XMPP::JidLinkManager::qt_metacast(const char *_clname)
{
    if (!_clname) return 0;
    if (!strcmp(_clname, qt_meta_stringdata_XMPP__JidLinkManager))
	return static_cast<void*>(const_cast<JidLinkManager*>(this));
    return QObject::qt_metacast(_clname);
}

int XMPP::JidLinkManager::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    return _id;
}
