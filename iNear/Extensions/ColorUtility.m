//
//  ColorUtility.m
//  iNear
//
//  Created by Сергей Сейтов on 03.02.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

#import "ColorUtility.h"
#import <CommonCrypto/CommonDigest.h>

@implementation ColorUtility

+ (UIColor*)MD5color:(NSString*)toMd5
{
    // Create pointer to the string as UTF8
    const char *ptr = [toMd5 UTF8String];
    
    if (!ptr) {
        return [UIColor grayColor];
    }
    
    // Create byte array of unsigned chars
    unsigned char md5Buffer[CC_MD5_DIGEST_LENGTH];
    
    // Create 16 byte MD5 hash value, store in buffer
    CC_MD5(ptr, (CC_LONG)strlen(ptr), md5Buffer);
    
    float r = (float)md5Buffer[0]/256.0;
    float g = (float)md5Buffer[1]/256.0;
    float b = (float)md5Buffer[2]/256.0;
/*
    // take the first decimal part to avoid the gaussian distribution in the middle
    // (most users will be blueish without this)
    r *= 10;
    int r_i = (int)r;
    r -= r_i;
    
    g *= 10;
    int g_i = (int)g;
    g -= g_i;
    
    b *= 10;
    int b_i = (int)b;
    b -= b_i;
    
    return [UIColor colorWithHue:r saturation:1.0 brightness:1.0 alpha:1.0];
 */
    return [UIColor colorWithRed:r green:g blue:b alpha:1.0];
}

@end
