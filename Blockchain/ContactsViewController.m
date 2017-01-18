//
//  ContactsViewController.m
//  Blockchain
//
//  Created by Kevin Wu on 11/1/16.
//  Copyright © 2016 Blockchain Luxembourg S.A. All rights reserved.
//

#import "ContactsViewController.h"
#import "BCCreateContactView.h"
#import "BCModalViewController.h"
#import "Blockchain-Swift.h"
#import "Invitation.h"
#import "BCQRCodeView.h"
#import "NSString+NSString_EscapeQuotes.h"
#import "Contact.h"
#import "ContactDetailViewController.h"
#import "ContactTableViewCell.h"

const int sectionContacts = 0;

typedef enum {
    CreateContactTypeQR,
    CreateContactTypeLink
} CreateContactType;

@interface ContactsViewController () <UITableViewDelegate, UITableViewDataSource, AVCaptureMetadataOutputObjectsDelegate, CreateContactDelegate>

@property (nonatomic) BCNavigationController *createContactNavigationController;
@property (nonatomic) ContactDetailViewController *detailViewController;
@property (nonatomic) UITableView *tableView;
@property (nonatomic) NSArray *contacts;
@property (nonatomic) NSDictionary *lastCreatedInvitation;
@property (nonatomic) AVCaptureSession *captureSession;
@property (nonatomic) AVCaptureVideoPreviewLayer *videoPreviewLayer;

@property (nonatomic) NSString *invitationFromURL;
@property (nonatomic) NSString *nameFromURL;

@property (nonatomic) CreateContactType contactType;

@end

@implementation ContactsViewController

#pragma mark - Lifecycle

- (id)initWithInvitation:(NSString *)identifier name:(NSString *)name
{
    if (self = [super init]) {
        self.invitationFromURL = identifier;
        self.nameFromURL = name;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.frame style:UITableViewStyleGrouped];
    self.tableView.backgroundColor = [UIColor whiteColor];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
    [self.tableView registerClass:[ContactTableViewCell class] forCellReuseIdentifier:CELL_IDENTIFIER_CONTACT];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    BCNavigationController *navigationController = (BCNavigationController *)self.navigationController;
    navigationController.headerTitle = BC_STRING_CONTACTS;
    
    [self reload];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (self.invitationFromURL && self.nameFromURL) {
        [app.wallet readInvitation:[self JSDictionaryForInvitation:self.invitationFromURL name:self.nameFromURL]];
    }
}

- (void)reload
{
    self.contacts = [self getContacts];
    
    [app.wallet getMessages];
    
    [self.tableView reloadData];
}

- (NSArray *)getContacts
{
    NSArray *contactsArray = [[app.wallet getContacts] allValues];
    NSMutableArray *contacts = [NSMutableArray new];
    for (NSDictionary *contactDict in contactsArray) {
        Contact *contact = [[Contact alloc] initWithDictionary:contactDict];
        [contacts addObject:contact];
    }
    return contacts;
}

- (void)updateContactDetail
{
    [self reload];
    
    NSString *contactIdentifier = self.detailViewController.contact.identifier;
    
    Contact *reloadedContact = [[Contact alloc] initWithDictionary:[[app.wallet getContacts] objectForKey:contactIdentifier]];
    
    self.detailViewController.contact = reloadedContact;
}

#pragma mark - Table View Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.contacts.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ContactTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CELL_IDENTIFIER_CONTACT forIndexPath:indexPath];
    
    Contact *contact = self.contacts[indexPath.row];
    
    [cell configureWithContact:contact actionRequired:YES];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    Contact *contact = self.contacts[indexPath.row];
    [self contactClicked:contact];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 45.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 45)];
    view.backgroundColor = [UIColor whiteColor];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, self.view.frame.size.width, 14)];
    label.textColor = COLOR_FOREGROUND_GRAY;
    label.font = [UIFont systemFontOfSize:14.0];
    
    [view addSubview:label];
    
    NSString *labelString;
    
    if (section == 0) {
        labelString = BC_STRING_CONTACTS;
        UIButton *addButton = [[UIButton alloc] initWithFrame:CGRectMake(self.view.frame.size.width - 20 - 30, 4, 50, 40)];
        [addButton setImage:[UIImage imageNamed:@"new-grey"] forState:UIControlStateNormal];
        [addButton addTarget:self action:@selector(newContactClicked:) forControlEvents:UIControlEventTouchUpInside];
        [view addSubview:addButton];
    }
    
    label.text = [labelString uppercaseString];
    
    return view;
}

#pragma mark - Create Contact Delegate

- (void)didCreateSenderName:(NSString *)senderName contactName:(NSString *)contactName
{
    BCCreateContactView *createContactSharingView = [[BCCreateContactView alloc] initWithContactName:contactName senderName:senderName];
    createContactSharingView.delegate = self;
    
    BCModalViewController *modalViewController = [[BCModalViewController alloc] initWithCloseType:ModalCloseTypeClose showHeader:YES headerText:BC_STRING_CREATE view:createContactSharingView];
    
    [self.createContactNavigationController pushViewController:modalViewController animated:YES];
}

