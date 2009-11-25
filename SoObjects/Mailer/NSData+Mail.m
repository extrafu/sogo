/* NSData+Mail.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2008 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *         Ludovic Marcotte <lmarcotte@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#import <Foundation/NSString.h>

#import <NGExtensions/NGBase64Coding.h>
#import <NGExtensions/NGQuotedPrintableCoding.h>
#import <NGExtensions/NSString+Encoding.h>

#import "NSData+Mail.h"

@implementation NSData (SOGoMailUtilities)

- (NSData *) bodyDataFromEncoding: (NSString *) encoding
{
  NSString *realEncoding;
  NSData *decodedData;

  realEncoding = [encoding lowercaseString];

  if ([realEncoding isEqualToString: @"7bit"]
      || [realEncoding isEqualToString: @"8bit"])
    decodedData = self;
  else if ([realEncoding isEqualToString: @"base64"])
    decodedData = [self dataByDecodingBase64];
  else if ([realEncoding isEqualToString: @"quoted-printable"])
    decodedData = [self dataByDecodingQuotedPrintableTransferEncoding];
  else
    {
      decodedData = nil;
      NSLog (@"encoding '%@' unknown, returning nil data", realEncoding);
    }

  return decodedData;
}

/*
 * Excpected form is: "=?charset?encoding?encoded text?=".
 */
- (NSString *) decodedString
{
  const char *cData;
  unsigned int len, i, j;
  NSString *decodedString;

  cData = [self bytes];
  len = [self length];
  decodedString = nil;

  if (len)
    {
      if (len > 6)
	{
	  // Find beginning of encoded text
	  i = 1;
	  while ((*cData != '=' || *(cData+1) != '?') && i < len)
	    {
	      cData++;
	      i++;
	    }

	  if (*cData == '=' && *(cData+1) == '?')
	    {
	      NSString *enc;

	      if (i > 1)
		decodedString = [[[NSString alloc] initWithData: [self subdataWithRange: NSMakeRange(0, (i-1))]
							encoding: NSASCIIStringEncoding] autorelease];
	      cData += 2; // skip "=?"
	      i++;
	      j = i;
	      // Find next "?"
	      while (*cData != '?' && j < len)
		{
		  cData++;
		  j++;
		}
	      enc = [[[NSString alloc] initWithData:[self subdataWithRange: NSMakeRange(i, j-i)]
				       encoding: NSASCIIStringEncoding] autorelease];

	      i = j + 3; // skip "?q?"
	      if (i < (len-2))
		{
		  NSData *d;
		  BOOL isQuotedPrintable = NO;

		  cData++;
		  // We check if we have a QP or Base64 encoding
		  if (*cData == 'q' || *cData == 'Q')
		    isQuotedPrintable = YES;

		  // Find end of encoded text
		  j = i;
		  cData += 2; // skip "q?"
		  while ((*cData != '?' || *(cData+1) != '=') && (j+1) < len)
		    {
		      cData++;
		      j++;
		    }

		  d = [self subdataWithRange: NSMakeRange(i, j-i)];
		  if (isQuotedPrintable)
		    d = [d dataByDecodingQuotedPrintable];
		  else
		    d = [d dataByDecodingBase64];

		  if (decodedString)
		    {
		      decodedString = [NSString stringWithFormat: @"%@%@",
						decodedString, [NSString stringWithData: d
								     usingEncodingNamed: enc]];
		    }
		  else
		    decodedString = [NSString stringWithData: d
					  usingEncodingNamed: enc];

		  j += 2; // skip "?="
		  if (j < len)
		    {
		      // Recursively decode the remaining part
		      decodedString = [NSString stringWithFormat: @"%@%@",
						decodedString,
					 [[self subdataWithRange: NSMakeRange(j, len-j)] decodedString]];
		    }
		}
	      else
		decodedString = nil;
	    }
	}
      if (!decodedString)
	{
	  decodedString
	    = [[NSString alloc] initWithData: self
				encoding: NSUTF8StringEncoding];
	  if (!decodedString)
	    decodedString
	      = [[NSString alloc] initWithData: self
				  encoding: NSISOLatin1StringEncoding];
	  [decodedString autorelease];
	}
    }
  else
    decodedString = @"";

  return decodedString;
}

@end
