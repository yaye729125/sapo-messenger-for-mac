/****************************************************************************
** Meta object code from reading C++ file 'ndns.h'
**
** Created: Thu Jul 20 17:53:35 2006
**      by: The Qt Meta Object Compiler version 59 (Qt 4.1.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../src/ambrosia/iris/irisnet/legacy/ndns.h"
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'ndns.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 59
#error "This file was generated using the moc from 4.1.1. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

static const uint qt_meta_data_NDns[] = {

 // content:
       1,       // revision
       0,       // classname
       0,    0, // classinfo
       3,   10, // methods
       0,    0, // properties
       0,    0, // enums/sets

 // signals: signature, parameters, type, tag, flags
       6,    5,    5,    5, 0x05,

 // slots: signature, parameters, type, tag, flags
      21,    5,    5,    5, 0x08,
      63,    5,    5,    5, 0x08,

       0        // eod
};

static const char qt_meta_stringdata_NDns[] = {
    "NDns\0\0resultsReady()\0dns_resultsReady(QList<XMPP::NameRecord>)\0"
    "dns_error(XMPP::NameResolver::Error)\0"
};

const QMetaObject NDns::staticMetaObject = {
    { &QObject::staticMetaObject, qt_meta_stringdata_NDns,
      qt_meta_data_NDns, 0 }
};

const QMetaObject *NDns::metaObject() const
{
    return &staticMetaObject;
}

void *NDns::qt_metacast(const char *_clname)
{
    if (!_clname) return 0;
    if (!strcmp(_clname, qt_meta_stringdata_NDns))
	return static_cast<void*>(const_cast<NDns*>(this));
    return QObject::qt_metacast(_clname);
}

int NDns::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: resultsReady(); break;
        case 1: dns_resultsReady(*reinterpret_cast< const QList<XMPP::NameRecord>(*)>(_a[1])); break;
        case 2: dns_error(*reinterpret_cast< XMPP::NameResolver::Error(*)>(_a[1])); break;
        }
        _id -= 3;
    }
    return _id;
}

// SIGNAL 0
void NDns::resultsReady()
{
    QMetaObject::activate(this, &staticMetaObject, 0, 0);
}
