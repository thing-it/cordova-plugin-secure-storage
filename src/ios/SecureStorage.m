#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import "SecureStorage.h"
#import <Cordova/CDV.h>
#import "SAMKeychain.h"

static NSString *SERVICE_NAME = @"thing-it Mobile";

@implementation SecureStorage

- (void)pluginInitialize
{
    subscribers = [[NSMutableDictionary alloc] init];

    CFTypeRef accessibility;
    NSString *keychainAccessibility;
    NSDictionary *keychainAccesssibilityMapping = [NSDictionary dictionaryWithObjectsAndKeys:
          (__bridge id)(kSecAttrAccessibleAfterFirstUnlock), @"afterfirstunlock",
          (__bridge id)(kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly), @"afterfirstunlockthisdeviceonly",
          (__bridge id)(kSecAttrAccessibleWhenUnlocked), @"whenunlocked",
          (__bridge id)(kSecAttrAccessibleWhenUnlockedThisDeviceOnly), @"whenunlockedthisdeviceonly",
          (__bridge id)(kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly), @"whenpasscodesetthisdeviceonly",
          nil];

    keychainAccessibility = [[self.commandDelegate.settings objectForKey:[@"KeychainAccessibility" lowercaseString]] lowercaseString];
    if (keychainAccessibility == nil) {
        initialized = YES;
    } else {
        if ([keychainAccesssibilityMapping objectForKey:(keychainAccessibility)] != nil) {
            accessibility = (__bridge CFTypeRef)([keychainAccesssibilityMapping objectForKey:(keychainAccessibility)]);
            [SAMKeychain setAccessibilityType:accessibility];
            initialized = YES;
        } else {
            initialized = NO;
            initializationError = @"Unrecognized KeychainAccessibility value in config";
        }
    }

    NSError *error;
    if (initialized && ![self cacheStore]) {
        initialized = NO;
        initializationError = @"Cant fetch store";
    }

    [self publishEvent:@"initialized"];
}

- (BOOL)cacheStore
{
    NSError *error;
    SAMKeychainQuery *keysQuery = [[SAMKeychainQuery alloc] init];
    keysQuery.service = SERVICE_NAME;

    cachedStore = [[NSMutableDictionary alloc] init];

    NSArray *accounts = [keysQuery fetchAll:&error];
    if (accounts) {
        for (id dict in accounts) {
            NSString *key = [dict valueForKeyPath:@"acct"];
            SAMKeychainQuery *query = [[SAMKeychainQuery alloc] init];
            query.service = SERVICE_NAME;
            query.account = key;

            if ([query fetch:&error]) {
                cachedStore[key] = query.password;
            } else {
                break;
            }
        }

        if (!error) {
            return YES;
        } else {
            return NO;
        }
    } else if ([error code] == errSecItemNotFound) {
        return YES;
    } else {
        return NO;
    }
}

- (void)getAll:(CDVInvokedUrlCommand*)command
{
    NSError *error;

    if (cachedStore == nil) {
        [self cacheStore];

        if (error) {
            [self failWithMessage: @"Failure in SecureStorage.getAll()" : error : command.callbackId];
        }
    }

    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:cachedStore options:NSJSONWritingPrettyPrinted error:&error];
    if (!jsonData || error) {
        [self failWithMessage: @"Failure in SecureStorage.getAll()" : error : command.callbackId];
        return;
    }
    [self successWithMessage: [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : command.callbackId];
}

- (void)set:(CDVInvokedUrlCommand*)command
{
    NSString *key = [command argumentAtIndex:0];
    NSString *value = [command argumentAtIndex:1];
    [self.commandDelegate runInBackground:^{
        NSError *error;

        SAMKeychainQuery *query = [[SAMKeychainQuery alloc] init];
        query.service = SERVICE_NAME;
        query.account = key;
        query.password = value;

        if ([query save:&error]) {
            [self successWithMessage: key : command.callbackId];
        } else {
            [self failWithMessage: @"Failure in SecureStorage.set()" : error : command.callbackId];
        }
    }];
}

- (void)remove:(CDVInvokedUrlCommand*)command
{
    NSString *key = [command argumentAtIndex:0];
    [self.commandDelegate runInBackground:^{
        NSError *error;

        SAMKeychainQuery *query = [[SAMKeychainQuery alloc] init];
        query.service = SERVICE_NAME;
        query.account = key;

        if ([query deleteItem:&error]) {
            [self successWithMessage: key : command.callbackId];
        } else {
            [self failWithMessage: @"Failure in SecureStorage.remove()" : error : command.callbackId];
        }
    }];
}

- (void)clear:(CDVInvokedUrlCommand*)command
{
    [self.commandDelegate runInBackground:^{
        NSError *error;

        SAMKeychainQuery *query = [[SAMKeychainQuery alloc] init];
        query.service = SERVICE_NAME;

        NSArray *accounts = [query fetchAll:&error];
        if (accounts) {
            for (id dict in accounts) {
                query.account = [dict valueForKeyPath:@"acct"];
                if (![query deleteItem:&error]) {
                    break;
                }
            }

            if (!error) {
                [self successWithMessage: nil : command.callbackId];
            } else {
                [self failWithMessage: @"Failure in SecureStorage.clear()" : error : command.callbackId];
            }

        } else if ([error code] == errSecItemNotFound) {
            [self successWithMessage: nil : command.callbackId];
        } else {
            [self failWithMessage: @"Failure in SecureStorage.clear()" : error : command.callbackId];
        }

    }];
}

- (void)isDevicePasscodeSet:(CDVInvokedUrlCommand*)command;
{
	[self.commandDelegate runInBackground:^{
		__block CDVPluginResult* pluginResult = nil;
		NSError *passcodeError = nil;

		if (NSClassFromString(@"LAContext") != nil) {
			LAContext *laContext = [[LAContext alloc] init];
			if ([laContext canEvaluatePolicy: LAPolicyDeviceOwnerAuthentication error: &passcodeError]) {
				pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:TRUE];
			} else {
				pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsBool:FALSE];
			}
		} else {
			pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[passcodeError localizedDescription]];
		}
		[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
	}];
}

-(void)successWithMessage:(NSString *)message : (NSString *)callbackId
{
        CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:message];
        [self.commandDelegate sendPluginResult:commandResult callbackId:callbackId];
}

-(void)failWithMessage:(NSString *)message : (NSError *)error : (NSString *)callbackId
{
    NSString        *errorMessage = (error) ? [NSString stringWithFormat:@"%@ - %@", message, [error localizedDescription]] : message;
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];

    [self.commandDelegate sendPluginResult:commandResult callbackId:callbackId];
}

- (void)subscribe:(CDVInvokedUrlCommand *)command {
    NSString *eventName = [command argumentAtIndex:0];

    subscribers[eventName] = command.callbackId;

    if ([eventName isEqualToString:@"initialized"]) {
        [self publishEvent:eventName];
    }
}

- (void)publishEvent:(NSString *)eventName {
    if (subscribers[eventName] == nil) {
        return;
    }

    if ([eventName isEqualToString:@"initialized"]) {
        if (initialized) {
            [self successWithMessage: nil : subscribers[eventName]];
            return;
        }
        if (initializationError != nil) {
            [self failWithMessage: initializationError : nil : subscribers[eventName]];
        }
    } else {
        [self successWithMessage: nil : subscribers[eventName]];
    }
}

@end
