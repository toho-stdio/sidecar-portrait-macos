//
//  VirtualDisplayManager.mm
//  display-app
//
//  Created by Codex on 31/12/25.
//

#import "VirtualDisplayManager.h"
#import <AppKit/AppKit.h>
#include <vector>

@class CGVirtualDisplayDescriptor;
@interface CGVirtualDisplayMode : NSObject
@property(readonly, nonatomic) CGFloat refreshRate;
@property(readonly, nonatomic) NSUInteger width;
@property(readonly, nonatomic) NSUInteger height;
- (instancetype)initWithWidth:(NSUInteger)arg1 height:(NSUInteger)arg2 refreshRate:(CGFloat)arg3;
@end

@interface CGVirtualDisplaySettings : NSObject
@property(nonatomic) unsigned int hiDPI;
@property(retain, nonatomic) NSArray<CGVirtualDisplayMode *> *modes;
- (instancetype)init;
@end

@interface CGVirtualDisplay : NSObject
@property(readonly, nonatomic) CGDirectDisplayID displayID;
- (instancetype)initWithDescriptor:(CGVirtualDisplayDescriptor *)arg1;
- (BOOL)applySettings:(CGVirtualDisplaySettings *)arg1;
@end

@interface CGVirtualDisplayDescriptor : NSObject
@property(retain, nonatomic) NSString *name;
@property(nonatomic) unsigned int maxPixelsHigh;
@property(nonatomic) unsigned int maxPixelsWide;
@property(nonatomic) CGSize sizeInMillimeters;
@property(nonatomic) unsigned int serialNum;
@property(nonatomic) unsigned int productID;
@property(nonatomic) unsigned int vendorID;
@property(copy, nonatomic) void (^terminationHandler)(id, CGVirtualDisplay *);
- (instancetype)init;
- (nullable dispatch_queue_t)dispatchQueue;
- (void)setDispatchQueue:(dispatch_queue_t)arg1;
@end

static NSString *const VDErrorDomain = @"VirtualDisplayManager";

static int VDClampInt(int value, int low, int high) {
    return value < low ? low : (value > high ? high : value);
}

static NSString *VD_CopyDisplayName(CGDirectDisplayID displayID) {
    for (NSScreen *screen in [NSScreen screens]) {
        NSNumber *number = screen.deviceDescription[@"NSScreenNumber"];
        if (number && (CGDirectDisplayID)number.unsignedIntValue == displayID) {
            return [screen.localizedName copy];
        }
    }
    return nil;
}

@implementation VirtualDisplayInfo
@end

@implementation VirtualDisplayManager {
    CGVirtualDisplay *_display;
    CGVirtualDisplayDescriptor *_descriptor;
    CGVirtualDisplaySettings *_settings;
    NSUInteger _width;
    NSUInteger _height;
}

- (VirtualDisplayInfo *)currentDisplay {
    if (!_display) {
        return nil;
    }
    VirtualDisplayInfo *info = [VirtualDisplayInfo new];
    info.displayID = _display.displayID;
    info.width = _width;
    info.height = _height;
    return info;
}

