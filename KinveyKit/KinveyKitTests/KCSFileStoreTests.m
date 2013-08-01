//
//  KCSFileStoreTests.m
//  KinveyKit
//
//  Created by Michael Katz on 6/18/13.
//  Copyright (c) 2013 Kinvey. All rights reserved.
//

#import "KCSFileStoreTests.h"
#import "TestUtils.h"

#import "KCSFile.h"
#import "KCSFileStore.h"
#import "NSArray+KinveyAdditions.h"
#import "NSString+KinveyAdditions.h"
#import "KCSHiddenMethods.h"

#define KTAssertIncresing(var) \
{ \
    KTAssertCountAtLeast(1, var); \
    NSMutableArray* lastdouble = [NSMutableArray arrayWith:var.count copiesOf:@(-1)]; \
    for (id v in var) { \
        NSArray* vArr = [NSArray wrapIfNotArray:v]; \
        [vArr enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) { \
                double thisdouble = [obj doubleValue]; \
                STAssertTrue(thisdouble >= [lastdouble[idx] doubleValue], @"should be increasing value"); \
                lastdouble[idx] = @(thisdouble); \
            }];\
}}


#define SETUP_PROGRESS \
    NSMutableArray* progresses = [NSMutableArray array]; \
    NSMutableArray* datas = [NSMutableArray array];
#define PROGRESS_BLOCK \
    ^(NSArray *objects, double percentComplete) { \
        [progresses addObject:@(percentComplete)]; \
        [datas addObject:[objects valueForKeyPath:@"length"]]; \
    }
#define ASSERT_PROGESS \
    KTAssertIncresing(progresses); \
    KTAssertIncresing(datas);

#define SLEEP_TIMEINTERVAL 20
#define PAUSE NSLog(@"sleeping for %u seconds....",SLEEP_TIMEINTERVAL); [NSThread sleepForTimeInterval:SLEEP_TIMEINTERVAL];


#define kTestId @"testData"
#define kTestMimeType @"text/plain"
#define kTestFilename @"test.txt"
#define kTestSize testData().length

#define kImageFilename @"mavericks.jpg"
#define kImageMimeType @"image/jpeg"
#define kImageSize 3510397

//copy for testing
@interface KCSDownloadStreamRequest : NSObject
@property (nonatomic) unsigned long long bytesWritten;
@end


@implementation KCSFileStoreTests

NSData* testData()
{
    NSString* loremIpsum = @"Et quidem saepe quaerimus verbum Latinum par Graeco et quod idem valeat; Non quam nostram quidem, inquit Pomponius iocans; Ex rebus enim timiditas, non ex vocabulis nascitur. Nunc vides, quid faciat. Tum Piso: Quoniam igitur aliquid omnes, quid Lucius noster? Graece donan, Latine voluptatem vocant. Mihi, inquam, qui te id ipsum rogavi? Quem Tiberina descensio festo illo die tanto gaudio affecit, quanto L. Primum in nostrane potestate est, quid meminerimus? Si quidem, inquit, tollerem, sed relinquo. Quo modo autem philosophus loquitur? Sic enim censent, oportunitatis esse beate vivere.";
    NSData* ipsumData = [loremIpsum dataUsingEncoding:NSUTF16BigEndianStringEncoding];
    return ipsumData;
}

- (NSURL*) largeImageURL
{
    return [[NSBundle bundleForClass:[self class]] URLForResource:@"mavericks" withExtension:@"jpg"];
}

- (void) setUpTestFile
{
    KCSMetadata* metadata = [[KCSMetadata alloc] init];
    [metadata setGloballyWritable:YES];
    [metadata setGloballyReadable:YES];

    self.done = NO;
    [KCSFileStore uploadData:testData() options:@{ KCSFileId : kTestId, KCSFileACL : metadata, KCSFileMimeType : kTestMimeType, KCSFileFileName : kTestFilename} completionBlock:^(KCSFile *uploadInfo, NSError *error) {
        STAssertNoError_;
        self.done = YES;
    } progressBlock:nil];
    [self poll];
}

- (KCSFile*) getMetadataForId:(NSString*)fileId
{
    KCSAppdataStore* metaStore = [KCSAppdataStore storeWithCollection:[KCSCollection fileMetadataCollection] options:nil];
    
    self.done = NO;
    __block KCSFile* info = nil;
    [metaStore loadObjectWithID:fileId withCompletionBlock:^(NSArray *objectsOrNil, NSError *errorOrNil) {
        STAssertNoError;
        KTAssertCount(1, objectsOrNil);
        info = objectsOrNil[0];
        self.done = YES;
    } withProgressBlock:nil];
    [self poll];

    return info;
}

- (NSURL*) getDownloadURLForId:(NSString*)fileId
{
    KCSFile* downloadFile = [self getMetadataForId:fileId];
    NSURL* downloadURL = downloadFile.remoteURL;
    STAssertNotNil(downloadURL, @"Should have a valid download URL");
    return downloadURL;
}

- (void)setUp
{
    [super setUp];
    
    STAssertTrue([TestUtils setUpKinveyUnittestBackend], @"Should be set up.");
    
    self.done = NO;
    [self setUpTestFile];
}

- (void)tearDown
{
    self.done = NO;
    [KCSFileStore deleteFile:kTestId completionBlock:^(unsigned long count, NSError *errorOrNil) {
        if (errorOrNil != nil && errorOrNil.code == KCSNotFoundError) {
            //was hopefully removed by a test
        } else {
            STAssertNoError;
            STAssertEquals((unsigned long)1, count, @"should have deleted the temp data");
        }
        self.done = YES;
    }];
    [self poll];
    
    [super tearDown];
}

#pragma mark - Download Data

- (void)testDownloadBasic
{
    self.done = NO;
    SETUP_PROGRESS
    [KCSFileStore downloadData:kTestId completionBlock:^(NSArray *downloadedResources, NSError *error) {
        STAssertNoError_;
        //assert one KCSFile & its data is the right data
        STAssertNotNil(downloadedResources, @"should have a resource");
        KTAssertCount(1, downloadedResources);
        
        KCSFile* resource = downloadedResources[0];
        STAssertNil(resource.localURL, @"should have no local url for data");
        STAssertEqualObjects(resource.fileId, kTestId, @"file ids should match");
        STAssertEqualObjects(resource.filename, kTestFilename, @"should have a filename");
        STAssertEqualObjects(resource.mimeType, kTestMimeType, @"should have a mime type");
        
        NSData* origData = testData();
        
        STAssertEqualObjects(resource.data, origData, @"should have matching data");
        STAssertEquals(resource.length, origData.length, @"should have matching lengths");
        
        self.done = YES;
    } progressBlock:PROGRESS_BLOCK];
    [self poll];
    ASSERT_PROGESS
}

//TODO: Test error conditions
//TODO: Test multiple ids
//TODO: test path components slashes, spaces, etc, dots
//TODO: test no mimeType
//TODO: test content type

- (void) testDownloadToFile
{
    self.done = NO;
    SETUP_PROGRESS
    [KCSFileStore downloadFile:kTestId options:nil completionBlock:^(NSArray *downloadedResources, NSError *error) {
        STAssertNoError_;
        //assert one KCSFile & its data is the right data
        STAssertNotNil(downloadedResources, @"should have a resource");
        KTAssertCount(1, downloadedResources);
        
        KCSFile* resource = downloadedResources[0];
        STAssertNil(resource.data, @"should have no local data");
        STAssertEqualObjects(resource.fileId, kTestId, @"file ids should match");
        STAssertEqualObjects(resource.filename, kTestFilename, @"should have a filename");
        STAssertEqualObjects(resource.mimeType, kTestMimeType, @"should have a mime type");
        
        NSURL* localURL = resource.localURL;
        STAssertNotNil(localURL, @"should have a URL");
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:[localURL path]];
        STAssertTrue(exists, @"file should exist");
        
        error = nil;
        NSDictionary* attr = [[NSFileManager defaultManager] attributesOfItemAtPath:[localURL path] error:&error];
        STAssertNil(error, @"%@",error);
        
        NSData* origData = testData();
        KTAssertEqualsInt([attr[NSFileSize] intValue], origData.length, @"should have matching data");
        
        [[NSFileManager defaultManager] removeItemAtURL:resource.localURL error:&error];
        STAssertNoError_
        
        self.done = YES;
    } progressBlock:PROGRESS_BLOCK];
    [self poll];
    ASSERT_PROGESS
}

