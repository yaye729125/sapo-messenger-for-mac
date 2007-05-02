/****************************************************************************
** Meta object code from reading C++ file 'irisnetplugin.h'
**
** Created: Thu Jul 20 17:53:29 2006
**      by: The Qt Meta Object Compiler version 59 (Qt 4.1.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../src/ambrosia/iris/irisnet/irisnetplugin.h"
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'irisnetplugin.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 59
#error "This file was generated using the moc from 4.1.1. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

static const uint qt_meta_data_XMPP__IrisNetProvider[] = {

 // content:
       1,       // revision
       0,       // classname
       0,    0, // classinfo
       0,    0, // methods
       0,    0, // properties
       0,    0, // enums/sets

       0        // eod
};

static const char qt_meta_stringdata_XMPP__IrisNetProvider[] = {
    "XMPP::IrisNetProvider\0"
};

const QMetaObject XMPP::IrisNetProvider::staticMetaObject = {
    { &QObject::staticMetaObject, qt_meta_stringdata_XMPP__IrisNetProvider,
      qt_meta_data_XMPP__IrisNetProvider, 0 }
};

const QMetaObject *XMPP::IrisNetProvider::metaObject() const
{
    return &staticMetaObject;
}

void *XMPP::IrisNetProvider::qt_metacast(const char *_clname)
{
    if (!_clname) return 0;
    if (!strcmp(_clname, qt_meta_stringdata_XMPP__IrisNetProvider))
	return static_cast<void*>(const_cast<IrisNetProvider*>(this));
    return QObject::qt_metacast(_clname);
}

int XMPP::IrisNetProvider::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    return _id;
}
static const uint qt_meta_data_XMPP__NetInterfaceProvider[] = {

 // content:
       1,       // revision
       0,       // classname
       0,    0, // classinfo
       1,   10, // methods
       0,    0, // properties
       0,    0, // enums/sets

 // signals: signature, parameters, type, tag, flags
      28,   27,   27,   27, 0x05,

       0        // eod
};

static const char qt_meta_stringdata_XMPP__NetInterfaceProvider[] = {
    "XMPP::NetInterfaceProvider\0\0updated()\0"
};

const QMetaObject XMPP::NetInterfaceProvider::staticMetaObject = {
    { &QObject::staticMetaObject, qt_meta_stringdata_XMPP__NetInterfaceProvider,
      qt_meta_data_XMPP__NetInterfaceProvider, 0 }
};

const QMetaObject *XMPP::NetInterfaceProvider::metaObject() const
{
    return &staticMetaObject;
}

void *XMPP::NetInterfaceProvider::qt_metacast(const char *_clname)
{
    if (!_clname) return 0;
    if (!strcmp(_clname, qt_meta_stringdata_XMPP__NetInterfaceProvider))
	return static_cast<void*>(const_cast<NetInterfaceProvider*>(this));
    return QObject::qt_metacast(_clname);
}

int XMPP::NetInterfaceProvider::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: updated(); break;
        }
        _id -= 1;
    }
    return _id;
}

// SIGNAL 0
void XMPP::NetInterfaceProvider::updated()
{
    QMetaObject::activate(this, &staticMetaObject, 0, 0);
}
static const uint qt_meta_data_XMPP__NameProvider[] = {

 // content:
       1,       // revision
       0,       // classname
       0,    0, // classinfo
       3,   10, // methods
       0,    0, // properties
       0,    0, // enums/sets

 // signals: signature, parameters, type, tag, flags
      31,   20,   19,   19, 0x05,
      86,   81,   19,   19, 0x05,
     139,  131,   19,   19, 0x05,

       0        // eod
};

static const char qt_meta_stringdata_XMPP__NameProvider[] = {
    "XMPP::NameProvider\0\0id,results\0"
    "resolve_resultsReady(int,QList<XMPP::NameRecord>)\0id,e\0"
    "resolve_error(int,XMPP::NameResolver::Error)\0id,name\0"
    "resolve_useLocal(int,QByteArray)\0"
};

const QMetaObject XMPP::NameProvider::staticMetaObject = {
    { &QObject::staticMetaObject, qt_meta_stringdata_XMPP__NameProvider,
      qt_meta_data_XMPP__NameProvider, 0 }
};

const QMetaObject *XMPP::NameProvider::metaObject() const
{
    return &staticMetaObject;
}

void *XMPP::NameProvider::qt_metacast(const char *_clname)
{
    if (!_clname) return 0;
    if (!strcmp(_clname, qt_meta_stringdata_XMPP__NameProvider))
	return static_cast<void*>(const_cast<NameProvider*>(this));
    return QObject::qt_metacast(_clname);
}

int XMPP::NameProvider::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: resolve_resultsReady(*reinterpret_cast< int(*)>(_a[1]),*reinterpret_cast< const QList<XMPP::NameRecord>(*)>(_a[2])); break;
        case 1: resolve_error(*reinterpret_cast< int(*)>(_a[1]),*reinterpret_cast< XMPP::NameResolver::Error(*)>(_a[2])); break;
        case 2: resolve_useLocal(*reinterpret_cast< int(*)>(_a[1]),*reinterpret_cast< const QByteArray(*)>(_a[2])); break;
        }
        _id -= 3;
    }
    return _id;
}

// SIGNAL 0
void XMPP::NameProvider::resolve_resultsReady(int _t1, const QList<XMPP::NameRecord> & _t2)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)), const_cast<void*>(reinterpret_cast<const void*>(&_t2)) };
    QMetaObject::activate(this, &staticMetaObject, 0, _a);
}

// SIGNAL 1
void XMPP::NameProvider::resolve_error(int _t1, XMPP::NameResolver::Error _t2)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)), const_cast<void*>(reinterpret_cast<const void*>(&_t2)) };
    QMetaObject::activate(this, &staticMetaObject, 1, _a);
}

// SIGNAL 2
void XMPP::NameProvider::resolve_useLocal(int _t1, const QByteArray & _t2)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)), const_cast<void*>(reinterpret_cast<const void*>(&_t2)) };
    QMetaObject::activate(this, &staticMetaObject, 2, _a);
}
static const uint qt_meta_data_XMPP__ServiceProvider[] = {

 // content:
       1,       // revision
       0,       // classname
       0,    0, // classinfo
       9,   10, // methods
       0,    0, // properties
       0,    0, // enums/sets

 // signals: signature, parameters, type, tag, flags
      35,   23,   22,   22, 0x05,
      87,   23,   22,   22, 0x05,
     144,  141,   22,   22, 0x05,
     178,  162,   22,   22, 0x05,
     221,  141,   22,   22, 0x05,
     240,  141,   22,   22, 0x05,
     268,  263,   22,   22, 0x05,
     322,  141,   22,   22, 0x05,
     351,  263,   22,   22, 0x05,

       0        // eod
};

static const char qt_meta_stringdata_XMPP__ServiceProvider[] = {
    "XMPP::ServiceProvider\0\0id,instance\0"
    "browse_instanceAvailable(int,XMPP::ServiceInstance)\0"
    "browse_instanceUnavailable(int,XMPP::ServiceInstance)\0id\0"
    "browse_error(int)\0id,address,port\0"
    "resolve_resultsReady(int,QHostAddress,int)\0resolve_error(int)\0"
    "publish_published(int)\0id,e\0"
    "publish_error(int,XMPP::ServiceLocalPublisher::Error)\0"
    "publish_extra_published(int)\0"
    "publish_extra_error(int,XMPP::ServiceLocalPublisher::Error)\0"
};

const QMetaObject XMPP::ServiceProvider::staticMetaObject = {
    { &QObject::staticMetaObject, qt_meta_stringdata_XMPP__ServiceProvider,
      qt_meta_data_XMPP__ServiceProvider, 0 }
};

const QMetaObject *XMPP::ServiceProvider::metaObject() const
{
    return &staticMetaObject;
}

void *XMPP::ServiceProvider::qt_metacast(const char *_clname)
{
    if (!_clname) return 0;
    if (!strcmp(_clname, qt_meta_stringdata_XMPP__ServiceProvider))
	return static_cast<void*>(const_cast<ServiceProvider*>(this));
    return QObject::qt_metacast(_clname);
}

int XMPP::ServiceProvider::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: browse_instanceAvailable(*reinterpret_cast< int(*)>(_a[1]),*reinterpret_cast< const XMPP::ServiceInstance(*)>(_a[2])); break;
        case 1: browse_instanceUnavailable(*reinterpret_cast< int(*)>(_a[1]),*reinterpret_cast< const XMPP::ServiceInstance(*)>(_a[2])); break;
        case 2: browse_error(*reinterpret_cast< int(*)>(_a[1])); break;
        case 3: resolve_resultsReady(*reinterpret_cast< int(*)>(_a[1]),*reinterpret_cast< const QHostAddress(*)>(_a[2]),*reinterpret_cast< int(*)>(_a[3])); break;
        case 4: resolve_error(*reinterpret_cast< int(*)>(_a[1])); break;
        case 5: publish_published(*reinterpret_cast< int(*)>(_a[1])); break;
        case 6: publish_error(*reinterpret_cast< int(*)>(_a[1]),*reinterpret_cast< XMPP::ServiceLocalPublisher::Error(*)>(_a[2])); break;
        case 7: publish_extra_published(*reinterpret_cast< int(*)>(_a[1])); break;
        case 8: publish_extra_error(*reinterpret_cast< int(*)>(_a[1]),*reinterpret_cast< XMPP::ServiceLocalPublisher::Error(*)>(_a[2])); break;
        }
        _id -= 9;
    }
    return _id;
}

// SIGNAL 0
void XMPP::ServiceProvider::browse_instanceAvailable(int _t1, const XMPP::ServiceInstance & _t2)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)), const_cast<void*>(reinterpret_cast<const void*>(&_t2)) };
    QMetaObject::activate(this, &staticMetaObject, 0, _a);
}

// SIGNAL 1
void XMPP::ServiceProvider::browse_instanceUnavailable(int _t1, const XMPP::ServiceInstance & _t2)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)), const_cast<void*>(reinterpret_cast<const void*>(&_t2)) };
    QMetaObject::activate(this, &staticMetaObject, 1, _a);
}

// SIGNAL 2
void XMPP::ServiceProvider::browse_error(int _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 2, _a);
}

// SIGNAL 3
void XMPP::ServiceProvider::resolve_resultsReady(int _t1, const QHostAddress & _t2, int _t3)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)), const_cast<void*>(reinterpret_cast<const void*>(&_t2)), const_cast<void*>(reinterpret_cast<const void*>(&_t3)) };
    QMetaObject::activate(this, &staticMetaObject, 3, _a);
}

// SIGNAL 4
void XMPP::ServiceProvider::resolve_error(int _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 4, _a);
}

// SIGNAL 5
void XMPP::ServiceProvider::publish_published(int _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 5, _a);
}

// SIGNAL 6
void XMPP::ServiceProvider::publish_error(int _t1, XMPP::ServiceLocalPublisher::Error _t2)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)), const_cast<void*>(reinterpret_cast<const void*>(&_t2)) };
    QMetaObject::activate(this, &staticMetaObject, 6, _a);
}

// SIGNAL 7
void XMPP::ServiceProvider::publish_extra_published(int _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 7, _a);
}

// SIGNAL 8
void XMPP::ServiceProvider::publish_extra_error(int _t1, XMPP::ServiceLocalPublisher::Error _t2)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)), const_cast<void*>(reinterpret_cast<const void*>(&_t2)) };
    QMetaObject::activate(this, &staticMetaObject, 8, _a);
}