- (void)didCreateContactName:(NSString *)name
{
    BCCreateContactView *createContactSenderNameView = [[BCCreateContactView alloc] initWithContactName:name senderName:nil];
    createContactSenderNameView.delegate = self;
    
    BCModalViewController *modalViewController = [[BCModalViewController alloc] initWithCloseType:ModalCloseTypeClose showHeader:YES headerText:BC_STRING_CREATE view:createContactSenderNameView];
    
    [self.createContactNavigationController pushViewController:modalViewController animated:YES];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(ANIMATION_DURATION * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [createContactSenderNameView.textField becomeFirstResponder];
    });
}

- (void)didSelectQRCode
{
    self.contactType = CreateContactTypeQR;
}

- (void)didSelectShareLink
{
    self.contactType = CreateContactTypeLink;
}

- (void)dismissContactController
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Actions

- (void)contactClicked:(Contact *)contact
{
    [app.wallet completeRelation:contact.identifier];
    
    self.detailViewController = [[ContactDetailViewController alloc] initWithContact:contact];
    [self.navigationController pushViewController:self.detailViewController animated:YES];
}

- (void)newContactClicked:(id)sender
{
    UIAlertController *createContactOptionsAlert = [UIAlertController alertControllerWithTitle:BC_STRING_ADD_NEW_CONTACT message:nil preferredStyle:UIAlertControllerStyleAlert];
    [createContactOptionsAlert addAction:[UIAlertAction actionWithTitle:BC_STRING_CANCEL style:UIAlertActionStyleCancel handler:nil]];
    [createContactOptionsAlert addAction:[UIAlertAction actionWithTitle:BC_STRING_INVITE_SOMEONE_TO_CONNECT style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self createInvitation];
    }]];
    [createContactOptionsAlert addAction:[UIAlertAction actionWithTitle:BC_STRING_SOMEONE_SENT_ME_AN_INVITATION_CODE style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self prepareToReadInvitation];
    }]];
    
    [self presentViewController:createContactOptionsAlert animated:YES completion:nil];
}

- (void)createInvitation
{
    BCCreateContactView *createContactSharingView = [[BCCreateContactView alloc] initWithContactName:nil senderName:nil];
    createContactSharingView.delegate = self;
    
    BCModalViewController *modalViewController = [[BCModalViewController alloc] initWithCloseType:ModalCloseTypeClose showHeader:YES headerText:BC_STRING_CREATE view:createContactSharingView];
    
    self.createContactNavigationController = [[BCNavigationController alloc] initWithRootViewController:modalViewController title:BC_STRING_CREATE];
    
    [self presentViewController:self.createContactNavigationController animated:YES completion:nil];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(ANIMATION_DURATION * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [createContactSharingView.textField becomeFirstResponder];
    });
}

- (void)prepareToReadInvitation
{
    [self startReadingQRCode];
}

- (BOOL)startReadingQRCode
{
    AVCaptureDeviceInput *input = [app getCaptureDeviceInput];
    
    if (!input) {
        return NO;
    }
    
    self.captureSession = [[AVCaptureSession alloc] init];
    [self.captureSession addInput:input];
    
    AVCaptureMetadataOutput *captureMetadataOutput = [[AVCaptureMetadataOutput alloc] init];
    [self.captureSession addOutput:captureMetadataOutput];
    
    dispatch_queue_t dispatchQueue;
    dispatchQueue = dispatch_queue_create("myQueue", NULL);
    [captureMetadataOutput setMetadataObjectsDelegate:self queue:dispatchQueue];
    [captureMetadataOutput setMetadataObjectTypes:[NSArray arrayWithObject:AVMetadataObjectTypeQRCode]];
    
    self.videoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    [self.videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    
    CGRect frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height + DEFAULT_FOOTER_HEIGHT);
    
    [self.videoPreviewLayer setFrame:frame];
    
    UIView *view = [[UIView alloc] initWithFrame:frame];
    [view.layer addSublayer:self.videoPreviewLayer];
    
    BCModalViewController *modalViewController = [[BCModalViewController alloc] initWithCloseType:ModalCloseTypeClose showHeader:YES headerText:BC_STRING_SCAN_QR_CODE view:view];

    [self presentViewController:modalViewController animated:YES completion:nil];
    
    [self.captureSession startRunning];
    
    return YES;
}

- (void)stopReadingQRCode
{
    [self.captureSession stopRunning];
    self.captureSession = nil;
    
    [self.videoPreviewLayer removeFromSuperlayer];
    
    [app closeModalWithTransition:kCATransitionFade];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    if (metadataObjects != nil && [metadataObjects count] > 0) {
        AVMetadataMachineReadableCodeObject *metadataObj = [metadataObjects firstObject];
        
        if ([[metadataObj type] isEqualToString:AVMetadataObjectTypeQRCode]) {
            [self performSelectorOnMainThread:@selector(stopReadingQRCode) withObject:nil waitUntilDone:NO];
            
            // do something useful with results
            dispatch_sync(dispatch_get_main_queue(), ^{
                NSString *invitation = [metadataObj stringValue];
                [app.wallet readInvitation:invitation];
            });
        }
    }
}

