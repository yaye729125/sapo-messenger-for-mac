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
	[m_newCrashLogsSinceLastCheckPList release];
	[m_currentURLConnection cancel];
	[m_currentURLConnection release];
	[m_crashLogsUploadsURL release];
	
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


- (NSURLRequest *)p_URLRequestWithURL:(NSURL *)theURL POSTBody:(NSString *)bodyContents
{
	NSString *boundaryMarker = @"AaB03x";
	NSString *contentTypeHeader = [NSString stringWithFormat:@"multipart/form-data, boundary=%@", boundaryMarker];
	NSString *postString = [NSString stringWithFormat:
							@"--%1$@\r\n"
							@"content-disposition: form-data; name=\"post_data\"; filename=\"post_data.txt\"\r\n"
							@"Content-Type: text/plain;charset=UTF-8\r\n\r\n"
							@"%2$@\r\n"
							@"--%1$@--\r\n",
							boundaryMarker, bodyContents];
	
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:theURL];
	
	[request setHTTPMethod:@"POST"];
	[request setHTTPBody:[postString dataUsingEncoding:NSUTF8StringEncoding]];
	[request setValue:contentTypeHeader forHTTPHeaderField:@"Content-Type"];
	
	return request;
}


- (void)p_synchronousPostString:(NSString *)text toHTTPURL:(NSURL *)httpURL
{
	NSURLResponse *response = nil;
	[NSURLConnection sendSynchronousRequest:[self p_URLRequestWithURL:httpURL POSTBody:text]
						  returningResponse:&response
									  error:NULL];
}


- (BOOL)p_startPostOfCrashLogAtPathname:(NSString *)pathname toHTTPURL:(NSURL *)theURL
{
	BOOL didStart = NO;
	
	if (m_currentURLConnection == nil) {
		NSString *postString = [NSString stringWithContentsOfFile:pathname encoding:NSUTF8StringEncoding error:NULL];
		if (postString != nil) {
			NSURLRequest *request = [self p_URLRequestWithURL:theURL POSTBody:postString];
			
			m_currentURLConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
			NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
			
			[m_currentURLConnection scheduleInRunLoop:runLoop forMode:NSDefaultRunLoopMode];
			[m_currentURLConnection scheduleInRunLoop:runLoop forMode:NSModalPanelRunLoopMode];
			[m_currentURLConnection scheduleInRunLoop:runLoop forMode:NSEventTrackingRunLoopMode];
			
			[m_currentURLConnection start];
			didStart = YES;
		}
		else {
			NSLog(@"Failed to read file at \"%@\" as text.", pathname);
		}
	}
	return didStart;
}


- (BOOL)p_startPostOfCrashLogAtIndex:(NSUInteger)dictIndex
{
	BOOL didStart = NO;
	id crashLogsPList = [self newCrashLogsSinceLastCheckPList];
	
	if (dictIndex < [crashLogsPList count]) {
		NSDictionary *crashLogDict = [crashLogsPList objectAtIndex:dictIndex];
		NSString *crashLogPathname = [crashLogDict objectForKey:@"FilePathname"];
		
		didStart = [self p_startPostOfCrashLogAtPathname:crashLogPathname toHTTPURL:m_crashLogsUploadsURL];
	}
	return didStart;
}


#pragma mark NSURLConnection Delegate Methods


- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	if (connection == m_currentURLConnection) {
		[m_currentURLConnection autorelease];
		m_currentURLConnection = nil;
		
		NSLog(@"There was an error while uploading our crash logs. Aborting!");
		
		[self freeAllNewCrashLogsInternalInfo];
	}
}


- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	if (connection == m_currentURLConnection) {
		[m_currentURLConnection autorelease];
		m_currentURLConnection = nil;
		
		id crashLogsPList = [self newCrashLogsSinceLastCheckPList];
		
		NSDictionary *crashLogDict = [crashLogsPList objectAtIndex:m_indexOfCrashLogsPListElementBeingUploaded];
		NSDate *dateCreated = [crashLogDict objectForKey:@"CreationDate"];
		
		[[NSUserDefaults standardUserDefaults] setObject:dateCreated forKey:@"LastSentCrashLogDate"];
		
		do {
			++m_indexOfCrashLogsPListElementBeingUploaded;
		} while (m_indexOfCrashLogsPListElementBeingUploaded < [crashLogsPList count]
				 && ![self p_startPostOfCrashLogAtIndex:m_indexOfCrashLogsPListElementBeingUploaded]);
		
		if (m_indexOfCrashLogsPListElementBeingUploaded >= [crashLogsPList count]) {
			// Everything has been sent!
			[self freeAllNewCrashLogsInternalInfo];
		}
	}
}


