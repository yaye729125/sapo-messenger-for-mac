//
//  LPXMPPURI-Scanner.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Foundation/Foundation.h>


BOOL LPXMPPURI_ParseURI (NSString *uriStr, NSString **oJidPtr, NSString **oActionPtr, NSDictionary **oParamsPtr);
