//
//  VirtualDisplayManager.h
//  display-app
//
//  Created by Codex on 31/12/25.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface VirtualDisplayInfo : NSObject
@property(nonatomic, assign) CGDirectDisplayID displayID;
@property(nonatomic, assign) NSUInteger width;
@property(nonatomic, assign) NSUInteger height;
@end

@interface VirtualDisplayManager : NSObject
@property(nonatomic, readonly, nullable) VirtualDisplayInfo *currentDisplay;

- (nullable VirtualDisplayInfo *)createDisplayWithWidth:(NSUInteger)width
                                                height:(NSUInteger)height
                                             frameRate:(CGFloat)frameRate
                                                 hiDPI:(BOOL)hiDPI
                                                  name:(NSString *)name
                                                   ppi:(NSInteger)ppi
                                                mirror:(BOOL)mirror
                                                 error:(NSError * _Nullable * _Nullable)error;

- (BOOL)destroyDisplay;

- (nullable VirtualDisplayInfo *)findDisplayWithName:(nullable NSString *)name
                                           productID:(NSInteger)productID
                                            vendorID:(NSInteger)vendorID;
@end

NS_ASSUME_NONNULL_END
