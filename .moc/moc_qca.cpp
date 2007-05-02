/****************************************************************************
** Meta object code from reading C++ file 'qca.h'
**
** Created: Thu Jul 20 17:53:19 2006
**      by: The Qt Meta Object Compiler version 59 (Qt 4.1.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../src/ambrosia/qca/qca.h"
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'qca.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 59
#error "This file was generated using the moc from 4.1.1. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

static const uint qt_meta_data_QCA__TLS[] = {

 // content:
       1,       // revision
       0,       // classname
       0,    0, // classinfo
       6,   10, // methods
       0,    0, // properties
       0,    0, // enums/sets

 // signals: signature, parameters, type, tag, flags
      10,    9,    9,    9, 0x05,
      23,    9,    9,    9, 0x05,
      46,   35,    9,    9, 0x05,
      69,    9,    9,    9, 0x05,
      78,    9,    9,    9, 0x05,

 // slots: signature, parameters, type, tag, flags
      89,    9,    9,    9, 0x08,

       0        // eod
};

static const char qt_meta_stringdata_QCA__TLS[] = {
    "QCA::TLS\0\0handshaken()\0readyRead()\0plainBytes\0"
    "readyReadOutgoing(int)\0closed()\0error(int)\0update()\0"
};

const QMetaObject QCA::TLS::staticMetaObject = {
    { &QObject::staticMetaObject, qt_meta_stringdata_QCA__TLS,
      qt_meta_data_QCA__TLS, 0 }
};

const QMetaObject *QCA::TLS::metaObject() const
{
    return &staticMetaObject;
}

void *QCA::TLS::qt_metacast(const char *_clname)
{
    if (!_clname) return 0;
    if (!strcmp(_clname, qt_meta_stringdata_QCA__TLS))
	return static_cast<void*>(const_cast<TLS*>(this));
    return QObject::qt_metacast(_clname);
}

int QCA::TLS::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: handshaken(); break;
        case 1: readyRead(); break;
        case 2: readyReadOutgoing(*reinterpret_cast< int(*)>(_a[1])); break;
        case 3: closed(); break;
        case 4: error(*reinterpret_cast< int(*)>(_a[1])); break;
        case 5: update(); break;
        }
        _id -= 6;
    }
    return _id;
}

// SIGNAL 0
void QCA::TLS::handshaken()
{
    QMetaObject::activate(this, &staticMetaObject, 0, 0);
}

// SIGNAL 1
void QCA::TLS::readyRead()
{
    QMetaObject::activate(this, &staticMetaObject, 1, 0);
}

// SIGNAL 2
void QCA::TLS::readyReadOutgoing(int _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 2, _a);
}

// SIGNAL 3
void QCA::TLS::closed()
{
    QMetaObject::activate(this, &staticMetaObject, 3, 0);
}

// SIGNAL 4
void QCA::TLS::error(int _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 4, _a);
}
static const uint qt_meta_data_QCA__SASL[] = {

 // content:
       1,       // revision
       0,       // classname
       0,    0, // classinfo
       9,   10, // methods
       0,    0, // properties
       0,    0, // enums/sets

 // signals: signature, parameters, type, tag, flags
      27,   11,   10,   10, 0x05,
      79,   70,   10,   10, 0x05,
     124,  100,   10,   10, 0x05,
     169,  156,   10,   10, 0x05,
     196,   10,   10,   10, 0x05,
     212,   10,   10,   10, 0x05,
     235,  224,   10,   10, 0x05,
     258,   10,   10,   10, 0x05,

 // slots: signature, parameters, type, tag, flags
     269,   10,   10,   10, 0x08,

       0        // eod
};

static const char qt_meta_stringdata_QCA__SASL[] = {
    "QCA::SASL\0\0mech,clientInit\0"
    "clientFirstStep(QString,const QByteArray*)\0stepData\0"
    "nextStep(QByteArray)\0user,authzid,pass,realm\0"
    "needParams(bool,bool,bool,bool)\0user,authzid\0"
    "authCheck(QString,QString)\0authenticated()\0readyRead()\0plainBytes\0"
    "readyReadOutgoing(int)\0error(int)\0tryAgain()\0"
};

const QMetaObject QCA::SASL::staticMetaObject = {
    { &QObject::staticMetaObject, qt_meta_stringdata_QCA__SASL,
      qt_meta_data_QCA__SASL, 0 }
};

const QMetaObject *QCA::SASL::metaObject() const
{
    return &staticMetaObject;
}

void *QCA::SASL::qt_metacast(const char *_clname)
{
    if (!_clname) return 0;
    if (!strcmp(_clname, qt_meta_stringdata_QCA__SASL))
	return static_cast<void*>(const_cast<SASL*>(this));
    return QObject::qt_metacast(_clname);
}

int QCA::SASL::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: clientFirstStep(*reinterpret_cast< const QString(*)>(_a[1]),*reinterpret_cast< const QByteArray*(*)>(_a[2])); break;
        case 1: nextStep(*reinterpret_cast< const QByteArray(*)>(_a[1])); break;
        case 2: needParams(*reinterpret_cast< bool(*)>(_a[1]),*reinterpret_cast< bool(*)>(_a[2]),*reinterpret_cast< bool(*)>(_a[3]),*reinterpret_cast< bool(*)>(_a[4])); break;
        case 3: authCheck(*reinterpret_cast< const QString(*)>(_a[1]),*reinterpret_cast< const QString(*)>(_a[2])); break;
        case 4: authenticated(); break;
        case 5: readyRead(); break;
        case 6: readyReadOutgoing(*reinterpret_cast< int(*)>(_a[1])); break;
        case 7: error(*reinterpret_cast< int(*)>(_a[1])); break;
        case 8: tryAgain(); break;
        }
        _id -= 9;
    }
    return _id;
}

// SIGNAL 0
void QCA::SASL::clientFirstStep(const QString & _t1, const QByteArray * _t2)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)), const_cast<void*>(reinterpret_cast<const void*>(&_t2)) };
    QMetaObject::activate(this, &staticMetaObject, 0, _a);
}

// SIGNAL 1
void QCA::SASL::nextStep(const QByteArray & _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 1, _a);
}

// SIGNAL 2
void QCA::SASL::needParams(bool _t1, bool _t2, bool _t3, bool _t4)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)), const_cast<void*>(reinterpret_cast<const void*>(&_t2)), const_cast<void*>(reinterpret_cast<const void*>(&_t3)), const_cast<void*>(reinterpret_cast<const void*>(&_t4)) };
    QMetaObject::activate(this, &staticMetaObject, 2, _a);
}

// SIGNAL 3
void QCA::SASL::authCheck(const QString & _t1, const QString & _t2)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)), const_cast<void*>(reinterpret_cast<const void*>(&_t2)) };
    QMetaObject::activate(this, &staticMetaObject, 3, _a);
}

// SIGNAL 4
void QCA::SASL::authenticated()
{
    QMetaObject::activate(this, &staticMetaObject, 4, 0);
}

// SIGNAL 5
void QCA::SASL::readyRead()
{
    QMetaObject::activate(this, &staticMetaObject, 5, 0);
}

// SIGNAL 6
void QCA::SASL::readyReadOutgoing(int _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 6, _a);
}

// SIGNAL 7
void QCA::SASL::error(int _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 7, _a);
}
