//
//  LPLogger.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Foundation/Foundation.h>


#define LP_DEBUG_LOGGER_ENABLED

/* If LP_DEBUG_LOGGER_LOG_FILE is defined then all NSLog output will be redirected to the
specified file.  Otherwise the output is just written to the system console as usual. */
/*
#define LP_DEBUG_LOGGER_LOG_FILE	\
	[[NSHomeDirectory() stringByAppendingPathComponent:@"SapoIM_Debug.log"] UTF8String]
*/


#ifdef LP_DEBUG_LOGGER_ENABLED

void _LPDebugLogInit (void);
void _LPDebugLog	 (BOOL do_write, NSString *fmt, ...);

#define LPDebugLogInit()			\
	_LPDebugLogInit()

#define LPDebugLog(do_write, ... )	\
	do { _LPDebugLog(do_write, __VA_ARGS__); } while (0)	/* swallow the semicolon */

#else

#define LPDebugLogInit()
#define LPDebugLog(do_write, ... )

#endif