- (void)showInvitationAlert:(NSDictionary *)invitation identifier:(NSString *)identifier
{
    NSString *name = [invitation objectForKey:DICTIONARY_KEY_NAME];
    NSString *invitationID = [invitation objectForKey:DICTIONARY_KEY_INVITATION_RECEIVED];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:BC_STRING_ADD_NEW_CONTACT message:[NSString stringWithFormat:BC_STRING_CONTACTS_SHOW_INVITATION_ALERT_MESSAGE_ARGUMENT_NAME_ARGUMENT_IDENTIFIER, name, invitationID] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:BC_STRING_ACCEPT style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [app.wallet acceptRelation:identifier name:name identifier:invitationID];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:BC_STRING_CANCEL style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)shareInvitationClicked
{
    NSString *identifier = [self.lastCreatedInvitation objectForKey:DICTIONARY_KEY_INVITATION_RECEIVED];
    NSString *sharedInfo = [self.lastCreatedInvitation objectForKey:DICTIONARY_KEY_NAME];
    
    NSString *shareLink = [PREFIX_BLOCKCHAIN_URI stringByAppendingFormat:@"invite?id=%@&name=%@", [identifier escapeStringForJS], [sharedInfo escapeStringForJS]];
    NSArray *items = @[shareLink];
    
    UIActivityViewController *activityController = [[UIActivityViewController alloc]initWithActivityItems:items applicationActivities:nil];
    
    [self.createContactNavigationController presentViewController:activityController animated:YES completion:nil];
}

#pragma mark - Helpers

- (NSString *)JSDictionaryForInvitation:(NSString *)identifier name:(NSString *)name;
{
    return [NSString stringWithFormat:@"{name: \"%@\", invitationReceived: \"%@\"}", [name escapeStringForJS], [identifier escapeStringForJS]];
}

#pragma mark - Wallet Callbacks

- (void)didReadInvitation:(NSDictionary *)invitation identifier:(NSString *)identifier
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(ANIMATION_DURATION * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self showInvitationAlert:invitation identifier:identifier];
    });
}

- (void)didAcceptRelation:(NSString *)invitation name:(NSString *)name
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:BC_STRING_ADDED_NEW_CONTACT message:[NSString stringWithFormat:BC_STRING_CONTACTS_ACCEPTED_INVITATION_ALERT_MESSAGE_ARGUMENT_NAME_ARGUMENT_IDENTIFIER, name, invitation] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:BC_STRING_OK style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
    
    [self reload];
}

- (void)didCompleteRelation
{
    DLog(@"Read invitation sent success");
}

- (void)didCreateInvitation:(NSDictionary *)invitationDict
{
    self.lastCreatedInvitation = invitationDict;
    
    NSString *identifier = [invitationDict objectForKey:DICTIONARY_KEY_INVITATION_RECEIVED];
    NSString *sharedInfo = [invitationDict objectForKey:DICTIONARY_KEY_NAME];
    
    if (self.contactType == CreateContactTypeQR) {
        BCQRCodeView *qrCodeView = [[BCQRCodeView alloc] initWithFrame:self.view.frame qrHeaderText:BC_STRING_CONTACT_SCAN_INSTRUCTIONS addAddressPrefix:NO];
        qrCodeView.address = [self JSDictionaryForInvitation:identifier name:sharedInfo];
        
        UIViewController *viewController = [UIViewController new];
        [viewController.view addSubview:qrCodeView];
        
        CGRect frame = qrCodeView.frame;
        frame.origin.y = viewController.view.frame.origin.y + DEFAULT_HEADER_HEIGHT;
        qrCodeView.frame = frame;
        
        UIButton *doneButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 80, 40)];
        doneButton.backgroundColor = COLOR_BUTTON_BLUE;
        doneButton.layer.cornerRadius = 4;
        [doneButton setTitle:BC_STRING_DONE forState:UIControlStateNormal];
        [doneButton addTarget:self action:@selector(dismissContactController) forControlEvents:UIControlEventTouchUpInside];
        [qrCodeView addSubview:doneButton];
        doneButton.center = CGPointMake(qrCodeView.center.x, qrCodeView.frame.size.height - 100);
        
        [self.createContactNavigationController pushViewController:viewController animated:YES];
    } else if (self.contactType == CreateContactTypeLink) {
        [self shareInvitationClicked];
    } else {
        DLog(@"Unknown create contact type");
    }
    
    [self reload];
}

- (void)didGetMessages
{
    [self.tableView reloadData];
    
    [self.detailViewController didGetMessages];
}

- (void)didChangeTrust
{
    [self updateContactDetail];
}

- (void)didFetchExtendedPublicKey
{
    [self updateContactDetail];
    
    [self.detailViewController showExtendedPublicKey];
}

- (void)didReadMessage:(NSString *)message
{
    [self.detailViewController didReadMessage:message];
}

- (void)didSendMessage:(NSString *)contact
{
    [self.detailViewController didSendMessage:contact];
}

@end