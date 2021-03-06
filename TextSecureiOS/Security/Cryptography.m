//
//  Cryptography.m
//  TextSecureiOS
//
//  Created by Christine Corbett Moran on 3/26/13.
//  Copyright (c) 2013 Open Whisper Systems. All rights reserved.
//

#import "Cryptography.h"
#import <Security/Security.h>
#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonCryptor.h>
#import "NSData+Conversion.h"
#import "KeychainWrapper.h"
#import "Constants.h"

#include "NSString+Conversion.h"
#include "NSData+Base64.h"
#import "FilePath.h"


@implementation Cryptography


#pragma mark random bytes methods
+(NSMutableData*) generateRandomBytes:(int)numberBytes {
  /* used to generate db master key, and to generate signaling key, both at install */
  NSMutableData* randomBytes = [NSMutableData dataWithLength:numberBytes];
  int err = 0;
  err = SecRandomCopyBytes(kSecRandomDefault,numberBytes,[randomBytes mutableBytes]);
  if(err != noErr) {
    @throw [NSException exceptionWithName:@"random problem" reason:@"problem generating the random " userInfo:nil];
  }
  return randomBytes;
}




#pragma mark SHA1
+(NSString*)truncatedSHA1Base64EncodedWithoutPadding:(NSString*)string{
  /* used by TSContactManager to send hashed/truncated contact list to server */
  NSMutableData *hashData = [NSMutableData dataWithLength:20];
  CC_SHA1([[string dataUsingEncoding:NSUTF8StringEncoding] bytes], [[string dataUsingEncoding:NSUTF8StringEncoding] length], [hashData mutableBytes]);
  NSData *truncatedData = [hashData subdataWithRange:NSMakeRange(0, 10)];
  
  return [[truncatedData base64EncodedString] stringByReplacingOccurrencesOfString:@"=" withString:@""];
}

+ (NSString*)computeSHA1DigestForString:(NSString*)input {
  // Here we are taking in our string hash, placing that inside of a C Char Array, then parsing it through the SHA1 encryption method.
  const char *cstr = [input cStringUsingEncoding:NSUTF8StringEncoding];
  NSData *data = [NSData dataWithBytes:cstr length:input.length];
  uint8_t digest[CC_SHA1_DIGEST_LENGTH];
  
  CC_SHA1(data.bytes, data.length, digest);
  
  NSMutableString* output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
  
  for(int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
    [output appendFormat:@"%02x", digest[i]];
  }
  
  return output;
}

#pragma HMAC/SHA256

+(NSData*) truncatedHMAC:(NSData*)dataToHMAC withHMACKey:(NSData*)HMACKey {
  uint8_t ourHmac[CC_SHA256_DIGEST_LENGTH] = {0};
  CCHmac(kCCHmacAlgSHA256,
         [HMACKey bytes],
         [HMACKey length],
         [dataToHMAC bytes],
         [dataToHMAC  length],
         ourHmac);
  return [NSData dataWithBytes: ourHmac length: 10];
}


#pragma mark push payload encryptiong/decryption
+(NSData*) decryptPushPayload:(NSData*) dataToDecrypt withKey:(NSData*) key withIV:(NSData*) iv withVersion:(NSData*)version withHMACKey:(NSData*) hmacKey forHMAC:(NSData *)hmac{
  /* AES256 CBC encrypt then mac 
   Returns nil if hmac invalid or decryption fails
   */
  //verify hmac of version||encrypted data||iv
  NSMutableData *dataToHmac = [NSMutableData data ];
  [dataToHmac appendData:version];
  [dataToHmac appendData:iv];
  [dataToHmac appendData:dataToDecrypt];
  
  // verify hmac
  NSData* ourHmacData = [Cryptography truncatedHMAC:dataToHmac withHMACKey:hmacKey];
  if(![ourHmacData isEqualToData:hmac]) {
    return nil;
  }
  
  // decrypt
  size_t bufferSize           = [dataToDecrypt length] + kCCBlockSizeAES128;
  void* buffer                = malloc(bufferSize);
  
  size_t bytesDecrypted    = 0;
  CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                        [key bytes], [key length],
                                        [iv bytes],
                                        [dataToDecrypt bytes], [dataToDecrypt length],
                                        buffer, bufferSize,
                                        &bytesDecrypted);
  if (cryptStatus == kCCSuccess) {
    return [NSData dataWithBytesNoCopy:buffer length:bytesDecrypted];
  }
  
  free(buffer);
  return nil;
  
  
}


+(NSData*)encryptPushPayload:(NSData*) dataToEncrypt withKey:(NSData*) key withIV:(NSData*) iv withVersion:(NSData*)version  withHMACKey:(NSData*) hmacKey computedHMAC:(NSData**)hmac {
  /* AES256 CBC encrypt then mac
   Returns nil if encryption fails
   */
  size_t bufferSize           = [dataToEncrypt length] + kCCBlockSizeAES128;
  void* buffer                = malloc(bufferSize);
  
  size_t bytesEncrypted    = 0;
  CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                        [key bytes], [key length],
                                        [iv bytes],
                                        [dataToEncrypt bytes], [dataToEncrypt length],
                                        buffer, bufferSize,
                                        &bytesEncrypted);
  
  if (cryptStatus == kCCSuccess){
    NSData* encryptedData= [NSData dataWithBytesNoCopy:buffer length:bytesEncrypted];
    //compute hmac of version||encrypted data||iv
    NSMutableData *dataToHmac = [NSMutableData data];
    [dataToHmac appendData:version];
    [dataToHmac appendData:iv];
    [dataToHmac appendData:encryptedData];
    *hmac = [Cryptography truncatedHMAC:dataToHmac withHMACKey:hmacKey];
    return encryptedData;
  }
  free(buffer);
  return nil;
  
}





@end
