//
//  LPCrashReporter.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPCrashReporter.h"
#import <ExceptionHandling/ExceptionHandling.h>
#include <sys/utsname.h>


@implementation LPCrashReporter

- init
{
	if (self = [super init]) {
		// Set up our top-level exception handler/logger to catch anything that gets thrown and isn't handled somewhere else
		NSExceptionHandler *handler = [NSExceptionHandler defaultExceptionHandler];
		[handler setExceptionHandlingMask:(NSHandleUncaughtExceptionMask       |
										   NSHandleUncaughtSystemExceptionMask |
										   NSHandleUncaughtRuntimeErrorMask    |
										   NSHandleTopLevelExceptionMask       )];
		[handler setDelegate:self];
	}
	return self;
}

- initWithDelegate:(id)delegate
{
	if (self = [self init]) {
		[self setDelegate:delegate];
	}
	return self;
}

- (void)dealloc
{
	[m_accumulatedExceptionLogsPList release];
	[m_newCrashLogsPathnamesSinceLastCheck release];
	[super dealloc];
}

- (id)delegate
{
	return m_delegate;
}

- (void)setDelegate:(id)delegate
{
	m_delegate = delegate;
}	


#pragma mark -
#pragma mark Uploading files using HTTP POST


- (void)p_postString:(NSString *)text toHTTPURL:(NSURL *)httpURL
{
	NSString *boundaryMarker = @"AaB03x";
	NSString *contentTypeHeader = [NSString stringWithFormat:@"multipart/form-data, boundary=%@", boundaryMarker];
	NSString *postString = [NSString stringWithFormat:
							@"--%1$@\r\n"
							@"content-disposition: form-data; name=\"post_data\"; filename=\"post_data.txt\"\r\n"
							@"Content-Type: text/plain;charset=UTF-8\r\n\r\n"
							@"%2$@\r\n"
							@"--%1$@--\r\n",
							boundaryMarker, text];
	NSData *postData = [postString dataUsingEncoding:NSUTF8StringEncoding];
	
	CFHTTPMessageRef request = CFHTTPMessageCreateRequest(kCFAllocatorDefault, CFSTR("POST"), (CFURLRef)httpURL, kCFHTTPVersion1_1);
	
	CFHTTPMessageSetHeaderFieldValue(request, CFSTR("Content-Type"), (CFStringRef)contentTypeHeader);
	CFHTTPMessageSetBody(request, (CFDataRef)postData);
	
	CFReadStreamRef stream = CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault, request);
	
	CFReadStreamSetProperty(stream, kCFStreamPropertyHTTPShouldAutoredirect, kCFBooleanTrue);
	
	if (CFReadStreamOpen(stream)) {
		// This forces the stream to actually post the data and get a reply
		UInt8 readBuf[1024];
		CFReadStreamRead(stream, readBuf, 1024);
		
		// We don't care whether any of this succeeds or not as there's actually not much we can do, anyway.
		
		CFReadStreamClose(stream);
	}
	
	if (stream)
		CFRelease(stream);
	if (request)
		CFRelease(request);
}


#pragma mark Unhandled Exceptions


- (id)accumulatedExceptionLogsPList
{
	// This needs to be thread-safe as we may get notified about a new unhandled exception
	// in a different thread at any time.
	
	id plistCopy = nil;
	@synchronized (self) {
		plistCopy = [m_accumulatedExceptionLogsPList copy];
	}
	return [plistCopy autorelease];
}


- (void)postAccumulatedExceptionLogsPListToHTTPURL:(NSURL *)httpURL
{
	[self p_postString:[[self accumulatedExceptionLogsPList] description] toHTTPURL:httpURL];
}


#pragma mark Crash Reporter Logs


