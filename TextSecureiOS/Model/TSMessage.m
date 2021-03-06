//
//  Message.m
//  TextSecureiOS
//
//  Created by Christine Corbett Moran on 12/1/13.
//  Copyright (c) 2013 Open Whisper Systems. All rights reserved.
//

#import "TSMessage.h"

@implementation TSMessage
-(id) initWithMessage:(NSString*)text sender:(NSString*)sender recipients:(NSArray*)recipients sentOnDate:(NSDate*)date {
  if(self=[super init]) {
    self.message=text;
    self.senderId=sender;
    self.recipientId=[recipients objectAtIndex:0];
    self.messageTimestamp = date;
  }
  return self;
}
@end
