//
//  ContactDetailViewController.m
//  Blockchain
//
//  Created by Kevin Wu on 12/7/16.
//  Copyright © 2016 Blockchain Luxembourg S.A. All rights reserved.
//

#import "ContactDetailViewController.h"
#import "Contact.h"
#import "BCNavigationController.h"
#import "BCQRCodeView.h"

const int rowName = 0;
const int rowExtendedPublicKey = 1;
const int rowTrust = 2;
const int rowFetchMDID = 3;

@interface ContactDetailViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic) UITableView *tableView;
@end

@implementation ContactDetailViewController

#pragma mark - Lifecycle

- (id)initWithContact:(Contact *)contact
{
    if (self = [super init]) {
        _contact = contact;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.frame style:UITableViewStyleGrouped];
    self.tableView.backgroundColor = [UIColor whiteColor];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:CELL_IDENTIFIER_CONTACT_DETAIL];
    
    [self.tableView reloadData];
}

- (void)setContact:(Contact *)contact
{
    _contact = contact;
    
    [self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    BCNavigationController *navigationController = (BCNavigationController *)self.navigationController;
    navigationController.headerTitle = self.contact.name ? self.contact.name : self.contact.identifier;
}

#pragma mark - Table View Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 4;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CELL_IDENTIFIER_CONTACT_DETAIL forIndexPath:indexPath];

    if (indexPath.row == rowName) {
        cell.textLabel.text = self.contact.name ? self.contact.name : self.contact.identifier;
        cell.accessoryView = nil;
    } else if (indexPath.row == rowExtendedPublicKey) {
        cell.textLabel.text = BC_STRING_EXTENDED_PUBLIC_KEY;
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (indexPath.row == rowTrust) {
        cell.textLabel.text = BC_STRING_TRUST_USER;
        UISwitch *switchForTrust = [[UISwitch alloc] init];
        switchForTrust.on = self.contact.trusted;
        [switchForTrust addTarget:self action:@selector(toggleTrust) forControlEvents:UIControlEventTouchUpInside];
        cell.accessoryView = switchForTrust;
    } else if (indexPath.row == rowFetchMDID) {
        cell.textLabel.text = BC_STRING_FETCH_MDID;
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.row == rowExtendedPublicKey) {
        if (!self.contact.xpub) {
            [app.wallet fetchExtendedPublicKey:self.contact.identifier];
        } else {
            [self showExtendedPublicKey];
        }
    } else if (indexPath.row == rowFetchMDID) {
        [app.wallet readInvitationSent:self.contact.identifier];
    }
}

#pragma mark - Actions

- (void)showExtendedPublicKey
{
    BCQRCodeView *qrCodeView = [[BCQRCodeView alloc] initWithFrame:self.view.frame qrHeaderText:nil addAddressPrefix:NO];
    qrCodeView.address = self.contact.xpub;
    
    UIViewController *viewController = [UIViewController new];
    [viewController.view addSubview:qrCodeView];
    
    CGRect frame = qrCodeView.frame;
    frame.origin.y = viewController.view.frame.origin.y + DEFAULT_HEADER_HEIGHT;
    qrCodeView.frame = frame;

    qrCodeView.qrCodeFooterLabel.text = BC_STRING_COPY_XPUB;

    BCNavigationController *navigationController = (BCNavigationController *)self.navigationController;
    navigationController.headerLabel.text = BC_STRING_EXTENDED_PUBLIC_KEY;
    
    [self.navigationController pushViewController:viewController animated:YES];
}

- (void)toggleTrust
{
    BOOL trusted = self.contact.trusted;
    
    NSString *title = trusted ? BC_STRING_UNTRUST_USER_ALERT_TITLE : BC_STRING_TRUST_USER_ALERT_TITLE;
    NSString *message = trusted ? BC_STRING_UNTRUST_USER_ALERT_MESSAGE : BC_STRING_TRUST_USER_ALERT_MESSAGE;
    
    UIAlertController *alertForTogglingTrust = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alertForTogglingTrust addAction:[UIAlertAction actionWithTitle:BC_STRING_CONTINUE style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        trusted ? [app.wallet deleteTrust:self.contact.identifier] : [app.wallet addTrust:self.contact.identifier];
    }]];
    [alertForTogglingTrust addAction:[UIAlertAction actionWithTitle:BC_STRING_CANCEL style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowTrust inSection:0];
        [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }]];
    [self presentViewController:alertForTogglingTrust animated:YES completion:nil];
}

@end