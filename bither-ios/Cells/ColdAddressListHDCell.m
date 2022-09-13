//
//  ColdAddressListHDCell.m
//  bither-ios
//
//  Created by 宋辰文 on 15/7/16.
//  Copyright (c) 2015年 Bither. All rights reserved.
//

#import <Bitheri/NSString+Base58.h>
#import "ColdAddressListHDCell.h"
#import "DialogProgress.h"
#import "DialogPassword.h"
#import "DialogXrandomInfo.h"
#import "DialogWithActions.h"
#import "DialogBlackQrCode.h"
#import "DialogHDMSeedWordList.h"
#import "DialogPrivateKeyText.h"
#import <Bitheri/BTHDAccountAddress.h>
#import "StringUtil.h"
#import <Bitheri/BTQRCodeUtil.h>
#import "BTWordsTypeManager.h"
#import "DialogAlert.h"
#import "AddressAddModeUtil.h"

@interface ColdAddressListHDCell () <DialogPasswordDelegate> {
    BTHDAccountCold *_account;
    NSString *password;
    SEL passwordSelector;
    DialogProgress *dp;
}
@property(weak, nonatomic) IBOutlet UIImageView *ivXRandom;
@property(weak, nonatomic) IBOutlet UIImageView *ivType;
@property (weak, nonatomic) IBOutlet UIButton *btnAddMode;

@property(strong, nonatomic) UILongPressGestureRecognizer *longPress;
@property(strong, nonatomic) UILongPressGestureRecognizer *xrandomLongPress;
@end

@implementation ColdAddressListHDCell

- (void)setAccount:(BTHDAccountCold *)account {
    _account = account;
    if (!self.longPress) {
        self.longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleTableviewCellLongPressed:)];
    }
    if (!self.xrandomLongPress) {
        self.xrandomLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleXrandomLabelLongPressed:)];
    }
    if (![self.ivType.gestureRecognizers containsObject:self.longPress]) {
        [self.ivType addGestureRecognizer:self.longPress];
    }
    if (![self.ivXRandom.gestureRecognizers containsObject:self.xrandomLongPress]) {
        [self.ivXRandom addGestureRecognizer:self.xrandomLongPress];
    }
    if (!dp) {
        dp = [[DialogProgress alloc] initWithMessage:NSLocalizedString(@"Please wait…", nil)];
    }
    self.ivXRandom.hidden = !_account.isFromXRandom;
    CGFloat wScreen = [[UIScreen mainScreen] bounds].size.width;
    if (_account.isFromXRandom) {
        _btnAddMode.frame = CGRectMake(wScreen - 110, _btnAddMode.frame.origin.y, _btnAddMode.frame.size.width, _btnAddMode.frame.size.height);
    } else {
        _btnAddMode.frame = CGRectMake(wScreen - 82, _btnAddMode.frame.origin.y, _btnAddMode.frame.size.width, _btnAddMode.frame.size.height);
    }
    [_btnAddMode setImage:[UIImage imageNamed:[AddressAddModeUtil getImgRes:_account.addMode isFromXRandom:_account.isFromXRandom isNormal:true]] forState:UIControlStateNormal];
    [_btnAddMode setImage:[UIImage imageNamed:[AddressAddModeUtil getImgRes:_account.addMode isFromXRandom:_account.isFromXRandom isNormal:false]] forState:UIControlStateHighlighted];
    self.btnAddMode.hidden = false;
}

- (BTHDAccountCold *)account {
    return _account;
}

- (IBAction)seedPressed:(id)sender {
    [[[DialogWithActions alloc] initWithActions:@[
            [[Action alloc] initWithName:NSLocalizedString(@"add_hd_account_seed_qr_phrase", nil) target:self andSelector:@selector(showPhrase)],
            [[Action alloc] initWithName:NSLocalizedString(@"hd_account_cold_first_address", nil) target:self andSelector:@selector(showFirstAddress)]
    ]] showInWindow:self.window];
}

- (IBAction)qrPressed:(id)sender {
    [[[DialogWithActions alloc] initWithActions:@[
            [[Action alloc] initWithName:NSLocalizedString(@"add_cold_hd_account_monitor_qr", nil) target:self andSelector:@selector(showAccountQrCode)]
    ]] showInWindow:self.window];
}

- (IBAction)btnAddModeClicked:(UIButton *)sender {
    DialogAlert *dialogAlert = [[DialogAlert alloc] initWithConfirmMessage:NSLocalizedString([AddressAddModeUtil getDes:_account.addMode isFromXRandom:_account.isFromXRandom], nil) confirm:^{
    }];
    [dialogAlert showInWindow:self.window];
}

- (void)showAccountQrCode {
    if (!password) {
        passwordSelector = @selector(showAccountQrCode);
        [[[DialogPassword alloc] initWithDelegate:self] showInWindow:self.window];
        return;
    }
    NSString *p = password;
    password = nil;
    __weak __block DialogProgress *d = dp;
    [d showInWindow:self.window completion:^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            NSString *pub = [[self.account xPub:p withPurposePathLevel:NormalAddress] serializePubB58];
            NSString *segwitPub = [[self.account xPub:p withPurposePathLevel:P2SHP2WPKH] serializePubB58];

            dispatch_async(dispatch_get_main_queue(), ^{
                [d dismissWithCompletion:^{
                    DialogBlackQrCode *d = [[DialogBlackQrCode alloc] initWithContent:[NSString stringWithFormat:@"%@%@%@%@", HD_MONITOR_QR_PREFIX, pub, HD_MONITOR_QR_SPLIT, segwitPub] title:NSLocalizedString(@"add_cold_hd_account_monitor_qr", nil) andSubtitle:[StringUtil formatAddress:pub groupSize:4 lineSize:24]];
                    [d showInWindow:self.window];
                }];
            });
        });
    }];
}

- (void)showPhrase {
    if (!password) {
        passwordSelector = @selector(showPhrase);
        [[[DialogPassword alloc] initWithDelegate:self] showInWindow:self.window];
        return;
    }
    NSString *p = password;
    password = nil;
    __weak __block DialogProgress *d = dp;
    [d showInWindow:self.window completion:^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            NSArray *words = [self.account seedWords:p];
            dispatch_async(dispatch_get_main_queue(), ^{
                [d dismissWithCompletion:^{
                    [[[DialogHDMSeedWordList alloc] initWithWords:words] showInWindow:self.window];
                }];
            });
        });
    }];
}

- (void)showFirstAddress {
    if (!password) {
        passwordSelector = @selector(showFirstAddress);
        [[[DialogPassword alloc] initWithDelegate:self] showInWindow:self.window];
        return;
    }
    NSString* address = [[[_account xPub:password withPurposePathLevel:NormalAddress] deriveSoftened:EXTERNAL_ROOT_PATH] deriveSoftened:0].address;
    [[[DialogPrivateKeyText alloc]initWithPrivateKeyStr:address]showInWindow:self.window];
}

- (void)onPasswordEntered:(NSString *)p {
    password = p;
    if (passwordSelector && [self respondsToSelector:passwordSelector]) {
        IMP imp = [self methodForSelector:passwordSelector];
        void (*func)(id, SEL) = (void *)imp;
        func(self, passwordSelector);
    }
    passwordSelector = nil;
}

- (void)handleXrandomLabelLongPressed:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [[[DialogXrandomInfo alloc] init] showInWindow:self.window];
    }
}

- (void)handleTableviewCellLongPressed:(UILongPressGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        [self seedPressed:nil];
    }
}
@end
