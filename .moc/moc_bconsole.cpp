/****************************************************************************
** Meta object code from reading C++ file 'bconsole.h'
**
** Created: Thu Jul 20 17:53:21 2006
**      by: The Qt Meta Object Compiler version 59 (Qt 4.1.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../src/ambrosia/cutestuff/util/bconsole.h"
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'bconsole.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 59
#error "This file was generated using the moc from 4.1.1. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

static const uint qt_meta_data_BConsole[] = {

 // content:
       1,       // revision
       0,       // classname
       0,    0, // classinfo
       2,   10, // methods
       0,    0, // properties
       0,    0, // enums/sets

 // slots: signature, parameters, type, tag, flags
      10,    9,    9,    9, 0x08,
      20,    9,    9,    9, 0x08,

       0        // eod
};

static const char qt_meta_stringdata_BConsole[] = {
    "BConsole\0\0sn_read()\0sn_write()\0"
};

const QMetaObject BConsole::staticMetaObject = {
    { &ByteStream::staticMetaObject, qt_meta_stringdata_BConsole,
      qt_meta_data_BConsole, 0 }
};

const QMetaObject *BConsole::metaObject() const
{
    return &staticMetaObject;
}

void *BConsole::qt_metacast(const char *_clname)
{
    if (!_clname) return 0;
    if (!strcmp(_clname, qt_meta_stringdata_BConsole))
	return static_cast<void*>(const_cast<BConsole*>(this));
    return ByteStream::qt_metacast(_clname);
}

int BConsole::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = ByteStream::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: sn_read(); break;
        case 1: sn_write(); break;
        }
        _id -= 2;
    }
    return _id;
}