- (VirtualDisplayInfo *)createDisplayWithWidth:(NSUInteger)width
                                       height:(NSUInteger)height
                                    frameRate:(CGFloat)frameRate
                                        hiDPI:(BOOL)hiDPI
                                         name:(NSString *)name
                                          ppi:(NSInteger)ppi
                                       mirror:(BOOL)mirror
                                        error:(NSError * _Nullable * _Nullable)error {
    _display = nil;
    _descriptor = nil;
    _settings = nil;
    _width = 0;
    _height = 0;

    NSUInteger clampedWidth = MAX(width, 1);
    NSUInteger clampedHeight = MAX(height, 1);
    CGFloat clampedRate = VDClampInt((int)frameRate, 30, 120);
    NSInteger clampedPPI = VDClampInt((int)ppi, 72, 300);
    NSString *displayName = name.length > 0 ? name : @"Virtual Display";

    _descriptor = [CGVirtualDisplayDescriptor new];
    _descriptor.name = displayName;
    _descriptor.maxPixelsWide = (unsigned int)clampedWidth;
    _descriptor.maxPixelsHigh = (unsigned int)clampedHeight;

    double ratio = 25.4 / clampedPPI;
    _descriptor.sizeInMillimeters = CGSizeMake(clampedWidth * ratio, clampedHeight * ratio);
    _descriptor.productID = 0xeeee + (unsigned int)clampedWidth + (unsigned int)clampedHeight + (unsigned int)clampedPPI;
    _descriptor.vendorID = 0xeeee;
    _descriptor.serialNum = 0x0001;

    _display = [[CGVirtualDisplay alloc] initWithDescriptor:_descriptor];
    if (!_display) {
        if (error) {
            *error = [NSError errorWithDomain:VDErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: @"Failed to create virtual display"}];
        }
        return nil;
    }

    _settings = [CGVirtualDisplaySettings new];
    _settings.hiDPI = hiDPI ? 1 : 0;

    CGVirtualDisplayMode *mode = [[CGVirtualDisplayMode alloc] initWithWidth:clampedWidth
                                                                      height:clampedHeight
                                                                  refreshRate:clampedRate];
    if (hiDPI) {
        CGVirtualDisplayMode *lowResMode = [[CGVirtualDisplayMode alloc] initWithWidth:clampedWidth / 2
                                                                                height:clampedHeight / 2
                                                                            refreshRate:clampedRate];
        _settings.modes = @[mode, lowResMode];
    } else {
        _settings.modes = @[mode];
    }

    if (![_display applySettings:_settings]) {
        if (error) {
            *error = [NSError errorWithDomain:VDErrorDomain code:3 userInfo:@{NSLocalizedDescriptionKey: @"Failed to apply virtual display settings"}];
        }
        _display = nil;
        _descriptor = nil;
        _settings = nil;
        return nil;
    }

    CGDirectDisplayID mainDisplay = CGMainDisplayID();
    CGDirectDisplayID newMainDisplayID = CGMainDisplayID();

    CGDisplayConfigRef config;
    CGBeginDisplayConfiguration(&config);
    if (newMainDisplayID == _display.displayID && newMainDisplayID != mainDisplay) {
        CGConfigureDisplayOrigin(config, mainDisplay, 0, 0);
    }

    CGDirectDisplayID displayId = CGDisplayMirrorsDisplay(mainDisplay);
    if (displayId == _display.displayID) {
        CGConfigureDisplayMirrorOfDisplay(config, displayId, kCGNullDirectDisplay);
    }
    CGCompleteDisplayConfiguration(config, kCGConfigureForAppOnly);

    boolean_t isMirror = CGDisplayIsInMirrorSet(_display.displayID);
    CGBeginDisplayConfiguration(&config);
    if (mirror) {
        if (isMirror == 0) {
            CGConfigureDisplayMirrorOfDisplay(config, _display.displayID, mainDisplay);
        }
    } else {
        if (isMirror == 1) {
            CGConfigureDisplayMirrorOfDisplay(config, _display.displayID, kCGNullDirectDisplay);
        }
    }
    CGCompleteDisplayConfiguration(config, kCGConfigureForAppOnly);

    _width = clampedWidth;
    _height = clampedHeight;

    VirtualDisplayInfo *info = [VirtualDisplayInfo new];
    info.displayID = _display.displayID;
    info.width = clampedWidth;
    info.height = clampedHeight;
    return info;
}

- (BOOL)destroyDisplay {
    if (_display) {
        _display = nil;
        _descriptor = nil;
        _settings = nil;
        _width = 0;
        _height = 0;
        return YES;
    }
    return NO;
}

- (VirtualDisplayInfo *)findDisplayWithName:(nullable NSString *)name
                                  productID:(NSInteger)productID
                                   vendorID:(NSInteger)vendorID {
    uint32_t displayCount = 0;
    CGGetOnlineDisplayList(0, nullptr, &displayCount);
    if (displayCount == 0) {
        return nil;
    }

    std::vector<CGDirectDisplayID> displayIDs(displayCount);
    CGGetOnlineDisplayList(displayCount, displayIDs.data(), &displayCount);

    for (uint32_t i = 0; i < displayCount; i++) {
        CGDirectDisplayID displayID = displayIDs[i];
        if (productID >= 0 && (NSInteger)CGDisplayModelNumber(displayID) != productID) {
            continue;
        }
        if (vendorID >= 0 && (NSInteger)CGDisplayVendorNumber(displayID) != vendorID) {
            continue;
        }
        if (name.length > 0) {
            NSString *displayName = VD_CopyDisplayName(displayID);
            BOOL matches = (displayName && [displayName isEqualToString:name]);
            if (!matches) {
                continue;
            }
        }

        CGDisplayModeRef displayMode = CGDisplayCopyDisplayMode(displayID);
        NSUInteger width = 0;
        NSUInteger height = 0;
        if (displayMode) {
            width = (NSUInteger)CGDisplayModeGetPixelWidth(displayMode);
            height = (NSUInteger)CGDisplayModeGetPixelHeight(displayMode);
            CFRelease(displayMode);
        }
        VirtualDisplayInfo *info = [VirtualDisplayInfo new];
        info.displayID = displayID;
        info.width = width;
        info.height = height;
        return info;
    }

    return nil;
}

@end
