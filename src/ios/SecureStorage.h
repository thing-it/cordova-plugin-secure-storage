#import <Cordova/CDVPlugin.h>

@interface SecureStorage : CDVPlugin

- (void)init:(CDVInvokedUrlCommand*)command;
- (void)getAll:(CDVInvokedUrlCommand*)command;
- (void)set:(CDVInvokedUrlCommand*)command;
- (void)remove:(CDVInvokedUrlCommand*)command;
- (void)clear:(CDVInvokedUrlCommand*)command;
- (void)isDevicePasscodeSet:(CDVInvokedUrlCommand*)command;

@end
