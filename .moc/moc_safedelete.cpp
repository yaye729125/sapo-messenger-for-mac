/****************************************************************************
** Meta object code from reading C++ file 'safedelete.h'
**
** Created: Thu Jul 20 17:53:34 2006
**      by: The Qt Meta Object Compiler version 59 (Qt 4.1.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../src/ambrosia/iris/irisnet/legacy/safedelete.h"
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'safedelete.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 59
#error "This file was generated using the moc from 4.1.1. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

static const uint qt_meta_data_SafeDeleteLater[] = {

 // content:
       1,       // revision
       0,       // classname
       0,    0, // classinfo
       1,   10, // methods
       0,    0, // properties
       0,    0, // enums/sets

 // slots: signature, parameters, type, tag, flags
      17,   16,   16,   16, 0x08,

       0        // eod
};

static const char qt_meta_stringdata_SafeDeleteLater[] = {
    "SafeDeleteLater\0\0explode()\0"
};

const QMetaObject SafeDeleteLater::staticMetaObject = {
    { &QObject::staticMetaObject, qt_meta_stringdata_SafeDeleteLater,
      qt_meta_data_SafeDeleteLater, 0 }
};

const QMetaObject *SafeDeleteLater::metaObject() const
{
    return &staticMetaObject;
}

void *SafeDeleteLater::qt_metacast(const char *_clname)
{
    if (!_clname) return 0;
    if (!strcmp(_clname, qt_meta_stringdata_SafeDeleteLater))
	return static_cast<void*>(const_cast<SafeDeleteLater*>(this));
    return QObject::qt_metacast(_clname);
}

int SafeDeleteLater::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: explode(); break;
        }
        _id -= 1;
    }
    return _id;
}
