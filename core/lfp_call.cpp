#include "lfp_call.h"

/*static void reverseBytes(QByteArray *buf)
{
	unsigned char *start = (unsigned char *)buf->data();
	unsigned char *end = start + buf->size() - 1;
	unsigned char c;
	while(start < end)
	{
		c = *start;
		*(start++) = *end;
		*(end--) = c;
	}
}

static QByteArray encodeInt(int x)
{
	bool noswap = QSysInfo::ByteOrder == QSysInfo::BigEndian;
	QByteArray out(4, 0);
	unsigned char *xp = (unsigned char *)&x;
	out[0] = xp[0];
	out[1] = xp[1];
	out[2] = xp[2];
	out[3] = xp[3];
}

static QByteArray encodeUInt(uint x)
{
}

static QVariant decodeInt(const QByteArray &buf)
{
	if(buf.isEmpty())
		return QVariant((int)0);

	// is it negative?  and where does the value start?
	bool is_negative = false;
	int offset = buf.size() - 1;
	for(int n = 0; n < buf.size(); ++n)
	{
		unsigned char c = buf[n];
		if(n == 0)
		{
			if(c & 0x80)
			{
				is_negative = true;
				c &= 0x7f; // don't count the sign bit
			}
		}
		if(c != 0)
		{
			offset = n;
			break;
		}
	}

	int numbytes = buf.size() - offset;
	if(is_negative && (buf[offset] & 0x80)) // fixme: this will break for buf[0], due to sign bit
		++numbytes;

	unsigned char *dest;
	if(numbytes > 4)
		dest = (unsigned char *)(new qint64);
	else
		dest = (unsigned char *)(new qint32);
	qint64

	const unsigned char *start = (const unsigned char *)buf.data() + n;

	// negative?
	if(*start & 0x80)
	{
		out.resize(1);
	}

	QByteArray out;
}

static QByteArray encodeInt(const QVariant &var_int)
{
	QByteArray out;
	switch(var_int.type())
	{
		case QVariant::Int:
		case QVariant::UInt:
		case QVariant::LongLong:
		case QVariant::ULongLong:
		default:
			break;
	}
	return out;
}*/

//----------------------------------------------------------------------------
// LfpObject
//----------------------------------------------------------------------------
LfpObject::LfpObject()
{
}

LfpObject::LfpObject(const QString &type, const QString &name, const QVariant &value)
{
	_type = type;
	_name = name;
	_value = value;
}

LfpObject::~LfpObject()
{
}

QString LfpObject::type() const
{
	return _type;
}

QString LfpObject::name() const
{
	return _name;
}

QVariant LfpObject::value() const
{
	return _value;
}

QList<LfpObject> LfpObject::children() const
{
	return _children;
}

void LfpObject::setType(const QString &s)
{
	_type = s;
}

void LfpObject::setName(const QString &s)
{
	_name = s;
}

void LfpObject::setValue(const QVariant &v)
{
	_value = v;
}

void LfpObject::appendChild(const LfpObject &obj)
{
	_children += obj;
}

