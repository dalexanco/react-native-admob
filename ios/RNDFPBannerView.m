#import "RNDFPBannerView.h"

#if __has_include(<React/RCTBridgeModule.h>)
#import <React/RCTBridgeModule.h>
#import <React/UIView+React.h>
#import <React/RCTLog.h>
#else
#import "RCTBridgeModule.h"
#import "UIView+React.h"
#import "RCTLog.h"
#endif

#include "RCTConvert+GADAdSize.h"

@implementation RNDFPBannerView
{
    DFPBannerView  *_bannerView;
}

- (void)dealloc
{
    _bannerView.delegate = nil;
    _bannerView.adSizeDelegate = nil;
    _bannerView.appEventDelegate = nil;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        super.backgroundColor = [UIColor clearColor];

        UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
        UIViewController *rootViewController = [keyWindow rootViewController];

        _bannerView = [[DFPBannerView alloc] initWithAdSize:kGADAdSizeBanner];
        _bannerView.delegate = self;
        _bannerView.adSizeDelegate = self;
        _bannerView.appEventDelegate = self;
        _bannerView.rootViewController = rootViewController;
        [self addSubview:_bannerView];
    }

    return self;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-missing-super-calls"
- (void)insertReactSubview:(UIView *)subview atIndex:(NSInteger)atIndex
{
    RCTLogError(@"RNDFPBannerView cannot have subviews");
}
#pragma clang diagnostic pop

- (void)loadBanner {
    if (_targeting) {
        NSArray *array = [_bannerView.adUnitID componentsSeparatedByString:@"/"];
        int compteur = (int)[array count] - 1;
        NSString *finString = [array objectAtIndex:compteur];

        [_bannerView setAppEventDelegate:self];

        if(!CGRectEqualToRect(self.bounds, _bannerView.bounds)) {
            if ([finString isEqualToString:@"native1"] || [finString isEqualToString:@"native2"]) {
                self.onSizeChange(@{
                                    @"width": [NSNumber numberWithFloat: [_fixedWidth intValue]],
                                    @"height": [NSNumber numberWithFloat: [_fixedHeight intValue]]
                                    });
            }
        }

        DFPRequest *request = [DFPRequest request];
        if ([_targeting length] > 0) {
            NSArray *array = [_targeting componentsSeparatedByString:@"|"];
            NSMutableDictionary *customtargeting = [[NSMutableDictionary alloc] initWithCapacity:[array count]];

            for (int i = 0 ; i < [array count] ; i++) {
                id objet = [array objectAtIndex:i];
                if ([objet length] > 0 && objet) {
                    NSArray *array2 = [objet componentsSeparatedByString:@":"];
                    if ([array2 count]>1) {
                        NSString *key = [array2 objectAtIndex:0];
                        NSString *valeur = [array2 objectAtIndex:1];
                        if (valeur && ![valeur isEqual:@"[]"]) {
                            [customtargeting setObject:valeur forKey: key];
                        }
                    }
                }
            }

            request.customTargeting = customtargeting;
        }

        request.testDevices = _testDevices;
        [_bannerView loadRequest:request];
    }
}

- (void)setValidAdSizes:(NSArray *)adSizes
{
    __block NSMutableArray *validAdSizes = [[NSMutableArray alloc] initWithCapacity:adSizes.count];
    [adSizes enumerateObjectsUsingBlock:^(id jsonValue, NSUInteger idx, __unused BOOL *stop) {
        GADAdSize adSize = [RCTConvert GADAdSize:jsonValue];
        if (GADAdSizeEqualToSize(adSize, kGADAdSizeInvalid)) {
            RCTLogWarn(@"Invalid adSize %@", jsonValue);
        } else {
            [validAdSizes addObject:NSValueFromGADAdSize(adSize)];
        }
    }];
    _bannerView.validAdSizes = validAdSizes;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    NSArray *array = [_bannerView.adUnitID componentsSeparatedByString:@"/"];
    int compteur = (int)[array count] - 1;
    NSString *finString = [array objectAtIndex:compteur];
    if ([finString isEqualToString:@"native1"] || [finString isEqualToString:@"native2"]) {
        _bannerView.frame = CGRectMake(self.bounds.origin.x, self.bounds.origin.x, [_fixedWidth intValue], [_fixedHeight intValue]);
    } else {
        _bannerView.frame = CGRectMake(self.bounds.origin.x, self.bounds.origin.x, _bannerView.frame.size.width, _bannerView.frame.size.height);
    }

    [self addSubview:_bannerView];
}

# pragma mark GADBannerViewDelegate

/// Tells the delegate an ad request loaded an ad.
- (void)adViewDidReceiveAd:(DFPBannerView *)adView
{
    if (self.onSizeChange) {
        self.onSizeChange(@{
                            @"width": @([_fixedWidth intValue]),
                            @"height": @([_fixedHeight intValue]) });
    }
    if (self.onAdLoaded) {
        self.onAdLoaded(@{});
    }
}

/// Tells the delegate an ad request failed.
- (void)adView:(DFPBannerView *)adView
didFailToReceiveAdWithError:(GADRequestError *)error
{
    if (self.onAdFailedToLoad) {
        self.onAdFailedToLoad(@{ @"error": @{ @"message": [error localizedDescription] } });
    }
}

/// Tells the delegate that a full screen view will be presented in response
/// to the user clicking on an ad.
- (void)adViewWillPresentScreen:(DFPBannerView *)adView
{
    if (self.onAdOpened) {
        self.onAdOpened(@{});
    }
}

/// Tells the delegate that the full screen view will be dismissed.
- (void)adViewWillDismissScreen:(__unused DFPBannerView *)adView
{
    if (self.onAdClosed) {
        self.onAdClosed(@{});
    }
}

/// Tells the delegate that a user click will open another app (such as
/// the App Store), backgrounding the current app.
- (void)adViewWillLeaveApplication:(DFPBannerView *)adView
{
    if (self.onAdLeftApplication) {
        self.onAdLeftApplication(@{});
    }
}

# pragma mark GADAdSizeDelegate

- (void)adView:(GADBannerView *)bannerView willChangeAdSizeTo:(GADAdSize)size
{
    self.onSizeChange(@{
                        @"width": @([_fixedWidth intValue]),
                        @"height": @([_fixedHeight intValue]) });
}

# pragma mark GADAppEventDelegate

- (void)adView:(GADBannerView *)banner didReceiveAppEvent:(NSString *)name withInfo:(NSString *)info
{
    if (self.onAppEvent) {
        self.onAppEvent(@{ @"name": name, @"info": info });
    }
}

@end

