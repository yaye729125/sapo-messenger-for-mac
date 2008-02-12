//
//  LPLogger.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Foundation/Foundation.h>


#define LP_DEBUG_LOGGER_ENABLED


#define LP_DEBUG_LOGGER_LOG_FILE	\
	[[NSHomeDirectory() stringByAppendingPathComponent:@"SapoIM_Debug.log"] UTF8String]

void LPDebugLogInit (void);



#ifdef LP_DEBUG_LOGGER_ENABLED

void _LPDebugLog	 (BOOL do_write, NSString *fmt, ...);
#define LPDebugLog(do_write, ... )	\
	do { _LPDebugLog(do_write, __VA_ARGS__); } while (0)	/* swallow the semicolon */

#else

#define LPDebugLog(do_write, ... )

#endif

