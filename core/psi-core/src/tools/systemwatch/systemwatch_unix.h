/*
 * systemwatch_unix.h - Detect changes in the system state (Unix).
 * Copyright (C) 2005  Remko Troncon
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */

#ifndef SYSTEMWATCH_UNIX_H
#define SYSTEMWATCH_UNIX_H

#include "systemwatch.h"

class UnixSystemWatch : public SystemWatchImpl
{
	Q_OBJECT

public:
	static UnixSystemWatch* instance();
	
private:
	UnixSystemWatch();
	
	static UnixSystemWatch* instance_;
};


#endif
