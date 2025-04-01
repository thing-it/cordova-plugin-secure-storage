#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import "SecureStorage.h"
#import <Cordova/CDV.h>
#import "SAMKeychain.h"

static NSString *SERVICE_NAME = @"thing-it Mobile";

@implementation SecureStorage

- (void)pluginInitialize {
    subscribers = [[NSMutableDictionary alloc] init];

    CFTypeRef accessibility;
    NSString *keychainAccessibility;
    NSDictionary *keychainAccesssibilityMapping = @{
        @"afterfirstunlock": (__bridge id)(kSecAttrAccessibleAfterFirstUnlock),
        @"afterfirstunlockthisdeviceonly": (__bridge id)(kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly),
        @"whenunlocked": (__bridge id)(kSecAttrAccessibleWhenUnlocked),
        @"whenunlockedthisdeviceonly": (__bridge id)(kSecAttrAccessibleWhenUnlockedThisDeviceOnly),
        @"whenpasscodesetthisdeviceonly": (__bridge id)(kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly)
    };

    keychainAccessibility = [[[self.commandDelegate.settings objectForKey:@"KeychainAccessibility"] lowercaseString] copy];

    if (keychainAccessibility == nil) {
        initialized = YES;
    } else {
        if ([keychainAccesssibilityMapping objectForKey:keychainAccessibility] != nil) {
            accessibility = (__bridge CFTypeRef)(keychainAccesssibilityMapping[keychainAccessibility]);
            [SAMKeychain setAccessibilityType:accessibility];
            initialized = YES;
        } else {
            initialized = NO;
            initializationError = @"Unrecognized KeychainAccessibility value in config";
        }
    }

    if (initialized && ![self cacheStore]) {
        initialized = NO;
        initializationError = @"Cant fetch store";
    }

    [self publishEvent:@"initialized"];
}

- (BOOL)cacheStore {
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

- (void)getAll:(CDVInvokedUrlCommand*)command {
    NSError *error;

    if (cachedStore == nil) {
        [self cacheStore];

        if (error) {
            [self failWithMessage:@"Failure in SecureStorage.getAll()" error:error callbackId:command.callbackId];
            return;
        }
    }

    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:cachedStore options:NSJSONWritingPrettyPrinted error:&error];
    if (!jsonData || error) {
        [self failWithMessage:@"Failure in SecureStorage.getAll()" error:error callbackId:command.callbackId];
        return;
    }

    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [self successWithMessage:jsonString :command.callbackId];
}

- (void)set:(CDVInvokedUrlCommand*)command {
    NSString *key = [command argumentAtIndex:0];
    NSString *value = [command argumentAtIndex:1];

    [self.commandDelegate runInBackground:^{
        NSError *error;
        SAMKeychainQuery *query = [[SAMKeychainQuery alloc] init];
        query.service = SERVICE_NAME;
        query.account = key;
        query.password = value;

        if ([query save:&error]) {
            cachedStore[key] = value;
            [self successWithMessage:key :command.callbackId];
        } else {
            [self failWithMessage:@"Failure in SecureStorage.set()" error:error callbackId:command.callbackId account:key];
        }
    }];
}

- (void)remove:(CDVInvokedUrlCommand*)command {
    NSString *key = [command argumentAtIndex:0];

    [self.commandDelegate runInBackground:^{
        NSError *error;
        SAMKeychainQuery *query = [[SAMKeychainQuery alloc] init];
        query.service = SERVICE_NAME;
        query.account = key;

        if ([query deleteItem:&error]) {
            [cachedStore removeObjectForKey:key];
            [self successWithMessage:key :command.callbackId];
        } else {
            [self failWithMessage:@"Failure in SecureStorage.remove()" error:error callbackId:command.callbackId account:key];
        }

        cachedStore = nil;
        [self cacheStore];
    }];
}

- (void)clear:(CDVInvokedUrlCommand*)command {
    [self.commandDelegate runInBackground:^{
        NSError *error;
        SAMKeychainQuery *query = [[SAMKeychainQuery alloc] init];
        query.service = SERVICE_NAME;

        NSArray *accounts = [query fetchAll:&error];
        if (accounts) {
            for (id dict in accounts) {
                query.account = [dict valueForKeyPath:@"acct"];
                if (![query deleteItem:&error]) {
                    [self failWithMessage:@"Failure in SecureStorage.clear()" error:error callbackId:command.callbackId account:query.account];
                    return;
                }
            }
            cachedStore = nil;
            [self cacheStore];
            [self successWithMessage:nil :command.callbackId];
        } else if ([error code] == errSecItemNotFound) {
            cachedStore = nil;
            [self cacheStore];
            [self successWithMessage:nil :command.callbackId];
        } else {
            [self failWithMessage:@"Failure in SecureStorage.clear()" error:error callbackId:command.callbackId];
        }
    }];
}

- (void)isDevicePasscodeSet:(CDVInvokedUrlCommand*)command {
    [self.commandDelegate runInBackground:^{
        NSError *passcodeError = nil;
        CDVPluginResult* pluginResult = nil;

        if (NSClassFromString(@"LAContext") != nil) {
            LAContext *laContext = [[LAContext alloc] init];
            if ([laContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&passcodeError]) {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:YES];
            } else {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsBool:NO];
            }
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[passcodeError localizedDescription]];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)successWithMessage:(NSString *)message :(NSString *)callbackId {
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:message];
    [self.commandDelegate sendPluginResult:commandResult callbackId:callbackId];
}

- (void)failWithMessage:(NSString *)message error:(NSError *)error callbackId:(NSString *)callbackId {
    [self failWithMessage:message error:error callbackId:callbackId account:nil];
}

- (void)failWithMessage:(NSString *)message error:(NSError *)error callbackId:(NSString *)callbackId account:(NSString *)account {
    NSMutableDictionary *errorDict = [@{ @"message": message ?: @"Unknown error" } mutableCopy];

    if (error) {
        errorDict[@"status"] = @(error.code);
        errorDict[@"description"] = error.localizedDescription ?: @"No description";
        errorDict[@"domain"] = error.domain ?: @"";
    }
    if (account) {
        errorDict[@"account"] = account;
        errorDict[@"service"] = SERVICE_NAME;
    }

    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:errorDict];
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
            [self successWithMessage:nil :subscribers[eventName]];
        } else if (initializationError != nil) {
            [self failWithMessage:initializationError error:nil callbackId:subscribers[eventName]];
        }
    } else {
        [self successWithMessage:nil :subscribers[eventName]];
    }
}

@end