- (void) testDownloadToFileOptionsFilename
{
    NSString* filename = @"hookemsnivy.rtf";
    
    self.done = NO;
    [KCSFileStore downloadFile:kTestId options:@{KCSFileFileName : filename} completionBlock:^(NSArray *downloadedResources, NSError *error) {
        STAssertNoError_
        KTAssertCount(1, downloadedResources);
        KCSFile* dlFile = downloadedResources[0];
        
        NSURL* localURL = dlFile.localURL;
        STAssertNotNil(dlFile.localURL, @"should be a local URL");
        STAssertEqualObjects([localURL lastPathComponent], filename, @"local file should have the specified filename");
        STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[localURL path]], @"should exist");
        NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[localURL path] error:&error];
        STAssertNoError_;
        
        NSData* origData = testData();
        KTAssertEqualsInt([attributes[NSFileSize] intValue], origData.length, @"should have matching data");

        [[NSFileManager defaultManager] removeItemAtURL:localURL error:&error];
        STAssertNoError_
        self.done = YES;
    } progressBlock:nil];
    [self poll];
}

//TODO: test specifying location
//TODO: get by filename!

- (void) testGetByFileName
{
    self.done = NO;
    __block NSString* fileId;
    [KCSFileStore uploadFile:[self largeImageURL] options:nil completionBlock:^(KCSFile *uploadInfo, NSError *error) {
        STAssertNoError_;
        fileId = uploadInfo.fileId;
        self.done = YES;
    } progressBlock:nil];
    [self poll];
    
    self.done = NO;
    SETUP_PROGRESS
    [KCSFileStore downloadDataByName:kImageFilename completionBlock:^(NSArray *downloadedResources, NSError *error) {
        STAssertNoError_;
        //assert one KCSFile & its data is the right data
        STAssertNotNil(downloadedResources, @"should have a resource");
        KTAssertCount(1, downloadedResources);
        
        KCSFile* resource = downloadedResources[0];
        STAssertNil(resource.localURL, @"should have no local url for data");
        STAssertNotNil(resource.data, @"Should have data");
        STAssertEqualObjects(resource.fileId, fileId, @"file ids should match");
        STAssertEqualObjects(resource.filename, kImageFilename, @"should have a filename");
        STAssertEqualObjects(resource.mimeType, kImageMimeType, @"should have a mime type");
        KTAssertEqualsInt(resource.length, kImageSize, @"should have matching lengths");
        KTAssertEqualsInt(resource.data.length, kImageSize, @"should have matching lengths");
        
        self.done = YES;
    } progressBlock:PROGRESS_BLOCK];
    [self poll];
    ASSERT_PROGESS
    
    if (fileId) {
        self.done = NO;
        [KCSFileStore deleteFile:fileId completionBlock:^(unsigned long count, NSError *errorOrNil) {
            STAssertNoError;
            self.done = YES;
        }];
        [self poll];
    }
}


//TODO: query by filename

- (void) testGetFileIsNotThere
{
    self.done = NO;
    SETUP_PROGRESS
    [KCSFileStore downloadFile:@"NOSUCHFILE" options:nil completionBlock:^(NSArray *downloadedResources, NSError *error) {
        STAssertNotNil(error, @"should get an error");
        STAssertNil(downloadedResources, @"should get no resources");
        STAssertEqualObjects(error.domain, KCSFileStoreErrorDomain, @"Should be a file error");
        KTAssertEqualsInt(error.code, KCSNotFoundError, @"should be a 404");
        self.done = YES;
    } progressBlock:PROGRESS_BLOCK];
    [self poll];
    KTAssertCount(0, progresses);
    KTAssertCount(0, datas);
}

#pragma mark - download from a resolved URL

- (void) testDownloadWithResolvedURL
{
    NSURL* downloadURL = [self getDownloadURLForId:kTestId];
    
    self.done = NO;
    SETUP_PROGRESS
    [KCSFileStore downloadFileWithResolvedURL:downloadURL options:nil completionBlock:^(NSArray *downloadedResources, NSError *error) {
        STAssertNoError_
        KTAssertCount(1, downloadedResources);
        KCSFile* dlFile = downloadedResources[0];
        STAssertNil(dlFile.data, @"no data");
        STAssertEqualObjects(dlFile.filename, kTestFilename, @"should match filenames");
        STAssertEqualObjects(dlFile.fileId, kTestId, @"should match ids");
        STAssertEquals(dlFile.length, testData().length, @"lengths should match");
        STAssertEqualObjects(dlFile.mimeType, kTestMimeType, @"mime types should match");
        STAssertNotNil(dlFile.localURL, @"should be a local URL");
        STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[dlFile.localURL path]], @"should exist");
        NSData* downloadedData = [NSData dataWithContentsOfURL:dlFile.localURL];
        STAssertEqualObjects(downloadedData, testData(), @"should get our test data back");
        [[NSFileManager defaultManager] removeItemAtURL:dlFile.localURL error:&error];
        STAssertNoError_
        self.done = YES;
    } progressBlock:PROGRESS_BLOCK];
    [self poll];
    ASSERT_PROGESS
}

- (void) testDownloadWithResolvedURLOptionsFilename
{
    NSString* filename = @"hookemsnivy.rtf";
    NSURL* downloadURL = [self getDownloadURLForId:kTestId];
    
    self.done = NO;
    SETUP_PROGRESS
    [KCSFileStore downloadFileWithResolvedURL:downloadURL options:@{KCSFileFileName : filename} completionBlock:^(NSArray *downloadedResources, NSError *error) {
        STAssertNoError_
        KTAssertCount(1, downloadedResources);
        KCSFile* dlFile = downloadedResources[0];
        STAssertNil(dlFile.data, @"no data");
        STAssertEqualObjects(dlFile.filename, filename, @"should match filenames");
        STAssertEqualObjects(dlFile.fileId, kTestId, @"should match ids");
        STAssertEquals(dlFile.length, testData().length, @"lengths should match");
        STAssertEqualObjects(dlFile.mimeType, kTestMimeType, @"mime types should match");
        STAssertNotNil(dlFile.localURL, @"should be a local URL");
        STAssertEqualObjects([dlFile.localURL lastPathComponent], filename, @"local file should have the specified filename");
        STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[dlFile.localURL path]], @"should exist");
        NSData* downloadedData = [NSData dataWithContentsOfURL:dlFile.localURL];
        STAssertEqualObjects(downloadedData, testData(), @"should get our test data back");
        [[NSFileManager defaultManager] removeItemAtURL:dlFile.localURL error:&error];
        STAssertNoError_
        self.done = YES;
    } progressBlock:PROGRESS_BLOCK];
    [self poll];
    ASSERT_PROGESS
}

