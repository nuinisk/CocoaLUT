//
//  LUTColorSpace.h
//  Pods
//
//  Created by Greg Cotten on 4/2/14.
//
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>
#import "CocoaLUT.h"

@interface LUTColorSpace : NSObject


+ (instancetype)LUTColorSpaceWithWhiteChromaticityX:(double)whiteChromaticityX
                                 whiteChromaticityY:(double)whiteChromaticityY
                                   redChromaticityX:(double)redChromaticityX
                                   redChromaticityY:(double)redChromaticityY
                                 greenChromaticityX:(double)greenChromaticityX
                                 greenChromaticityY:(double)greenChromaticityY
                                  blueChromaticityX:(double)blueChromaticityX
                                  blueChromaticityY:(double)blueChromaticityY;

+ (instancetype)LUTColorSpaceWithNPM:(GLKMatrix3)npm;

+ (LUT *)convertLUT:(LUT *)lut fromColorSpace:(LUTColorSpace *)sourceColorSpace toColorSpace:(LUTColorSpace *)destinationColorSpace;

+ (GLKMatrix3)transformationMatrixFromColorSpace:(LUTColorSpace *)sourceColorSpace ToColorSpace:(LUTColorSpace *)destinationColorSpace;

+ (NSDictionary *)knownColorSpaces;

+ (instancetype)rec709ColorSpace;
+ (instancetype)dciP3ColorSpace;
+ (instancetype)p3D60ColorSpace;
+ (instancetype)p3D65ColorSpace;
+ (instancetype)rec2020ColorSpace;
+ (instancetype)alexaWideGamutColorSpace;
+ (instancetype)sGamut3CineColorSpace;
+ (instancetype)sGamutColorSpace;
+ (instancetype)acesGamutColorSpace;
+ (instancetype)xyzColorSpace;




@end