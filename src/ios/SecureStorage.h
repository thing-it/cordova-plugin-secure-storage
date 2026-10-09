#import <Cordova/CDVPlugin.h>

@interface SecureStorage : CDVPlugin {
    NSMutableDictionary<NSString *, NSString *> *subscribers;
    // Only accessed on storeQueue
    NSMutableDictionary<NSString *, NSString *> *cachedStore;
    dispatch_queue_t storeQueue;
    BOOL initialized;
    NSString *initializationError;
}

- (BOOL)cacheStore:(NSError **)error;
- (void)getAll:(CDVInvokedUrlCommand*)command;
- (void)set:(CDVInvokedUrlCommand*)command;
- (void)remove:(CDVInvokedUrlCommand*)command;
- (void)clear:(CDVInvokedUrlCommand*)command;
- (void)isDevicePasscodeSet:(CDVInvokedUrlCommand*)command;

@end