- (void) testDownloadWithResolvedURLOptionsIfNewer
{
    //start by downloading file
    __block NSDate* firsDate = nil;
    self.done = NO;
    [KCSFileStore downloadFile:kTestId options:nil completionBlock:^(NSArray *downloadedResources, NSError *error) {
        STAssertNoError_
        KTAssertCount(1, downloadedResources);
        KCSFile* dlFile = downloadedResources[0];
        STAssertNotNil(dlFile.localURL, @"should be a local URL");
        STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[dlFile.localURL path]], @"should exist");
        NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[dlFile.localURL path] error:&error];
        STAssertNoError_;
        firsDate = attributes[NSFileModificationDate];
        self.done = YES;
    } progressBlock:nil];
    [self poll];
    
    NSURL* downloadURL = [self getDownloadURLForId:kTestId];
    
    self.done = NO;
    SETUP_PROGRESS
    [KCSFileStore downloadFileWithResolvedURL:downloadURL options:@{KCSFileOnlyIfNewer : @(YES)} completionBlock:^(NSArray *downloadedResources, NSError *error) {
        STAssertNoError_
        KTAssertCount(1, downloadedResources);
        KCSFile* dlFile = downloadedResources[0];
        STAssertNil(dlFile.data, @"no data");
        STAssertEqualObjects(dlFile.filename, kTestFilename, @"should match filenames");
        STAssertEqualObjects(dlFile.fileId, kTestId, @"should match ids");
        STAssertEquals(dlFile.length, testData().length, @"lengths should match");
        STAssertEqualObjects(dlFile.mimeType, kTestMimeType, @"mime types should match");
        STAssertNotNil(dlFile.localURL, @"should be a local URL");
        STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[dlFile.localURL path]], @"should exist");
        NSData* downloadedData = [NSData dataWithContentsOfURL:dlFile.localURL];
        STAssertEqualObjects(downloadedData, testData(), @"should get our test data back");
        
        NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[dlFile.localURL path] error:&error];
        STAssertNoError_;
        NSDate* thisDate = attributes[NSFileModificationDate];
        STAssertEqualObjects(thisDate, firsDate, @"file should not have been modified");
        
        [[NSFileManager defaultManager] removeItemAtURL:dlFile.localURL error:&error];
        STAssertNoError_
        self.done = YES;
    } progressBlock:PROGRESS_BLOCK];
    [self poll];
    //should have no progress b/c they are local
    KTAssertCount(0, progresses);
    KTAssertCount(0, datas);
}


- (void) testDownloadWithResolvedURLOptionsIfNewerButNotNewer
{
    //start by downloading file
    
    __block NSDate* firstDate = nil;
    self.done = NO;
    [KCSFileStore downloadFile:kTestId options:nil completionBlock:^(NSArray *downloadedResources, NSError *error) {
        STAssertNoError_
        KTAssertCount(1, downloadedResources);
        KCSFile* dlFile = downloadedResources[0];
        STAssertNotNil(dlFile.localURL, @"should be a local URL");
        STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[dlFile.localURL path]], @"should exist");
        NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[dlFile.localURL path] error:&error];
        STAssertNoError_;
        firstDate = attributes[NSFileModificationDate];
        self.done = YES;
    } progressBlock:nil];
    [self poll];
    
    
    PAUSE
    
    //then re-upload file
    self.done = NO;
    [KCSFileStore uploadData:testData() options:@{KCSFileId : kTestId} completionBlock:^(KCSFile *uploadInfo, NSError *error) {
        STAssertNoError_
        self.done = YES;
    } progressBlock:nil];
    [self poll];
    
    NSURL* downloadURL = [self getDownloadURLForId:kTestId];
    
    self.done = NO;
    SETUP_PROGRESS
    [KCSFileStore downloadFileWithResolvedURL:downloadURL options:@{KCSFileOnlyIfNewer : @(YES)} completionBlock:^(NSArray *downloadedResources, NSError *error) {
        STAssertNoError_
        KTAssertCount(1, downloadedResources);
        KCSFile* dlFile = downloadedResources[0];
        STAssertNil(dlFile.data, @"no data");
        STAssertEqualObjects(dlFile.filename, kTestFilename, @"should match filenames");
        STAssertEqualObjects(dlFile.fileId, kTestId, @"should match ids");
        STAssertEquals(dlFile.length, testData().length, @"lengths should match");
        STAssertEqualObjects(dlFile.mimeType, kTestMimeType, @"mime types should match");
        STAssertNotNil(dlFile.localURL, @"should be a local URL");
        STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[dlFile.localURL path]], @"should exist");
        NSData* downloadedData = [NSData dataWithContentsOfURL:dlFile.localURL];
        STAssertEqualObjects(downloadedData, testData(), @"should get our test data back");
        
        NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[dlFile.localURL path] error:&error];
        STAssertNoError_;
        NSDate* thisDate = attributes[NSFileModificationDate];
        NSComparisonResult oldComparedToNew = [firstDate compare:thisDate];
        STAssertTrue(oldComparedToNew == NSOrderedAscending, @"file should not have been modified");
        
        [[NSFileManager defaultManager] removeItemAtURL:dlFile.localURL error:&error];
        STAssertNoError_
        self.done = YES;
    } progressBlock:PROGRESS_BLOCK];
    [self poll];
    ASSERT_PROGESS
}

- (void) testDownloadWithResolvedURLOptionsFilenameAndNewer
{
    NSString* filename = @"hookemsnivy.rtf";
    
    //start by downloading file
    __block NSDate* firsDate = nil;
    self.done = NO;
    [KCSFileStore downloadFile:kTestId options:@{KCSFileFileName : filename} completionBlock:^(NSArray *downloadedResources, NSError *error) {
        STAssertNoError_
        KTAssertCount(1, downloadedResources);
        KCSFile* dlFile = downloadedResources[0];
        STAssertNotNil(dlFile.localURL, @"should be a local URL");
        STAssertEqualObjects([dlFile.localURL lastPathComponent], filename, @"local file should have the specified filename");
        STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[dlFile.localURL path]], @"should exist");
        NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[dlFile.localURL path] error:&error];
        STAssertNoError_;
        firsDate = attributes[NSFileModificationDate];
        self.done = YES;
    } progressBlock:nil];
    [self poll];
    
    NSURL* downloadURL = [self getDownloadURLForId:kTestId];
    
    self.done = NO;
    SETUP_PROGRESS
    [KCSFileStore downloadFileWithResolvedURL:downloadURL options:@{KCSFileFileName : filename, KCSFileOnlyIfNewer : @(YES)} completionBlock:^(NSArray *downloadedResources, NSError *error) {
        STAssertNoError_
        KTAssertCount(1, downloadedResources);
        KCSFile* dlFile = downloadedResources[0];
        STAssertNil(dlFile.data, @"no data");
        STAssertEqualObjects(dlFile.filename, filename, @"should match filenames");
        STAssertEqualObjects(dlFile.fileId, kTestId, @"should match ids");
        STAssertEquals(dlFile.length, testData().length, @"lengths should match");
        STAssertEqualObjects(dlFile.mimeType, @"text/rtf", @"mime types should match");
        STAssertNotNil(dlFile.localURL, @"should be a local URL");
        STAssertEqualObjects([dlFile.localURL lastPathComponent], filename, @"local file should have the specified filename");
        STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[dlFile.localURL path]], @"should exist");

        NSData* downloadedData = [NSData dataWithContentsOfURL:dlFile.localURL];
        STAssertEqualObjects(downloadedData, testData(), @"should get our test data back");
        
        NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[dlFile.localURL path] error:&error];
        STAssertNoError_;
        NSDate* thisDate = attributes[NSFileModificationDate];
        STAssertEqualObjects(thisDate, firsDate, @"file should not have been modified");
        
        [[NSFileManager defaultManager] removeItemAtURL:dlFile.localURL error:&error];
        STAssertNoError_
        self.done = YES;
    } progressBlock:PROGRESS_BLOCK];
    [self poll];
    //should have no progress b/c they are local
    KTAssertCount(0, progresses);
    KTAssertCount(0, datas);

}

