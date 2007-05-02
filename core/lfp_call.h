#ifndef LFP_CALL_H
#define LFP_CALL_H

#include <QtCore>

class LfpObject
{
public:
	LfpObject();
	LfpObject(const QString &type, const QString &name = QString(), const QVariant &value = QVariant());
	~LfpObject();

	QString type() const;
	QString name() const;
	QVariant value() const;
	QList<LfpObject> children() const;

	void setType(const QString &s);
	void setName(const QString &s);
	void setValue(const QVariant &v);
	void appendChild(const LfpObject &obj);

	QByteArray toArray() const;
	static LfpObject fromArray(const QByteArray &a);

	void operator+=(const LfpObject &obj);

private:
	QString _type, _name;
	QVariant _value;
	QList<LfpObject> _children;
};

class LfpArgument
{
public:
	LfpArgument(const QString &name, const QVariant &value);

	QString name;
	QVariant value;
};

class LfpArgumentList : public QList<LfpArgument>
{
public:
	QByteArray toArray() const;
	static LfpArgumentList fromArray(const QByteArray &a);
};

class LfpCall
{
public:
	QString method;
	LfpArgumentList arguments;
};

#endif
