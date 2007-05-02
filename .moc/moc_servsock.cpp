/****************************************************************************
** Meta object code from reading C++ file 'servsock.h'
**
** Created: Thu Jul 20 17:53:37 2006
**      by: The Qt Meta Object Compiler version 59 (Qt 4.1.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../src/ambrosia/iris/irisnet/legacy/servsock.h"
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'servsock.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 59
#error "This file was generated using the moc from 4.1.1. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

static const uint qt_meta_data_ServSock[] = {

 // content:
       1,       // revision
       0,       // classname
       0,    0, // classinfo
       2,   10, // methods
       0,    0, // properties
       0,    0, // enums/sets

 // signals: signature, parameters, type, tag, flags
      10,    9,    9,    9, 0x05,

 // slots: signature, parameters, type, tag, flags
      31,    9,    9,    9, 0x08,

       0        // eod
};

static const char qt_meta_stringdata_ServSock[] = {
    "ServSock\0\0connectionReady(int)\0sss_connectionReady(int)\0"
};

const QMetaObject ServSock::staticMetaObject = {
    { &QObject::staticMetaObject, qt_meta_stringdata_ServSock,
      qt_meta_data_ServSock, 0 }
};

const QMetaObject *ServSock::metaObject() const
{
    return &staticMetaObject;
}

void *ServSock::qt_metacast(const char *_clname)
{
    if (!_clname) return 0;
    if (!strcmp(_clname, qt_meta_stringdata_ServSock))
	return static_cast<void*>(const_cast<ServSock*>(this));
    return QObject::qt_metacast(_clname);
}

int ServSock::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: connectionReady(*reinterpret_cast< int(*)>(_a[1])); break;
        case 1: sss_connectionReady(*reinterpret_cast< int(*)>(_a[1])); break;
        }
        _id -= 2;
    }
    return _id;
}

// SIGNAL 0
void ServSock::connectionReady(int _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 0, _a);
}
static const uint qt_meta_data_ServSockSignal[] = {

 // content:
       1,       // revision
       0,       // classname
       0,    0, // classinfo
       1,   10, // methods
       0,    0, // properties
       0,    0, // enums/sets

 // signals: signature, parameters, type, tag, flags
      16,   15,   15,   15, 0x05,

       0        // eod
};

static const char qt_meta_stringdata_ServSockSignal[] = {
    "ServSockSignal\0\0connectionReady(int)\0"
};

const QMetaObject ServSockSignal::staticMetaObject = {
    { &QTcpServer::staticMetaObject, qt_meta_stringdata_ServSockSignal,
      qt_meta_data_ServSockSignal, 0 }
};

const QMetaObject *ServSockSignal::metaObject() const
{
    return &staticMetaObject;
}

void *ServSockSignal::qt_metacast(const char *_clname)
{
    if (!_clname) return 0;
    if (!strcmp(_clname, qt_meta_stringdata_ServSockSignal))
	return static_cast<void*>(const_cast<ServSockSignal*>(this));
    return QTcpServer::qt_metacast(_clname);
}

int ServSockSignal::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QTcpServer::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: connectionReady(*reinterpret_cast< int(*)>(_a[1])); break;
        }
        _id -= 1;
    }
    return _id;
}

// SIGNAL 0
void ServSockSignal::connectionReady(int _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 0, _a);
}