- (void) testDownloadWithResolvedURLStopAndResume
{
    self.done = NO;
    __block NSString* fileId;
    [KCSFileStore uploadFile:[self largeImageURL] options:nil completionBlock:^(KCSFile *uploadInfo, NSError *error) {
        STAssertNoError_;
        fileId = uploadInfo.fileId;
        self.done = YES;
    } progressBlock:nil];
    [self poll];
    
    NSURL* downloadURL = [self getDownloadURLForId:fileId];
    
    self.done = NO;
    __block NSDate* localLMT = nil;
    SETUP_PROGRESS
    [KCSFileStore downloadFileWithResolvedURL:downloadURL options:nil completionBlock:^(NSArray *downloadedResources, NSError *error) {
        STAssertNotNil(error, @"Should get an error");
        KTAssertCount(1, downloadedResources);
        KCSFile* dlFile = downloadedResources[0];
        STAssertNil(dlFile.data, @"no data");
        STAssertEqualObjects(dlFile.filename, kImageFilename, @"should match filenames");
        STAssertEqualObjects(dlFile.fileId, fileId, @"should match ids");
        STAssertTrue(dlFile.length < kImageSize, @"lengths should match");
        STAssertEqualObjects(dlFile.mimeType, kImageMimeType, @"mime types should match");
        STAssertNotNil(dlFile.localURL, @"should be a local URL");
        STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[dlFile.localURL path]], @"should exist");
        
        error = nil;
        NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[dlFile.localURL path] error:&error];
        STAssertNoError_;
        localLMT = attributes[NSFileModificationDate];

        self.done = YES;
    } progressBlock:PROGRESS_BLOCK];
    id lastRequest = [KCSFileStore lastRequest];
    double delayInSeconds = 0.25;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        NSLog(@"cancelling...");
        [lastRequest cancel];
    });
    [self poll];
    
    unsigned long long firstWritten = [lastRequest bytesWritten];
    
    [NSThread sleepForTimeInterval:1];
    self.done = NO;
    [KCSFileStore downloadFileWithResolvedURL:downloadURL options:@{KCSFileResume : @(YES)} completionBlock:^(NSArray *downloadedResources, NSError *error) {
        STAssertNoError_
        KTAssertCount(1, downloadedResources);
        KCSFile* dlFile = downloadedResources[0];
        STAssertNil(dlFile.data, @"no data");
        STAssertEqualObjects(dlFile.filename, kImageFilename, @"should match filenames");
        STAssertEqualObjects(dlFile.fileId, fileId, @"should match ids");
        KTAssertEqualsInt(dlFile.length, kImageSize, @"lengths should match");
        STAssertEqualObjects(dlFile.mimeType, kImageMimeType, @"mime types should match");
        STAssertNotNil(dlFile.localURL, @"should be a local URL");
        STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[dlFile.localURL path]], @"should exist");
        
        NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[dlFile.localURL path] error:&error];
        STAssertNoError_;
        NSDate* newLMT = attributes[NSFileModificationDate];
        NSComparisonResult oldComparedToNew = [localLMT compare:newLMT];
        STAssertTrue(oldComparedToNew == NSOrderedAscending, @"file should be updated");

        [[NSFileManager defaultManager] removeItemAtURL:dlFile.localURL error:&error];
        STAssertNoError_
        
        self.done = YES;
    } progressBlock:PROGRESS_BLOCK];
    [self poll];
    ASSERT_PROGESS
    
    lastRequest = [KCSFileStore lastRequest];
    unsigned long long secondWritten = [lastRequest bytesWritten];
    STAssertEquals(firstWritten + secondWritten, (unsigned long long) kImageSize, @"should have only downloaded the total num bytes");
}

- (void) testDownloadWithResolvedURLStopAndResumeFromBeginningIfNewer
{
    self.done = NO;
    __block NSString* fileId;
    [KCSFileStore uploadFile:[self largeImageURL] options:nil completionBlock:^(KCSFile *uploadInfo, NSError *error) {
        STAssertNoError_;
        fileId = uploadInfo.fileId;
        self.done = YES;
    } progressBlock:nil];
    [self poll];
    
    NSURL* downloadURL = [self getDownloadURLForId:fileId];
    
    //start a download and then abort it
    self.done = NO;
    __block NSDate* localLMT = nil;
    SETUP_PROGRESS
    [KCSFileStore downloadFileWithResolvedURL:downloadURL options:nil completionBlock:^(NSArray *downloadedResources, NSError *error) {
        STAssertNotNil(error, @"Should get an error");
        KTAssertCount(1, downloadedResources);
        KCSFile* dlFile = downloadedResources[0];
        STAssertNil(dlFile.data, @"no data");
        STAssertEqualObjects(dlFile.filename, kImageFilename, @"should match filenames");
        STAssertEqualObjects(dlFile.fileId, fileId, @"should match ids");
        STAssertTrue(dlFile.length < kImageSize, @"lengths should match");
        STAssertEqualObjects(dlFile.mimeType, kImageMimeType, @"mime types should match");
        STAssertNotNil(dlFile.localURL, @"should be a local URL");
        STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[dlFile.localURL path]], @"should exist");
        
        error = nil;
        NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[dlFile.localURL path] error:&error];
        STAssertNoError_;
        localLMT = attributes[NSFileModificationDate];
        
        self.done = YES;
    } progressBlock:PROGRESS_BLOCK];
    id lastRequest = [KCSFileStore lastRequest];
    double delayInSeconds = 0.25;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        NSLog(@"cancelling...");
        [lastRequest cancel];
    });
    [self poll];
    unsigned long long firstWritten = [lastRequest bytesWritten];
    
    //update the file
    PAUSE
    self.done = NO;
    [KCSFileStore uploadFile:[self largeImageURL] options:@{KCSFileId : fileId} completionBlock:^(KCSFile *uploadInfo, NSError *error) {
        STAssertNoError_;
        fileId = uploadInfo.fileId;
        self.done = YES;
    } progressBlock:nil];
    [self poll];
    
    //restart the download and make sure it starts over from the beginning
    self.done = NO;
    [KCSFileStore downloadFileWithResolvedURL:downloadURL options:@{KCSFileResume : @(YES), KCSFileOnlyIfNewer : @(YES)} completionBlock:^(NSArray *downloadedResources, NSError *error) {
        STAssertNoError_
        KTAssertCount(1, downloadedResources);
        KCSFile* dlFile = downloadedResources[0];
        STAssertNil(dlFile.data, @"no data");
        STAssertEqualObjects(dlFile.filename, kImageFilename, @"should match filenames");
        STAssertEqualObjects(dlFile.fileId, fileId, @"should match ids");
        KTAssertEqualsInt(dlFile.length, kImageSize, @"lengths should match");
        STAssertEqualObjects(dlFile.mimeType, kImageMimeType, @"mime types should match");
        STAssertNotNil(dlFile.localURL, @"should be a local URL");
        STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[dlFile.localURL path]], @"should exist");
        
        NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[dlFile.localURL path] error:&error];
        STAssertNoError_;
        NSDate* newLMT = attributes[NSFileModificationDate];
        STAssertTrue([localLMT compare:newLMT] == NSOrderedAscending, @"file should be updated");
        
        [[NSFileManager defaultManager] removeItemAtURL:dlFile.localURL error:&error];
        STAssertNoError_
        
        self.done = YES;
    } progressBlock:PROGRESS_BLOCK];
    [self poll];
    //Note: don't ASSERT_PROGRESS becuase progress is going to go 0, .1, .2.. for first download and start back at 0 for second download - no longer monotonically increasing
    
    lastRequest = [KCSFileStore lastRequest];
    unsigned long long secondWritten = [lastRequest bytesWritten];
    STAssertEquals(secondWritten, (unsigned long long) kImageSize, @"second download should be full file");
    STAssertEquals(firstWritten + secondWritten, (unsigned long long) kImageSize + firstWritten, @"should have restarted download");
}

- (void) testDownloadWithURLData
{
    NSURL* downloadURL = [self getDownloadURLForId:kTestId];
    
    self.done = NO;
    SETUP_PROGRESS
    [KCSFileStore downloadDataWithResolvedURL:downloadURL completionBlock:^(NSArray *downloadedResources, NSError *error) {
        STAssertNoError_
        KTAssertCount(1, downloadedResources);
        KCSFile* dlFile = downloadedResources[0];
        STAssertNotNil(dlFile.data, @"should have data");
        STAssertEqualObjects(dlFile.filename, kTestFilename, @"should match filenames");
        STAssertEqualObjects(dlFile.fileId, kTestId, @"should match ids");
        STAssertEquals(dlFile.length, testData().length, @"lengths should match");
        STAssertEqualObjects(dlFile.mimeType, kTestMimeType, @"mime types should match");
        STAssertNil(dlFile.localURL, @"should not have a local URL");
        STAssertEqualObjects(dlFile.data, testData(), @"should get our test data back");
        self.done = YES;
    } progressBlock:PROGRESS_BLOCK];
    [self poll];
    ASSERT_PROGESS
}