QByteArray LfpObject::toArray() const
{
	QByteArray c;
	bool noswap = QSysInfo::ByteOrder == QSysInfo::BigEndian;

	if(_type == "sequence" || _type == "map")
	{
		c.resize(4);
		int x = _children.count();
		unsigned char *xp = (unsigned char *)&x;
		if(noswap)
		{
			c[0] = xp[0];
			c[1] = xp[1];
			c[2] = xp[2];
			c[3] = xp[3];
		}
		else
		{
			c[0] = xp[3];
			c[1] = xp[2];
			c[2] = xp[1];
			c[3] = xp[0];
		}
		for(int n = 0; n < _children.count(); ++n)
			c += _children[n].toArray();
	}
	else
	{
		// bool, int, string, bytearray
		if(_type == "int")
		{
			qlonglong	value = _value.toLongLong();
			int			localValueSize = sizeof(long long);
			int			valueSize;
			
			// Determine what type of int is this. Will we need 2 bytes? 4? 8?
			if (value <= SHRT_MAX && value >= SHRT_MIN) {
				valueSize = sizeof(short);
			}
			else if (value <= LONG_MAX && value >= LONG_MIN) {
				valueSize = sizeof(long);
			}
			else if (value <= LLONG_MAX && value >= LLONG_MIN) {
				valueSize = sizeof(long long);
			}
			
			unsigned char	*valueBytes = (unsigned char *)&value;
			int				valueSizeDelta = localValueSize - valueSize;
			
			c.resize(valueSize);
			
			for (int i = 0; i < valueSize; ++i) {
				// On big endian, get the least significant bytes of the local long long variable.
				// On little endian, also get the least significant bytes (at the begining, in this case) and swap them.
				c[i] = valueBytes[ noswap ? (valueSizeDelta + i) : (valueSize - 1 - i) ];
			}
		}
		else if(_type == "string")
		{
			c = _value.toString().toUtf8();
		}
		else if(_type == "bool")
		{
			c.resize(1);
			c[0] = _value.toBool() == true ? 1 : 0;
		}
		else if(_type == "bytearray")
		{
			c = _value.toByteArray();
		}
	}

	QByteArray out;
	QByteArray outtype = _type.toLatin1();
	QByteArray outname = _name.toLatin1();
	int size = _type.size() + 1 + _name.size() + 1 + c.size();
	{
		QByteArray c;
		c.resize(4);
		int x = size;
		unsigned char *xp = (unsigned char *)&x;
		if(noswap)
		{
			c[0] = xp[0];
			c[1] = xp[1];
			c[2] = xp[2];
			c[3] = xp[3];
		}
		else
		{
			c[0] = xp[3];
			c[1] = xp[2];
			c[2] = xp[1];
			c[3] = xp[0];
		}
		out += c;
	}
	out += outtype;
	out.append((char)0);
	out += outname;
	out.append((char)0);
	out += c;
	return out;
}

LfpObject LfpObject::fromArray(const QByteArray &a)
{
	QByteArray buf = a.mid(0, 4);
	int size;
	QByteArray type, name, content;
	unsigned char *xp = (unsigned char *)&size;
	bool noswap = QSysInfo::ByteOrder == QSysInfo::BigEndian;

	if(noswap)
	{
		xp[0] = buf[0];
		xp[1] = buf[1];
		xp[2] = buf[2];
		xp[3] = buf[3];
	}
	else
	{
		xp[0] = buf[3];
		xp[1] = buf[2];
		xp[2] = buf[1];
		xp[3] = buf[0];
	}
	int at = 4;
	int next;
	next = a.indexOf((char)0, at);
	type = a.mid(at, next - at);
	at = next + 1;
	next = a.indexOf((char)0, at);
	name = a.mid(at, next - at);
	at = next + 1;
	content = a.mid(at);

	//printf("type=[%s], name=[%s], content=[%d]\n", type.data(), name.data(), content.size());

	LfpObject obj;
	obj._type = QString::fromLatin1(type);
	obj._name = QString::fromLatin1(name);
	if(obj._type == "sequence" || obj._type == "map")
	{
		int count;
		unsigned char *xp = (unsigned char *)&count;
		if(noswap)
		{
			xp[0] = content[0];
			xp[1] = content[1];
			xp[2] = content[2];
			xp[3] = content[3];
		}
		else
		{
			xp[0] = content[3];
			xp[1] = content[2];
			xp[2] = content[1];
			xp[3] = content[0];
		}
		unsigned char *base = (unsigned char *)content.data();
		unsigned char *at = base + 4;
		for(int n = 0; n < count; ++n)
		{
			int x;
			unsigned char *xp = (unsigned char *)&x;
			if(noswap)
			{
				xp[0] = at[0];
				xp[1] = at[1];
				xp[2] = at[2];
				xp[3] = at[3];
			}
			else
			{
				xp[0] = at[3];
				xp[1] = at[2];
				xp[2] = at[1];
				xp[3] = at[0];
			}
			QByteArray cbuf = content.mid(at - base, 4 + x);
			LfpObject child = LfpObject::fromArray(cbuf);
			at += 4 + x;
			obj._children += child;
		}
	}
	else
	{
		if(obj._type == "int")
		{
			int				dataLength = content.length();
			unsigned char	valueBytes[sizeof(long long)];
			
			for (int i = 0; i < dataLength; ++i) {
				valueBytes[i] = content[ noswap ? i : (dataLength - 1 - i) ];
			}
			
			switch (dataLength) {
				case sizeof(short):
					obj._value = *((short *)valueBytes);
					break;
				case sizeof(int):
					obj._value = *((int *)valueBytes);
					break;
				case sizeof(long long):
					obj._value = *((long long *)valueBytes);
					break;
			}
		}
		else if(obj._type == "string")
		{
			QString str = QString::fromUtf8(content);
			obj._value = str;
		}
		else if(obj._type == "bool")
		{
			bool b = (char)content[0] != 0 ? true : false;
			obj._value = b;
		}
		else if(obj._type == "bytearray")
		{
			obj._value = content;
		}
	}

	return obj;
}

