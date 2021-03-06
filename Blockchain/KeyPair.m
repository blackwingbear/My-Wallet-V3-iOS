//
//  KeyPair.m
//  Blockchain
//
//  Created by Kevin Wu on 11/2/16.
//  Copyright © 2016 Blockchain Luxembourg S.A. All rights reserved.
//

#import "KeyPair.h"
#import "BTCKey.h"
#import "RootService.h"
#import "NSData+Hex.h"
#import "NSString+NSString_EscapeQuotes.h"
#import "NSData+BTCData.h"
#import "BTCNetwork.h"
#import "BTCAddress.h"

@implementation KeyPair {
    JSManagedValue *_network;
}

- (id)initWithKey:(BTCKey *)key network:(JSValue *)network
{
    if (self = [super init]) {
        
        self.key = key;
        
        if (network == nil || [network isNull] || [network isUndefined]) {
            network = [[NSUserDefaults standardUserDefaults] boolForKey:USER_DEFAULTS_KEY_DEBUG_ENABLE_TESTNET] ? [app.wallet executeJSSynchronous:@"MyWalletPhone.getNetworks().testnet"] : [app.wallet executeJSSynchronous:@"MyWalletPhone.getNetworks().bitcoin"];
        }
        
        _network = [JSManagedValue managedValueWithValue:network];
        [[[JSContext currentContext] virtualMachine] addManagedReference:_network withOwner:self];
    }
    return self;
}

- (JSValue *)network
{
    return _network.value;
}

- (JSValue *)d
{
    return [app.wallet executeJSSynchronous:[NSString stringWithFormat:@"BigInteger.fromBuffer(new Buffer('%@', 'hex'))", [[self.key.privateKey hexadecimalString] escapeStringForJS]]];
}

- (JSValue *)Q
{
    return [app.wallet executeJSSynchronous:[NSString stringWithFormat:@"BigInteger.fromBuffer(new Buffer('%@', 'hex'))", [[self.key.publicKey hexadecimalString] escapeStringForJS]]];
}

+ (KeyPair *)fromPublicKey:(NSString *)buffer buffer:(JSValue *)network
{
    BTCKey *key = [[BTCKey alloc] initWithPublicKey:[buffer dataUsingEncoding:NSUTF8StringEncoding]];
    return [[KeyPair alloc] initWithKey:key network:network];
}

+ (KeyPair *)from:(NSString *)string WIF:(JSValue *)network
{
    BTCKey *key = [[BTCKey alloc] initWithWIF:string];
    return [[KeyPair alloc] initWithKey:key network:network];
}

+ (KeyPair *)makeRandom:(JSValue *)options
{
    BTCKey *key = [[BTCKey alloc] init];
    return [[KeyPair alloc] initWithKey:key network:options];
}

- (NSString *)getAddress;
{
    BOOL testnetOn = [[NSUserDefaults standardUserDefaults] boolForKey:USER_DEFAULTS_KEY_DEBUG_ENABLE_TESTNET];
    
    if (testnetOn) {
        DLog(@"Testnet set in debug menu: using testnet");
        return self.key.addressTestnet.string;
    } else if ([[_network.value toDictionary] isEqual:[[app.wallet executeJSSynchronous:@"MyWalletPhone.getNetworks().bitcoin"] toDictionary]]) {
        DLog(@"Using mainnet");
        return self.key.address.string;
    } else if ([[_network.value toDictionary] isEqual:[[app.wallet executeJSSynchronous:@"MyWalletPhone.getNetworks().testnet"] toDictionary]]) {
        DLog(@"Using testnet");
        return self.key.addressTestnet.string;;
    } else {
        DLog(@"KeyPair error: unsupported network");
        return nil;
    }
}

- (JSValue *)getPublicKeyBuffer
{
    return [self bufferFromData:self.key.compressedPublicKey];
}

- (JSValue *)sign:(JSValue *)hash
{
    JSValue *ecdsa = [app.wallet executeJSSynchronous:@"MyWalletPhone.getECDSA()"];
    return [ecdsa invokeMethod:@"sign" withArguments:@[hash, self.d]];
}

- (NSString *)toWIF
{
    return self.key.WIF;
}

- (BOOL)verify:(NSString *)hash signature:(NSString *)signature;
{
    NSData *hashData = [hash dataUsingEncoding:NSUTF8StringEncoding];
    NSData *signatureData = [signature dataUsingEncoding:NSUTF8StringEncoding];
    return [self.key isValidSignature:signatureData hash:hashData];
}

- (JSValue *)bufferFromData:(NSData *)data
{
    return [app.wallet executeJSSynchronous:[NSString stringWithFormat:@"new Buffer('%@', 'hex')", [[data hexadecimalString] escapeStringForJS]]];
}

@end