- (void) testResume
{
    //1. Upload Image
    self.done = NO;
    __block NSString* fileId;
    [KCSFileStore uploadFile:[self largeImageURL] options:nil completionBlock:^(KCSFile *uploadInfo, NSError *error) {
        STAssertNoError_;
        fileId = uploadInfo.fileId;
        self.done = YES;
    } progressBlock:nil];
    [self poll];
    
    //2. Start Download
    NSURL* downloadURL = [self getDownloadURLForId:fileId];
    
    self.done = NO;
    __block NSDate* localLMT = nil;
    __block NSURL* startedURL = nil;
    SETUP_PROGRESS
    [KCSFileStore downloadFileWithResolvedURL:downloadURL options:nil completionBlock:^(NSArray *downloadedResources, NSError *error) {
        STAssertNotNil(error, @"Should get an error");
        KTAssertCount(1, downloadedResources);
        KCSFile* dlFile = downloadedResources[0];
        STAssertNil(dlFile.data, @"no data");
        STAssertEqualObjects(dlFile.filename, kImageFilename, @"should match filenames");
        STAssertEqualObjects(dlFile.fileId, fileId, @"should match ids");
        STAssertTrue(dlFile.length < kImageSize, @"lengths should match");
        STAssertEqualObjects(dlFile.mimeType, kImageMimeType, @"mime types should match");
        STAssertNotNil(dlFile.localURL, @"should be a local URL");
        STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[dlFile.localURL path]], @"should exist");
        startedURL = dlFile.localURL;
        
        error = nil;
        NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[dlFile.localURL path] error:&error];
        STAssertNoError_;
        localLMT = attributes[NSFileModificationDate];
        
        self.done = YES;
    } progressBlock:PROGRESS_BLOCK];
    
    //3. Stop Download Mid-stream
    id lastRequest = [KCSFileStore lastRequest];
    double delayInSeconds = 0.25;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        NSLog(@"cancelling...");
        [lastRequest cancel];
    });
    [self poll];
    ASSERT_PROGESS
    unsigned long long firstWritten = [lastRequest bytesWritten];
    [NSThread sleepForTimeInterval:1];
    
    //4. Resume Download
    self.done = NO;
    [KCSFileStore resumeDownload:startedURL from:downloadURL completionBlock:^(NSArray *downloadedResources, NSError *error) {
        STAssertNoError_
        KTAssertCount(1, downloadedResources);
        KCSFile* dlFile = downloadedResources[0];
        STAssertNil(dlFile.data, @"no data");
        STAssertEqualObjects(dlFile.filename, kImageFilename, @"should match filenames");
        STAssertEqualObjects(dlFile.fileId, fileId, @"should match ids");
        KTAssertEqualsInt(dlFile.length, kImageSize, @"lengths should match");
        STAssertEqualObjects(dlFile.mimeType, kImageMimeType, @"mime types should match");
        STAssertNotNil(dlFile.localURL, @"should be a local URL");
        STAssertEqualObjects(dlFile.localURL, startedURL, @"should restart URL");
        STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[dlFile.localURL path]], @"should exist");
        
        NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[dlFile.localURL path] error:&error];
        STAssertNoError_;
        NSDate* newLMT = attributes[NSFileModificationDate];
        NSComparisonResult oldComparedToNew = [localLMT compare:newLMT];
        STAssertTrue(oldComparedToNew == NSOrderedAscending, @"file should be updated");
        
        [[NSFileManager defaultManager] removeItemAtURL:dlFile.localURL error:&error];
        STAssertNoError_
        
        self.done = YES;
    } progressBlock:PROGRESS_BLOCK];
    [self poll];
    ASSERT_PROGESS
    
    lastRequest = [KCSFileStore lastRequest];
    unsigned long long secondWritten = [lastRequest bytesWritten];
    STAssertEquals(firstWritten + secondWritten, (unsigned long long) kImageSize, @"should have only downloaded the total num bytes");
}

- (void) testTTLExpiresMidUpdate
{
    //1. Set a low ttl
    //2. Upload a large file w/pause
    
    self.done = NO;
    SETUP_PROGRESS
    __block NSString* newFileId = nil;
    NSURL* fileURL = [self largeImageURL];
    [KCSFileStore uploadFile:fileURL options:nil completionBlock:^(KCSFile *uploadInfo, NSError *error) {
        STAssertNoError_;
        STAssertNotNil(uploadInfo, @"uploadInfo should be a real value");
        STAssertNotNil(uploadInfo.filename, @"filename should have faule");
        STAssertNotNil(uploadInfo.fileId, @"should have a file id");
        STAssertFalse([uploadInfo.fileId isEqualToString:uploadInfo.filename], @"file id should be unique");
        
        KTAssertEqualsInt(uploadInfo.length, kImageSize, @"sizes should match");
        STAssertNil(uploadInfo.remoteURL, @"should be nil");
        STAssertNil(uploadInfo.data, @"should have nil data");
        STAssertEqualObjects(uploadInfo.mimeType, kImageMimeType, @"should use default mimetype");
        
        newFileId = uploadInfo.fileId;
        self.done = YES;
    } progressBlock:PROGRESS_BLOCK];
    
    [self poll];
    ASSERT_PROGESS
    STAssertNotNil(newFileId, @"Should get a file id");
    
    self.done = NO;
    [KCSFileStore downloadFile:newFileId options:@{KCSFileLinkExpirationTimeInterval : @0.01} completionBlock:^(NSArray *downloadedResources, NSError *error) {
        STAssertNoError_
        KTAssertCount(1, downloadedResources);
        KCSFile* dlFile = downloadedResources[0];
        STAssertNil(dlFile.data, @"no data");
        STAssertEqualObjects(dlFile.filename, kImageFilename, @"should match filenames");
        STAssertEqualObjects(dlFile.fileId, newFileId, @"should match ids");
        KTAssertEqualsInt(dlFile.length, kImageSize, @"lengths should match");
        STAssertEqualObjects(dlFile.mimeType, kImageMimeType, @"mime types should match");
        STAssertNotNil(dlFile.localURL, @"should be a local URL");
        STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[dlFile.localURL path]], @"should exist");
        
        [[NSFileManager defaultManager] removeItemAtURL:dlFile.localURL error:&error];
        STAssertNoError_
        
        self.done = YES;
    } progressBlock:nil];
    [self poll];
    
    self.done = NO;
    [KCSFileStore deleteFile:newFileId completionBlock:^(unsigned long count, NSError *errorOrNil) {
        STAssertNoError;
        self.done = YES;
    }];
    [self poll];
    
    
}



#pragma mark - Streaming

- (void) testStreamingBasic
{
    self.done = NO;
    [KCSFileStore getStreamingURL:kTestId completionBlock:^(KCSFile *streamingResource, NSError *error) {
        STAssertNoError_;
        STAssertNil(streamingResource.localURL, @"should have no local url for data");
        STAssertEqualObjects(streamingResource.fileId, kTestId, @"file ids should match");
        STAssertEqualObjects(streamingResource.filename, kTestFilename, @"should have a filename");
        STAssertEqualObjects(streamingResource.mimeType, kTestMimeType, @"should have a mime type");
        STAssertNil(streamingResource.data, @"should have no data");
        STAssertNil(streamingResource.data, @"should have no data");
        STAssertEquals(streamingResource.length, testData().length, @"should have matching lengths");
        STAssertNotNil(streamingResource.remoteURL, @"should have a remote URL");
        STAssertNotNil(streamingResource.expirationDate, @"should have a valid date");
        STAssertTrue([streamingResource.expirationDate isKindOfClass:[NSDate class]], @"should be a date");
        self.done = YES;
    }];
    [self poll];
}
//test error conditions
//test streaming by name
//to get uiimage with url

#pragma mark - Uploading

- (void) testSaveLocalResource
{
    self.done = NO;
    SETUP_PROGRESS
    __block NSString* newFileId = nil;
    [KCSFileStore uploadFile:[self largeImageURL] options:nil completionBlock:^(KCSFile *uploadInfo, NSError *error) {
        STAssertNoError_;
        STAssertNotNil(uploadInfo, @"uploadInfo should be a real value");
        STAssertEqualObjects(uploadInfo.filename, kImageFilename, @"filename should match");
        STAssertNotNil(uploadInfo.fileId, @"should have a file id");
        STAssertFalse([uploadInfo.fileId isEqualToString:kImageFilename], @"file id should be unique");
        KTAssertEqualsInt(uploadInfo.length, kImageSize, @"sizes should match");
        
        newFileId = uploadInfo.fileId;
        self.done = YES;
    } progressBlock:PROGRESS_BLOCK];
    [self poll];
    ASSERT_PROGESS
    
    if (newFileId) {
        self.done = NO;
        [KCSFileStore deleteFile:newFileId completionBlock:^(unsigned long count, NSError *errorOrNil) {
            STAssertNoError;
            self.done = YES;
        }];
        [self poll];
    }
}