- (NSArray *)newCrashLogsPathnamesSinceLastCheck
{
	if (m_newCrashLogsPathnamesSinceLastCheck == nil) {
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey];
		NSDate *lastTimeLogsWereSent = [[NSUserDefaults standardUserDefaults] objectForKey:@"LPLastTimeLogsWereSent"];
		
		NSMutableArray *newCrashLogsPathnamesSinceLastCheck = [[NSMutableArray alloc] init];
		
		NSArray *libraryDirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask, YES);
		NSEnumerator *libraryDirsEnum = [libraryDirs objectEnumerator];
		NSString *libraryDirPath = nil;
		
		while (libraryDirPath = [libraryDirsEnum nextObject]) {
			NSString *logsDirPath = [libraryDirPath stringByAppendingPathComponent:@"Logs"];
			NSString *crashReporterDirPath = [logsDirPath stringByAppendingPathComponent:@"CrashReporter"];
			BOOL isFolder = NO;
			
			if ([fm fileExistsAtPath:crashReporterDirPath isDirectory:&isFolder] && isFolder) {
				NSArray *filesAtPath = [fm directoryContentsAtPath:crashReporterDirPath];
				
				NSEnumerator *filesEnum = [filesAtPath objectEnumerator];
				NSString *filename = nil;
				
				while (filename = [filesEnum nextObject]) {
					NSRange rangeOfAppName = [filename rangeOfString:appName];
					
					if (rangeOfAppName.location != NSNotFound) {
						NSString *fullPathname = [crashReporterDirPath stringByAppendingPathComponent:filename];
						NSDictionary *fileAttribsDict = [fm fileAttributesAtPath:fullPathname traverseLink:NO];
						NSDate *fileCreationDate = [fileAttribsDict objectForKey:NSFileCreationDate];
						
						if (lastTimeLogsWereSent == nil || [lastTimeLogsWereSent compare:fileCreationDate] == NSOrderedAscending) {
							[newCrashLogsPathnamesSinceLastCheck addObject:fullPathname];
						}
					}
				}
			}
		}
		
		m_newCrashLogsPathnamesSinceLastCheck = newCrashLogsPathnamesSinceLastCheck;
	}
		
	return [[m_newCrashLogsPathnamesSinceLastCheck retain] autorelease];;
}


- (void)postNewCrashLogsToHTTPURL:(NSURL *)httpURL
{
#warning *** TO DO ***
}


#pragma mark -
#pragma mark NSExceptionHandler Delegate Methods


// mask is NSHandle<exception type>Mask, exception's userInfo has stack trace for key NSStackTraceKey
- (BOOL)exceptionHandler:(NSExceptionHandler *)sender shouldHandleException:(NSException *)exception mask:(NSUInteger)aMask
{
	// Build the info dictionary:
	// executableFileArch and machineArch may be different if we're running a PPC binary on an Intel Mac under Rosetta, for example.
	NSString *executableFileArch = nil;
	NSString *machineArch = nil;
	
#if defined(__ppc__)
	executableFileArch = @"PowerPC";
#elif defined(__i386__)
	executableFileArch = @"Intel";
#endif
	struct utsname un;
	if (uname(&un) == 0) {
		machineArch = [NSString stringWithCString:un.machine encoding:NSUTF8StringEncoding];
	}
	
	NSString	*appBuildNr = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
	NSString	*exceptionName = [exception name];
	NSString	*exceptionReason = [exception reason];
	id			stackTrace = [[exception userInfo] objectForKey:NSStackTraceKey];
	
	NSDictionary *infoToBeSent = [NSDictionary dictionaryWithObjectsAndKeys:
								  [NSDate date], @"Date",
								  ( appBuildNr         ? appBuildNr         : @""), @"Build Nr",
								  ( machineArch        ? machineArch        : @""), @"Machine Architecture",
								  ( executableFileArch ? executableFileArch : @""), @"Executable Architecture",
								  ( exceptionName      ? exceptionName      : @""), @"Exception Name",
								  ( exceptionReason    ? exceptionReason    : @""), @"Exception Reason",
								  ( stackTrace         ? stackTrace         : @""), @"Exception Stack Batcktrace", nil];
	
	
	// Collect the info dictionary:
	BOOL shouldTellOurDelegate = NO;
	
	// This needs to be thread-safe as we may get notified about a new unhandled exception
	// in a different thread at any time.
	@synchronized (self) {
		if (m_accumulatedExceptionLogsPList == nil) {
			m_accumulatedExceptionLogsPList = [[NSMutableArray alloc] init];
			shouldTellOurDelegate = YES;
		}
		[m_accumulatedExceptionLogsPList addObject:infoToBeSent];
	}
	
	
	// Interact with our delegate:
	if (shouldTellOurDelegate) {
		if ([m_delegate respondsToSelector:@selector(crashReporterDidCatchFirstUnhandledException:)]) {
			[m_delegate performSelectorOnMainThread:@selector(crashReporterDidCatchFirstUnhandledException:)
										 withObject:self
									  waitUntilDone:YES
											  modes:[NSArray arrayWithObjects:NSDefaultRunLoopMode, NSEventTrackingRunLoopMode, NSModalPanelRunLoopMode, nil]];
		}
	}
	
	return YES;
}


@end
