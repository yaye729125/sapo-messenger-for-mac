/****************************************************************************
** Meta object code from reading C++ file 'httppoll.h'
**
** Created: Thu Jul 20 17:53:24 2006
**      by: The Qt Meta Object Compiler version 59 (Qt 4.1.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../src/ambrosia/cutestuff/network/httppoll.h"
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'httppoll.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 59
#error "This file was generated using the moc from 4.1.1. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

static const uint qt_meta_data_HttpPoll[] = {

 // content:
       1,       // revision
       0,       // classname
       0,    0, // classinfo
       6,   10, // methods
       0,    0, // properties
       0,    0, // enums/sets

 // signals: signature, parameters, type, tag, flags
      10,    9,    9,    9, 0x05,
      22,    9,    9,    9, 0x05,
      36,    9,    9,    9, 0x05,

 // slots: signature, parameters, type, tag, flags
      51,    9,    9,    9, 0x08,
      65,    9,    9,    9, 0x08,
      81,    9,    9,    9, 0x08,

       0        // eod
};

static const char qt_meta_stringdata_HttpPoll[] = {
    "HttpPoll\0\0connected()\0syncStarted()\0syncFinished()\0http_result()\0"
    "http_error(int)\0do_sync()\0"
};

const QMetaObject HttpPoll::staticMetaObject = {
    { &ByteStream::staticMetaObject, qt_meta_stringdata_HttpPoll,
      qt_meta_data_HttpPoll, 0 }
};

const QMetaObject *HttpPoll::metaObject() const
{
    return &staticMetaObject;
}

void *HttpPoll::qt_metacast(const char *_clname)
{
    if (!_clname) return 0;
    if (!strcmp(_clname, qt_meta_stringdata_HttpPoll))
	return static_cast<void*>(const_cast<HttpPoll*>(this));
    return ByteStream::qt_metacast(_clname);
}

int HttpPoll::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = ByteStream::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: connected(); break;
        case 1: syncStarted(); break;
        case 2: syncFinished(); break;
        case 3: http_result(); break;
        case 4: http_error(*reinterpret_cast< int(*)>(_a[1])); break;
        case 5: do_sync(); break;
        }
        _id -= 6;
    }
    return _id;
}

// SIGNAL 0
void HttpPoll::connected()
{
    QMetaObject::activate(this, &staticMetaObject, 0, 0);
}

// SIGNAL 1
void HttpPoll::syncStarted()
{
    QMetaObject::activate(this, &staticMetaObject, 1, 0);
}

// SIGNAL 2
void HttpPoll::syncFinished()
{
    QMetaObject::activate(this, &staticMetaObject, 2, 0);
}
static const uint qt_meta_data_HttpProxyPost[] = {

 // content:
       1,       // revision
       0,       // classname
       0,    0, // classinfo
       6,   10, // methods
       0,    0, // properties
       0,    0, // enums/sets

 // signals: signature, parameters, type, tag, flags
      15,   14,   14,   14, 0x05,
      24,   14,   14,   14, 0x05,

 // slots: signature, parameters, type, tag, flags
      35,   14,   14,   14, 0x08,
      52,   14,   14,   14, 0x08,
      76,   14,   14,   14, 0x08,
      93,   14,   14,   14, 0x08,

       0        // eod
};

static const char qt_meta_stringdata_HttpProxyPost[] = {
    "HttpProxyPost\0\0result()\0error(int)\0sock_connected()\0"
    "sock_connectionClosed()\0sock_readyRead()\0sock_error(int)\0"
};

const QMetaObject HttpProxyPost::staticMetaObject = {
    { &QObject::staticMetaObject, qt_meta_stringdata_HttpProxyPost,
      qt_meta_data_HttpProxyPost, 0 }
};

const QMetaObject *HttpProxyPost::metaObject() const
{
    return &staticMetaObject;
}

void *HttpProxyPost::qt_metacast(const char *_clname)
{
    if (!_clname) return 0;
    if (!strcmp(_clname, qt_meta_stringdata_HttpProxyPost))
	return static_cast<void*>(const_cast<HttpProxyPost*>(this));
    return QObject::qt_metacast(_clname);
}

int HttpProxyPost::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: result(); break;
        case 1: error(*reinterpret_cast< int(*)>(_a[1])); break;
        case 2: sock_connected(); break;
        case 3: sock_connectionClosed(); break;
        case 4: sock_readyRead(); break;
        case 5: sock_error(*reinterpret_cast< int(*)>(_a[1])); break;
        }
        _id -= 6;
    }
    return _id;
}

// SIGNAL 0
void HttpProxyPost::result()
{
    QMetaObject::activate(this, &staticMetaObject, 0, 0);
}

// SIGNAL 1
void HttpProxyPost::error(int _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 1, _a);
}