- (void) testUploadLFOptions
{
    self.done = NO;
    SETUP_PROGRESS
    __block NSString* newFileId = nil;
    NSString* fileId = [NSString UUID];
    [KCSFileStore uploadFile:[self largeImageURL]
                     options:@{KCSFileFileName: @"FOO",
                               KCSFileMimeType: @"BAR",
                               KCSFileId: fileId }
             completionBlock:^(KCSFile *uploadInfo, NSError *error) {
        STAssertNoError_;
        STAssertNotNil(uploadInfo, @"uploadInfo should be a real value");
        STAssertEqualObjects(uploadInfo.filename, @"FOO", @"filename should match");
        STAssertNotNil(uploadInfo.fileId, @"should have a file id");
        STAssertEqualObjects(uploadInfo.fileId, fileId, @"file id should be match");
                 STAssertEqualObjects(uploadInfo.mimeType, @"BAR", @"mime type should match");
                 KTAssertEqualsInt(uploadInfo.length, kImageSize, @"sizes shoukld match");
        
        newFileId = uploadInfo.fileId;
        self.done = YES;
    } progressBlock:PROGRESS_BLOCK];
    [self poll];
    ASSERT_PROGESS
    
    KCSFile* metaFile = [self getMetadataForId:newFileId];
    STAssertNotNil(metaFile, @"metaFile should be a real value");
    STAssertEqualObjects(metaFile.filename, @"FOO", @"filename should match");
    STAssertEqualObjects(metaFile.fileId, fileId, @"file id should be match");
    STAssertEqualObjects(metaFile.mimeType, @"BAR", @"mime type should match");
    KTAssertEqualsInt(metaFile.length, kImageSize, @"sizes shoukld match");

    if (newFileId) {
        self.done = NO;
        [KCSFileStore deleteFile:newFileId completionBlock:^(unsigned long count, NSError *errorOrNil) {
            STAssertNoError;
            self.done = YES;
        }];
        [self poll];
    }
}

- (void) testErrorOnSpecifyingSizeOfUpload
{
    self.done = NO;
    void(^badcall)() = ^{[KCSFileStore uploadFile:[self largeImageURL]
                                            options:@{KCSFileSize: @(100),
                                                      KCSFileMimeType: @"BAR"}
                                    completionBlock:^(KCSFile *uploadInfo, NSError *error) {
                                        STAssertNoError_;
                                        self.done = YES;
                                    } progressBlock:nil];};
    STAssertThrows(badcall(), @"Should have a size issue");
}

- (void) testMimeTypeGuessForSpecifiedFilename
{
    self.done = NO;
    SETUP_PROGRESS
    __block NSString* newFileId = nil;
    [KCSFileStore uploadData:testData()
                     options:@{KCSFileFileName: @"FOO"}
             completionBlock:^(KCSFile *uploadInfo, NSError *error) {
                 STAssertNoError_;
                 STAssertNotNil(uploadInfo, @"uploadInfo should be a real value");
                 STAssertEqualObjects(uploadInfo.filename, @"FOO", @"filename should match");
                 STAssertNotNil(uploadInfo.fileId, @"should have a file id");
                 STAssertEqualObjects(uploadInfo.mimeType, @"application/octet-stream", @"mime type should be bin");
                 KTAssertEqualsInt(uploadInfo.length, kTestSize, @"sizes shoukld match");
                 
                 newFileId = uploadInfo.fileId;
                 self.done = YES;
             } progressBlock:PROGRESS_BLOCK];
    [self poll];
    ASSERT_PROGESS

    if (newFileId) {
        self.done = NO;
        [KCSFileStore deleteFile:newFileId completionBlock:^(unsigned long count, NSError *errorOrNil) {
            STAssertNoError;
            self.done = YES;
        }];
        [self poll];
    }
    
    self.done = NO;
    [KCSFileStore uploadData:testData()
                     options:@{KCSFileFileName: @"jazz.wav"}
             completionBlock:^(KCSFile *uploadInfo, NSError *error) {
                 STAssertNoError_;
                 STAssertNotNil(uploadInfo, @"uploadInfo should be a real value");
                 STAssertEqualObjects(uploadInfo.filename, @"jazz.wav", @"filename should match");
                 STAssertNotNil(uploadInfo.fileId, @"should have a file id");
                 STAssertEqualObjects(uploadInfo.mimeType, @"audio/wav", @"mime type should be audio");
                 KTAssertEqualsInt(uploadInfo.length, kTestSize, @"sizes shoukld match");
                 
                 newFileId = uploadInfo.fileId;
                 self.done = YES;
             } progressBlock:nil];
    [self poll];
    
    if (newFileId) {
        self.done = NO;
        [KCSFileStore deleteFile:newFileId completionBlock:^(unsigned long count, NSError *errorOrNil) {
            STAssertNoError;
            self.done = YES;
        }];
        [self poll];
    }
    
    self.done = NO;
    [KCSFileStore uploadData:testData()
                     options:nil
             completionBlock:^(KCSFile *uploadInfo, NSError *error) {
                 STAssertNoError_;
                 STAssertNotNil(uploadInfo, @"uploadInfo should be a real value");
                 STAssertNotNil(uploadInfo.filename, @"filename should be set");
                 STAssertNotNil(uploadInfo.fileId, @"should have a file id");
                 STAssertEqualObjects(uploadInfo.mimeType, @"application/octet-stream", @"mime type should be bin");
                 KTAssertEqualsInt(uploadInfo.length, kTestSize, @"sizes shoukld match");
                 
                 newFileId = uploadInfo.fileId;
                 self.done = YES;
             } progressBlock:nil];
    [self poll];
    
    if (newFileId) {
        self.done = NO;
        [KCSFileStore deleteFile:newFileId completionBlock:^(unsigned long count, NSError *errorOrNil) {
            STAssertNoError;
            self.done = YES;
        }];
        [self poll];
    }
}


- (void) testUploadLFPublic
{
    self.done = NO;
    SETUP_PROGRESS
    __block NSString* newFileId = nil;
    NSURL* fileURL = [self largeImageURL];
    [KCSFileStore uploadFile:fileURL options:@{KCSFilePublic : @YES} completionBlock:^(KCSFile *uploadInfo, NSError *error) {
        STAssertNoError_;
        STAssertNotNil(uploadInfo, @"uploadInfo should be a real value");
        STAssertNotNil(uploadInfo.filename, @"filename should have faule");
        STAssertNotNil(uploadInfo.fileId, @"should have a file id");
        STAssertFalse([uploadInfo.fileId isEqualToString:uploadInfo.filename], @"file id should be unique");
        STAssertEqualObjects(uploadInfo.public, @(YES), @"should be public");
        
        KTAssertEqualsInt(uploadInfo.length, kImageSize, @"sizes should match");
        STAssertNotNil(uploadInfo.localURL, @"should not be nil");
        STAssertNil(uploadInfo.remoteURL, @"should be nil");
        STAssertNil(uploadInfo.data, @"should have nil data");
        STAssertEqualObjects(uploadInfo.mimeType, kImageMimeType, @"should use default mimetype");
        
        newFileId = uploadInfo.fileId;
        self.done = YES;
    } progressBlock:PROGRESS_BLOCK];
    
    [self poll];
    ASSERT_PROGESS
    STAssertNotNil(newFileId, @"Should get a file id");
    
    self.done = NO;
    [KCSFileStore getStreamingURL:newFileId options:@{KCSFileLinkExpirationTimeInterval : @1} completionBlock:^(KCSFile *streamingResource, NSError *error) {
        STAssertNoError_;
        NSURL* remoteURL = streamingResource.remoteURL;
        STAssertNotNil(remoteURL, @"should have a valid URL");
        
        NSLog(@"Sleeping for 10s to wait out the ttl");
        [NSThread sleepForTimeInterval:10];
        
        NSData* data = [NSData dataWithContentsOfURL:remoteURL];
        STAssertNotNil(data, @"should get back new data");
        STAssertEqualObjects(data, [NSData dataWithContentsOfURL:[self largeImageURL]], @"should get back our test data");
        self.done = YES;
    }];
    [self poll];
    
    self.done = NO;
    [KCSFileStore deleteFile:newFileId completionBlock:^(unsigned long count, NSError *errorOrNil) {
        STAssertNoError;
        self.done = YES;
    }];
    [self poll];

}

