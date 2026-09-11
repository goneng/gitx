//
//  PBGitRepositoryIgnoreTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitRepository.h"

// Names a .gitignore the test owns, so that ignoring a file needs no working
// directory and no libgit2 behind it.
@interface PBIgnoreStubRepository : PBGitRepository
@property (nonatomic, strong) NSString *ignoreFilename;
@end

@implementation PBIgnoreStubRepository

- (NSString *)gitIgnoreFilename
{
	return self.ignoreFilename;
}

@end

// Stands in for anything that can raise while the .gitignore is written.
@interface PBThrowingIgnoreRepository : PBIgnoreStubRepository
@end

@implementation PBThrowingIgnoreRepository

- (NSString *)gitIgnoreFilename
{
	[NSException raise:NSInternalInconsistencyException format:@"no working directory to write into"];

	return nil;
}

@end

@interface PBGitRepositoryIgnoreTests : XCTestCase
@property (nonatomic, strong) PBIgnoreStubRepository *repository;
@property (nonatomic, strong) NSURL *directory;
@end

@implementation PBGitRepositoryIgnoreTests

- (void)setUp
{
	[super setUp];

	self.directory = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]]];
	[[NSFileManager defaultManager] createDirectoryAtURL:self.directory
							withIntermediateDirectories:YES
											 attributes:nil
												  error:NULL];

	self.repository = [[PBIgnoreStubRepository alloc] init];
	self.repository.ignoreFilename = [self.directory URLByAppendingPathComponent:@".gitignore"].path;
}

- (void)tearDown
{
	[[NSFileManager defaultManager] removeItemAtURL:self.directory error:NULL];

	[super tearDown];
}

- (void)writeIgnoreFile:(NSString *)contents
{
	[contents writeToFile:self.repository.ignoreFilename atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

- (NSString *)ignoreFileContents
{
	return [NSString stringWithContentsOfFile:self.repository.ignoreFilename encoding:NSUTF8StringEncoding error:NULL];
}

- (BOOL)ignore:(NSArray<NSString *> *)paths
{
	NSError *error = nil;

	return [self.repository ignoreFilePaths:paths error:&error];
}

- (void)testTheFirstFileIgnoredWritesTheFile
{
	XCTAssertTrue([self ignore:@[ @"f1" ]]);

	XCTAssertEqualObjects([self ignoreFileContents], @"f1");
}

- (void)testASecondFileIsAddedToTheFileTheFirstOneLeftBehind
{
	XCTAssertTrue([self ignore:@[ @"f1" ]]);

	XCTAssertTrue([self ignore:@[ @"f2" ]], @"the second file has to be ignored just like the first");
	XCTAssertEqualObjects([self ignoreFileContents], @"f1\nf2");
}

- (void)testAFileAlreadyEndingInANewlineDoesNotGetASecondOne
{
	[self writeIgnoreFile:@"build/\n"];

	XCTAssertTrue([self ignore:@[ @"f1" ]]);

	XCTAssertEqualObjects([self ignoreFileContents], @"build/\nf1");
}

- (void)testAnEmptyFileIsWrittenWithoutALeadingNewline
{
	[self writeIgnoreFile:@""];

	XCTAssertTrue([self ignore:@[ @"f1" ]]);

	XCTAssertEqualObjects([self ignoreFileContents], @"f1");
}

- (void)testAFailureIsReportedRatherThanRaised
{
	PBThrowingIgnoreRepository *repository = [[PBThrowingIgnoreRepository alloc] init];
	NSError *error = nil;

	XCTAssertFalse([repository ignoreFilePaths:@[ @"f1" ] error:&error]);
	XCTAssertNotNil(error, @"the caller has an error sheet to show, if it is handed an error");
}

- (void)testEverySelectedFileGetsItsOwnLine
{
	[self writeIgnoreFile:@"build/"];

	XCTAssertTrue([self ignore:(@[ @"f1", @"f2" ])]);

	XCTAssertEqualObjects([self ignoreFileContents], @"build/\nf1\nf2");
}

@end