void LfpObject::operator+=(const LfpObject &obj)
{
	appendChild(obj);
}

LfpArgument::LfpArgument(const QString &name, const QVariant &value)
{
	this->name = name;
	this->value = value;
}


static QVariant objectAsVariant(const LfpObject &obj)
{
	if(obj.type() == "sequence")
	{
		QVariantList list;
		QList<LfpObject> clist = obj.children();
		for(int n = 0; n < clist.count(); ++n)
			list += objectAsVariant(clist[n]);
		return list;
	}
	else if(obj.type() == "map")
	{
		QVariantMap map;
		QList<LfpObject> clist = obj.children();
		for(int n = 0; n < clist.count(); ++n)
			map.insert(clist[n].name(), objectAsVariant(clist[n]));
		return map;
	}
	else
		return obj.value();
}

static LfpObject variantAsObject(const QVariant &v, const QString &name = QString())
{
	if(v.type() == QVariant::List)
	{
		QVariantList list = v.toList();
		LfpObject obj("sequence", name);
		for(int n = 0; n < list.count(); ++n)
			obj += variantAsObject(list[n]);
		return obj;
	}
	else if(v.type() == QVariant::Map)
	{
		QVariantMap map = v.toMap();
		LfpObject obj("map", name);
		QMapIterator<QString, QVariant> it(map);
		while(it.hasNext())
		{
			it.next();
			obj += variantAsObject(it.value(), it.key());
		}
		return obj;
	}
	else
	{
		if(v.type() == QVariant::Bool)
			return LfpObject("bool", name, v);
		else if(v.type() == QVariant::Int || v.type() == QVariant::LongLong)
			return LfpObject("int", name, v);
		else if(v.type() == QVariant::String)
			return LfpObject("string", name, v);
		else if(v.type() == QVariant::ByteArray)
			return LfpObject("bytearray", name, v);
		else
			return LfpObject(); // TODO: error?
	}
}

QByteArray LfpArgumentList::toArray() const
{
	LfpObject args("sequence");
	for(int n = 0; n < count(); ++n)
	{
		const LfpArgument &i = at(n);
		args += variantAsObject(i.value, i.name);
	}
	return args.toArray();
}

LfpArgumentList LfpArgumentList::fromArray(const QByteArray &a)
{
	LfpObject obj = LfpObject::fromArray(a);
	LfpArgumentList args;
	QList<LfpObject> list = obj.children();
	for(int n = 0; n < list.count(); ++n)
		args += LfpArgument(list[n].name(), objectAsVariant(list[n]));
	return args;
}