- (void) testUploadLFACL
{
    self.done = NO;
    SETUP_PROGRESS
    __block NSString* newFileId = nil;
    KCSMetadata* metadata =[[KCSMetadata alloc] init];
    [metadata setGloballyReadable:YES];
    [metadata setGloballyWritable:YES];
    [KCSFileStore uploadFile:[self largeImageURL] options:@{KCSFileACL : metadata} completionBlock:^(KCSFile *uploadInfo, NSError *error) {
        STAssertNoError_;
        STAssertNotNil(uploadInfo, @"uploadInfo should be a real value");
        STAssertNotNil(uploadInfo.filename, @"filename should have faule");
        STAssertNotNil(uploadInfo.fileId, @"should have a file id");
        STAssertFalse([uploadInfo.fileId isEqualToString:uploadInfo.filename], @"file id should be unique");
        
        KCSMetadata* meta = uploadInfo.metadata;
        STAssertNotNil(meta, @"should not be nil");
        STAssertTrue(meta.isGloballyWritable, @"gw should take");
        STAssertTrue(meta.isGloballyReadable, @"gr should take");

        
        KTAssertEqualsInt(uploadInfo.length, kImageSize, @"sizes should match");
        STAssertNotNil(uploadInfo.localURL, @"should not be nil");
        STAssertNil(uploadInfo.remoteURL, @"should be nil");
        STAssertNil(uploadInfo.data, @"should have nil data");
        STAssertEqualObjects(uploadInfo.mimeType, kImageMimeType, @"should use default mimetype");
        
        newFileId = uploadInfo.fileId;
        self.done = YES;
    } progressBlock:PROGRESS_BLOCK];
    
    [self poll];
    ASSERT_PROGESS
    STAssertNotNil(newFileId, @"Should get a file id");
    
    self.done = NO;
    KCSAppdataStore* fileStore = [KCSAppdataStore storeWithCollection:[KCSCollection fileMetadataCollection] options:nil];
    [fileStore loadObjectWithID:newFileId withCompletionBlock:^(NSArray *objectsOrNil, NSError *errorOrNil) {
        STAssertNoError;
        STAssertObjects(1);
        KCSFile* file = objectsOrNil[0];
        KCSMetadata* meta = file.metadata;
        STAssertNotNil(meta, @"should not be nil");
        STAssertTrue(meta.isGloballyWritable, @"gw should take");
        STAssertTrue(meta.isGloballyReadable, @"gr should take");
        self.done = YES;
    } withProgressBlock:nil];
    [self poll];
    
    self.done = NO;
    [KCSFileStore deleteFile:newFileId completionBlock:^(unsigned long count, NSError *errorOrNil) {
        STAssertNoError;
        self.done = YES;
    }];
    [self poll];
}

- (void) testLMTGetsUpdatedEvenIfNoMetadataChange
{
    self.done = NO;
    SETUP_PROGRESS
    __block NSString* newFileId = nil;
    __block KCSFile* origFile = nil;
    [KCSFileStore uploadData:testData() options:nil completionBlock:^(KCSFile *uploadInfo, NSError *error) {
        STAssertNoError_;
        origFile = uploadInfo;
        STAssertNotNil(uploadInfo, @"uploadInfo should be a real value");
        STAssertNotNil(uploadInfo.filename, @"filename should have faule");
        STAssertNotNil(uploadInfo.fileId, @"should have a file id");
        STAssertFalse([uploadInfo.fileId isEqualToString:uploadInfo.filename], @"file id should be unique");
        KTAssertEqualsInt(uploadInfo.length, testData().length, @"sizes should match");
        STAssertNil(uploadInfo.localURL, @"should be nil");
        STAssertNil(uploadInfo.remoteURL, @"should be nil");
        STAssertNil(uploadInfo.data, @"should have nil data");
        STAssertEqualObjects(uploadInfo.mimeType, @"application/octet-stream", @"should use default mimetype");
        
        newFileId = uploadInfo.fileId;
        self.done = YES;
    } progressBlock:PROGRESS_BLOCK];
    
    [self poll];
    ASSERT_PROGESS
    
    [NSThread sleepForTimeInterval:2];
    
    self.done = NO;
    [KCSFileStore uploadData:testData() options:@{KCSFileId : newFileId} completionBlock:^(KCSFile *uploadInfo, NSError *error) {
        STAssertNoError_;
        
        STAssertEqualObjects(uploadInfo.filename, origFile.filename, @"filenames should match");
        STAssertEquals(uploadInfo.length, origFile.length, @"lengths should match");
        STAssertEqualObjects(uploadInfo.mimeType, origFile.mimeType, @"types should match");
        STAssertFalse([uploadInfo.metadata.lastModifiedTime isEqualToDate:origFile.metadata.lastModifiedTime], @"lmts should not times match");
        STAssertTrue([uploadInfo.metadata.creationTime isEqualToDate:origFile.metadata.creationTime], @"ect times should match");
        self.done = YES;
    } progressBlock:nil];
    [self poll];
    
    if (newFileId) {
        self.done = NO;
        [KCSFileStore deleteFile:newFileId completionBlock:^(unsigned long count, NSError *errorOrNil) {
            STAssertNoError;
            self.done = YES;
        }];
        [self poll];
    }
}

- (void) testSaveDataBasic
{
    self.done = NO;
    SETUP_PROGRESS
    __block NSString* newFileId = nil;
    [KCSFileStore uploadData:testData() options:nil completionBlock:^(KCSFile *uploadInfo, NSError *error) {
        STAssertNoError_;
        STAssertNotNil(uploadInfo, @"uploadInfo should be a real value");
        STAssertNotNil(uploadInfo.filename, @"filename should have faule");
        STAssertNotNil(uploadInfo.fileId, @"should have a file id");
        STAssertFalse([uploadInfo.fileId isEqualToString:uploadInfo.filename], @"file id should be unique");
        KTAssertEqualsInt(uploadInfo.length, testData().length, @"sizes should match");
        STAssertNil(uploadInfo.localURL, @"should be nil");
        STAssertNil(uploadInfo.remoteURL, @"should be nil");
        STAssertNil(uploadInfo.data, @"should have nil data");
        STAssertEqualObjects(uploadInfo.mimeType, @"application/octet-stream", @"should use default mimetype");
        
        newFileId = uploadInfo.fileId;
        self.done = YES;
    } progressBlock:PROGRESS_BLOCK];
    
    [self poll];
    ASSERT_PROGESS
    
    if (newFileId) {
        self.done = NO;
        [KCSFileStore deleteFile:newFileId completionBlock:^(unsigned long count, NSError *errorOrNil) {
            STAssertNoError;
            self.done = YES;
        }];
        [self poll];
    }
}

