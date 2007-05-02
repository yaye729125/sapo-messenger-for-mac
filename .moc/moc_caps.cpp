/****************************************************************************
** Meta object code from reading C++ file 'caps.h'
**
** Created: Thu Jul 20 17:53:49 2006
**      by: The Qt Meta Object Compiler version 59 (Qt 4.1.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../src/caps.h"
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'caps.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 59
#error "This file was generated using the moc from 4.1.1. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

static const uint qt_meta_data_CapsManager[] = {

 // content:
       1,       // revision
       0,       // classname
       0,    0, // classinfo
       3,   10, // methods
       0,    0, // properties
       0,    0, // enums/sets

 // signals: signature, parameters, type, tag, flags
      17,   13,   12,   12, 0x05,

 // slots: signature, parameters, type, tag, flags
      34,   12,   12,   12, 0x09,
      50,   12,   12,   12, 0x09,

       0        // eod
};

static const char qt_meta_stringdata_CapsManager[] = {
    "CapsManager\0\0jid\0capsChanged(Jid)\0discoFinished()\0save()\0"
};

const QMetaObject CapsManager::staticMetaObject = {
    { &QObject::staticMetaObject, qt_meta_stringdata_CapsManager,
      qt_meta_data_CapsManager, 0 }
};

const QMetaObject *CapsManager::metaObject() const
{
    return &staticMetaObject;
}

void *CapsManager::qt_metacast(const char *_clname)
{
    if (!_clname) return 0;
    if (!strcmp(_clname, qt_meta_stringdata_CapsManager))
	return static_cast<void*>(const_cast<CapsManager*>(this));
    return QObject::qt_metacast(_clname);
}

int CapsManager::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: capsChanged(*reinterpret_cast< const Jid(*)>(_a[1])); break;
        case 1: discoFinished(); break;
        case 2: save(); break;
        }
        _id -= 3;
    }
    return _id;
}

// SIGNAL 0
void CapsManager::capsChanged(const Jid & _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 0, _a);
}