#pragma mark -
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
	id exceptionsLogsPList = [self accumulatedExceptionLogsPList];
	
	NSLog(@"Uploading unhandled exceptions logs:\n%@", exceptionsLogsPList);
	
	[self p_synchronousPostString:[exceptionsLogsPList description] toHTTPURL:httpURL];
}


#pragma mark Crash Reporter Logs


- (BOOL)hasNewCrashLogsSinceLastCheck
{
	return ([[self newCrashLogsSinceLastCheckPList] count] > 0);
}


- (NSArray *)newCrashLogsSinceLastCheckPList
{
	if (m_newCrashLogsSinceLastCheckPList == nil)
	{
		NSFileManager	*fm = [NSFileManager defaultManager];
		NSString		*appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey];
		NSDate			*lastTimeLogsWereSent = [[NSUserDefaults standardUserDefaults] objectForKey:@"LastSentCrashLogDate"];
		
		NSMutableArray	*newCrashLogsSinceLastCheckPList = [[NSMutableArray alloc] init];
		
		NSArray			*libraryDirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask, YES);
		NSEnumerator	*libraryDirsEnum = [libraryDirs objectEnumerator];
		NSString		*libraryDirPath = nil;
		
		while (libraryDirPath = [libraryDirsEnum nextObject])
		{
			NSString		*logsDirPath = [libraryDirPath stringByAppendingPathComponent:@"Logs"];
			NSString		*crashReporterDirPath = [logsDirPath stringByAppendingPathComponent:@"CrashReporter"];
			BOOL			isFolder = NO;
			
			if ([fm fileExistsAtPath:crashReporterDirPath isDirectory:&isFolder] && isFolder)
			{
				NSArray			*filesAtPath = [fm directoryContentsAtPath:crashReporterDirPath];
				NSEnumerator	*filesEnum = [filesAtPath objectEnumerator];
				NSString		*filename = nil;
				
				while (filename = [filesEnum nextObject])
				{
					NSRange			rangeOfAppName = [filename rangeOfString:appName];
					
					if (rangeOfAppName.location != NSNotFound)
					{
						NSString		*fullPathname = [crashReporterDirPath stringByAppendingPathComponent:filename];
						NSDictionary	*fileAttribsDict = [fm fileAttributesAtPath:fullPathname traverseLink:NO];
						NSDate			*fileCreationDate = [fileAttribsDict objectForKey:NSFileCreationDate];
						
						if (lastTimeLogsWereSent == nil || [lastTimeLogsWereSent compare:fileCreationDate] == NSOrderedAscending)
						{
							[newCrashLogsSinceLastCheckPList addObject:
							 [NSDictionary dictionaryWithObjectsAndKeys:
							  fullPathname, @"FilePathname", fileCreationDate, @"CreationDate", nil]];
						}
					}
				}
			}
		}
		
		/* Keep them sorted by ascending creation date. We can then save the file creation date of each log that
		 * gets successfully uploaded as soon as the upload completes, and that date can be used to determine
		 * which log files still need to be uploaded and which ones have already been uploaded. */
		NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"CreationDate" ascending:YES];
		[newCrashLogsSinceLastCheckPList sortUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
		[sortDescriptor release];
		
		m_newCrashLogsSinceLastCheckPList = newCrashLogsSinceLastCheckPList;
	}
	
	return m_newCrashLogsSinceLastCheckPList;
}


- (void)startPostingNewCrashLogsToHTTPURL:(NSURL *)httpURL
{
	if (m_crashLogsUploadsURL == nil) {
		m_crashLogsUploadsURL = [httpURL copy];
		m_indexOfCrashLogsPListElementBeingUploaded = 0;
		
		id crashLogsPList = [self newCrashLogsSinceLastCheckPList];
		
		NSLog(@"Uploading %d crash reports...", [crashLogsPList count]);
		
		while (m_indexOfCrashLogsPListElementBeingUploaded < [crashLogsPList count]
			   && ![self p_startPostOfCrashLogAtIndex:m_indexOfCrashLogsPListElementBeingUploaded]) {
			++m_indexOfCrashLogsPListElementBeingUploaded;
		}
	}
}


- (void)freeAllNewCrashLogsInternalInfo
{
	if (m_currentURLConnection == nil) {
		[m_crashLogsUploadsURL release];
		m_crashLogsUploadsURL = nil;
		
		[m_newCrashLogsSinceLastCheckPList release];
		m_newCrashLogsSinceLastCheckPList = nil;
	}
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