- (void) testUploadDataPublic
{
    self.done = NO;
    SETUP_PROGRESS
    __block NSString* newFileId = nil;
    [KCSFileStore uploadData:testData() options:@{KCSFilePublic : @YES} completionBlock:^(KCSFile *uploadInfo, NSError *error) {
        STAssertNoError_;
        STAssertNotNil(uploadInfo, @"uploadInfo should be a real value");
        STAssertNotNil(uploadInfo.filename, @"filename should have faule");
        STAssertNotNil(uploadInfo.fileId, @"should have a file id");
        STAssertFalse([uploadInfo.fileId isEqualToString:uploadInfo.filename], @"file id should be unique");
        STAssertEqualObjects(uploadInfo.public, @(YES), @"should be public");
        
        KTAssertEqualsInt(uploadInfo.length, testData().length, @"sizes should match");
        STAssertNil(uploadInfo.localURL, @"should be nil");
        STAssertNil(uploadInfo.remoteURL, @"should be nil");
        STAssertNil(uploadInfo.data, @"should have nil data");
        STAssertEqualObjects(uploadInfo.mimeType, @"application/octet-stream", @"should use default mimetype");
        
        newFileId = uploadInfo.fileId;
        self.done = YES;
    } progressBlock:PROGRESS_BLOCK];
    
    [self poll];
    ASSERT_PROGESS
    STAssertNotNil(newFileId, @"Should get a file id");
    
    self.done = NO;
    [KCSFileStore getStreamingURL:newFileId options:@{KCSFileLinkExpirationTimeInterval : @1} completionBlock:^(KCSFile *streamingResource, NSError *error) {
        STAssertNoError_;
        NSURL* remoteURL = streamingResource.remoteURL;
        STAssertNotNil(remoteURL, @"should have a valid URL");
        
        NSLog(@"Sleeping for 10s to wait out the ttl");
        [NSThread sleepForTimeInterval:10];

        NSData* data = [NSData dataWithContentsOfURL:remoteURL];
        STAssertNotNil(data, @"should get back new data");
        STAssertEqualObjects(data, testData(), @"should get back our test data");
        self.done = YES;
    }];
    [self poll];
    
    self.done = NO;
    [KCSFileStore deleteFile:newFileId completionBlock:^(unsigned long count, NSError *errorOrNil) {
        STAssertNoError;
        self.done = YES;
    }];
    [self poll];
}

- (void) testUploadDataACL
{
    self.done = NO;
    SETUP_PROGRESS
    __block NSString* newFileId = nil;
    KCSMetadata* metadata =[[KCSMetadata alloc] init];
    [metadata setGloballyReadable:YES];
    [metadata setGloballyWritable:YES];
    [KCSFileStore uploadData:testData() options:@{KCSFileACL : metadata} completionBlock:^(KCSFile *uploadInfo, NSError *error) {
        STAssertNoError_;
        STAssertNotNil(uploadInfo, @"uploadInfo should be a real value");
        STAssertNotNil(uploadInfo.filename, @"filename should have faule");
        STAssertNotNil(uploadInfo.fileId, @"should have a file id");
        STAssertFalse([uploadInfo.fileId isEqualToString:uploadInfo.filename], @"file id should be unique");
        
        KCSMetadata* meta = uploadInfo.metadata;
        STAssertNotNil(meta, @"should not be nil");
        STAssertTrue(meta.isGloballyWritable, @"gw should take");
        STAssertTrue(meta.isGloballyReadable, @"gr should take");
        
        KTAssertEqualsInt(uploadInfo.length, testData().length, @"sizes should match");
        STAssertNil(uploadInfo.localURL, @"should be nil");
        STAssertNil(uploadInfo.remoteURL, @"should be nil");
        STAssertNil(uploadInfo.data, @"should have nil data");
        STAssertEqualObjects(uploadInfo.mimeType, @"application/octet-stream", @"should use default mimetype");
        
        newFileId = uploadInfo.fileId;
        self.done = YES;
    } progressBlock:PROGRESS_BLOCK];
    
    [self poll];
    ASSERT_PROGESS
    STAssertNotNil(newFileId, @"Should get a file id");
    
    self.done = NO;
    KCSAppdataStore* fileStore = [KCSAppdataStore storeWithCollection:[KCSCollection fileMetadataCollection] options:nil];
    [fileStore loadObjectWithID:newFileId withCompletionBlock:^(NSArray *objectsOrNil, NSError *errorOrNil) {
        STAssertNoError;
        STAssertObjects(1);
        KCSFile* file = objectsOrNil[0];
        KCSMetadata* meta = file.metadata;
        STAssertNotNil(meta, @"should not be nil");
        STAssertTrue(meta.isGloballyWritable, @"gw should take");
        STAssertTrue(meta.isGloballyReadable, @"gr should take");
        self.done = YES;
    } withProgressBlock:nil];
    [self poll];
    
    self.done = NO;
    [KCSFileStore deleteFile:newFileId completionBlock:^(unsigned long count, NSError *errorOrNil) {
        STAssertNoError;
        self.done = YES;
    }];
    [self poll];
}

//TODO: implement this
- (void) TODO_testUploadResume
{
    //1. Upload partial
    //2. Cancel
    //3. Upload rest
    //4. check # bytes written should be single total
    //5. dl file and check that the file size is correct.
    NSLog(@"---------------------- TEST START ------------------------");
    
    //1. Upload partial
    self.done = NO;
    __block double progress = 0.;
    __block NSString* fileId = nil;
    __block KCSFile* file = nil;
    [KCSFileStore uploadFile:[self largeImageURL] options:nil completionBlock:^(KCSFile *uploadInfo, NSError *error) {
        STAssertNotNil(uploadInfo, @"should still have this info");
        fileId = uploadInfo.fileId;
        file = uploadInfo;
        STAssertNotNil(fileId, @"should have a fileid");
        STAssertNotNil(error, @"should get an errror");
        
        self.done = YES;
    } progressBlock:^(NSArray *objects, double percentComplete) {
        progress = percentComplete;
    }];
    
    //2. Cancel    
    double delayInSeconds = 1.6;
    __block id lastRequest;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_current_queue(), ^(void){
        NSLog(@"cancelling...");
        lastRequest = [KCSFileStore lastRequest];
        STAssertNotNil(lastRequest, @"should have a request");
        [lastRequest cancel];
    });
    [self poll];

    STAssertTrue(progress > 0 && progress < 1., @"Should have had some but not all progress");
    unsigned long long firstWritten = [lastRequest bytesWritten];
    [NSThread sleepForTimeInterval:1];

    
    //3. Upload Rest
    self.done = NO;
    [KCSFileStore uploadKCSFile:file options:@{KCSFileResume : @(YES)} completionBlock:^(KCSFile *uploadInfo, NSError *error) {
        STAssertNoError_
        self.done = YES;
    } progressBlock:nil];
    [self poll];
    
    //4. check # bytes written should be single total
    lastRequest = [KCSFileStore lastRequest];
    unsigned long long totalBytes = firstWritten + [lastRequest bytesWritten];
    KTAssertEqualsInt(totalBytes, kImageSize, @"should have only written the total bytes");
    
    self.done = NO;
    [KCSFileStore uploadKCSFile:file options:@{KCSFileResume : @(YES)} completionBlock:^(KCSFile *uploadInfo, NSError *error) {
        STAssertNoError_
        self.done = YES;
    } progressBlock:nil];
    [self poll];
    
    //5. dl file and check that the file size is correct.
    self.done = NO;
    [KCSFileStore downloadData:fileId completionBlock:^(NSArray *downloadedResources, NSError *error) {
        STAssertNoError_;
        KCSFile* file = downloadedResources[0];
        NSData* d = file.data;
        KTAssertEqualsInt(d.length, kImageSize, @"should be full data");
        UIImage* image = [UIImage imageWithData:d];
        STAssertNotNil(image, @"should have a valid image");
        self.done = YES;
    } progressBlock:nil];
    [self poll];
    
    // Cleanup
    self.done = NO;
    [KCSFileStore deleteFile:fileId completionBlock:^(unsigned long count, NSError *errorOrNil) {
        STAssertNoError;
        self.done = YES;
    }];
    [self poll];
}

- (void) testStreamingUpload
{
    //TODO: try this out in the future
}

#pragma mark - Delete

- (void) testDelete
{
    self.done = NO;
    [KCSFileStore deleteFile:kTestId completionBlock:^(unsigned long count, NSError *errorOrNil) {
        STAssertNoError;
        KTAssertEqualsInt(count, 1, @"should have deleted one file");
        self.done = YES;
    }];
    [self poll];
    
    self.done = NO;
    [KCSFileStore downloadData:kTestId completionBlock:^(NSArray *downloadedResources, NSError *error) {
        STAssertNotNil(error, @"should get an error");
        STAssertEqualObjects(error.domain, KCSFileStoreErrorDomain, @"Should be a file error");
        KTAssertEqualsInt(error.code, KCSNotFoundError, @"should be a 404");
        self.done = YES;
    } progressBlock:nil];
    [self poll];
}

@end
