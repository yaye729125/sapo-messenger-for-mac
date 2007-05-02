/****************************************************************************
** Meta object code from reading C++ file 'bytestream.h'
**
** Created: Thu Jul 20 17:53:20 2006
**      by: The Qt Meta Object Compiler version 59 (Qt 4.1.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../src/ambrosia/cutestuff/util/bytestream.h"
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'bytestream.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 59
#error "This file was generated using the moc from 4.1.1. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

static const uint qt_meta_data_ByteStream[] = {

 // content:
       1,       // revision
       0,       // classname
       0,    0, // classinfo
       5,   10, // methods
       0,    0, // properties
       0,    0, // enums/sets

 // signals: signature, parameters, type, tag, flags
      12,   11,   11,   11, 0x05,
      31,   11,   11,   11, 0x05,
      54,   11,   11,   11, 0x05,
      66,   11,   11,   11, 0x05,
      84,   11,   11,   11, 0x05,

       0        // eod
};

static const char qt_meta_stringdata_ByteStream[] = {
    "ByteStream\0\0connectionClosed()\0delayedCloseFinished()\0readyRead()\0"
    "bytesWritten(int)\0error(int)\0"
};

const QMetaObject ByteStream::staticMetaObject = {
    { &QObject::staticMetaObject, qt_meta_stringdata_ByteStream,
      qt_meta_data_ByteStream, 0 }
};

const QMetaObject *ByteStream::metaObject() const
{
    return &staticMetaObject;
}

void *ByteStream::qt_metacast(const char *_clname)
{
    if (!_clname) return 0;
    if (!strcmp(_clname, qt_meta_stringdata_ByteStream))
	return static_cast<void*>(const_cast<ByteStream*>(this));
    return QObject::qt_metacast(_clname);
}

int ByteStream::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: connectionClosed(); break;
        case 1: delayedCloseFinished(); break;
        case 2: readyRead(); break;
        case 3: bytesWritten(*reinterpret_cast< int(*)>(_a[1])); break;
        case 4: error(*reinterpret_cast< int(*)>(_a[1])); break;
        }
        _id -= 5;
    }
    return _id;
}

// SIGNAL 0
void ByteStream::connectionClosed()
{
    QMetaObject::activate(this, &staticMetaObject, 0, 0);
}

// SIGNAL 1
void ByteStream::delayedCloseFinished()
{
    QMetaObject::activate(this, &staticMetaObject, 1, 0);
}

// SIGNAL 2
void ByteStream::readyRead()
{
    QMetaObject::activate(this, &staticMetaObject, 2, 0);
}

// SIGNAL 3
void ByteStream::bytesWritten(int _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 3, _a);
}

// SIGNAL 4
void ByteStream::error(int _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 4, _a);
}
