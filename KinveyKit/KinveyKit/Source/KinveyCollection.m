//
//  KinveyCollection.m
//  KinveyKit
//
//  Created by Brian Wilson on 10/13/11.
//  Copyright (c) 2011 Kinvey. All rights reserved.
//

#import "KinveyPersistable.h"
#import "KinveyCollection.h"
#import "KCSClient.h"
#import "NSString+KinveyAdditions.h"
#import "JSONKit.h"
#import "KCSRESTRequest.h"
#import "KinveyHTTPStatusCodes.h"
#import "KCSConnectionResponse.h"
#import "KinveyErrorCodes.h"
#import "KCSErrorUtilities.h"
#import "KCSLogManager.h"


// Avoid compiler warning by prototyping here...
KCSConnectionCompletionBlock makeCollectionCompletionBlock(KCSCollection *collection, id<KCSCollectionDelegate>delegate);
KCSConnectionFailureBlock    makeCollectionFailureBlock(KCSCollection *collection, id<KCSCollectionDelegate>delegate);
KCSConnectionProgressBlock   makeCollectionProgressBlock(KCSCollection *collection, id<KCSCollectionDelegate>delegate);

KCSConnectionCompletionBlock makeCollectionCompletionBlock(KCSCollection *collection, id<KCSCollectionDelegate>delegate)
{
    return [[^(KCSConnectionResponse *response){
        
        KCSLogTrace(@"In collection callback with response: %@", response);
        
        // See if the class has a function map
        Class templateClass = collection.objectTemplate;
        NSDictionary *specialOptions = [templateClass kinveyObjectBuilderOptions];
        BOOL hasDesignatedInit = NO;
        BOOL hasFlatMap = NO;
        
        if (specialOptions != nil){
            if ([specialOptions objectForKey:KCS_USE_DESIGNATED_INITIALIZER_MAPPING_KEY] != nil){
                hasDesignatedInit = YES;
            }
            
            if ([specialOptions objectForKey:KCS_USE_DICTIONARY_KEY]){
                hasFlatMap = YES;
            }
        }
        
        id templateClassObject = nil;
        
        if (hasDesignatedInit){
            // We need to retain this to get a known +1 on the refcount to match below
            templateClassObject = [[templateClass kinveyDesignatedInitializer] retain];
        } else {
            templateClassObject = [[templateClass alloc] init];
        }
        
        NSDictionary *hostToJsonMap = [templateClassObject hostToKinveyPropertyMapping];
        [templateClassObject release];
        templateClassObject = nil;
        
        NSMutableArray *processedData = [[NSMutableArray alloc] init];
        
        
        // New KCS behavior, not ready yet
#if 0
        NSDictionary *jsonResponse = [response.responseData objectFromJSONData];
        NSObject *jsonData = [jsonResponse valueForKey:@"result"];
#else  
        NSObject *jsonData = [response.responseData objectFromJSONData];
#endif        
        NSArray *jsonArray;
        if (response.responseCode != KCS_HTTP_STATUS_OK){
            NSDictionary *userInfo = [KCSErrorUtilities createErrorUserDictionaryWithDescription:@"Collection fetch was unsuccessful."
                                                                               withFailureReason:[NSString stringWithFormat:@"JSON Error: %@", jsonData]
                                                                          withRecoverySuggestion:@"Retry request based on information in JSON Error"
                                                                             withRecoveryOptions:nil];
            NSError *error = [NSError errorWithDomain:KCSAppDataErrorDomain
                                                 code:[response responseCode]
                                             userInfo:userInfo];
            
            [delegate collection:collection didFailWithError:error];

            [processedData release];
            return;
        }
        
        if ([jsonData isKindOfClass:[NSArray class]]){
            jsonArray = (NSArray *)jsonData;
        } else {
            if ([(NSDictionary *)jsonData count] == 0){
                jsonArray = [NSArray array];
            } else {
                jsonArray = [NSArray arrayWithObjects:(NSDictionary *)jsonData, nil];
            }
        }
        
        for (NSDictionary *dict in jsonArray) {
            
            id copiedObject = nil;
            if (hasDesignatedInit){
                copiedObject = [templateClass kinveyDesignatedInitializer];
            } else {
                copiedObject = [[[templateClass alloc] init] autorelease];
            }
            
            for (NSString *hostKey in hostToJsonMap) {
                NSString *jsonKey = [hostToJsonMap objectForKey:hostKey];
                
                //            KCSLogDebug(@"Mapping from %@ to %@ (using value: %@)", jsonKey, hostKey, [dict valueForKey:jsonKey]);
                if ([dict valueForKey:jsonKey] == nil){
                    KCSLogWarning(@"Data Mismatch, unable to find value for JSON Key %@ (Host Key %@).  Object not 100%% valid.", jsonKey, hostKey);
                    continue;
                }
                [copiedObject setValue:[dict valueForKey:jsonKey] forKey:hostKey];
                //            KCSLogDebug(@"Copied Object: %@", copiedObject);
            }
            
            // We've processed all the known keys, let's put the rest in our "dictionary" if required
            if (hasFlatMap){
                NSString *dictName = [specialOptions objectForKey:KCS_DICTIONARY_NAME_KEY];
                if (dictName){
                    NSArray *knownJsonProps = [hostToJsonMap allValues];
                    for (NSString *property in dict) {
                        // Check if in known set
                        if ([knownJsonProps containsObject:property]){
                            continue;
                        } else {
                            // otherwise build key path and insert.
                            NSString *keyPath = [dictName stringByAppendingFormat:@".%@", property];
                            [copiedObject setValue:[dict objectForKey:property] forKeyPath:keyPath];
                        }
                    }
                }
            }
            
            [processedData addObject:copiedObject];
        }
        [delegate collection:collection didCompleteWithResult:processedData];
        [processedData release];
    } copy] autorelease];
}

KCSConnectionFailureBlock    makeCollectionFailureBlock(KCSCollection *collection, id<KCSCollectionDelegate>delegate)
{
    return [[^(NSError *error){
        [delegate collection:collection didFailWithError:error];
    } copy] autorelease];
}
KCSConnectionProgressBlock   makeCollectionProgressBlock(KCSCollection *collection, id<KCSCollectionDelegate>delegate)
{
    
    return [[^(KCSConnectionProgress *conn)
    {
        // Do nothing...
    } copy] autorelease];
    
}




@implementation KCSCollection

// Usage concept
// In controller
// self.objectCollection = [[KCSCollection alloc] init];
// self.objectCollection.collectionName = @"lists";
// self.objectColleciton.objectTemplate = [[MyObject alloc] init];
// self.objectCollection.kinveyConnection = [globalConnection];
//
// And later...
// [self.objectCollection collectionDelegateFetchAll: ()

@synthesize collectionName=_collectionName;
@synthesize objectTemplate=_objectTemplate;
@synthesize lastFetchResults=_lastFetchResults;
@synthesize filters=_filters;
@synthesize baseURL = _baseURL;

// TODO: Need a way to store the query portion of the library.

- (id)initWithName: (NSString *)name forTemplateClass: (Class) theClass
{
    self = [super init];
    
    if (self){
        _collectionName = name;
        _objectTemplate = theClass;
        _lastFetchResults = nil;
        _baseURL = [[KCSClient sharedClient] appdataBaseURL]; // Initialize this to the default appdata URL
        _filters = [[NSMutableArray alloc] init];      
    }
    
    return self;
}


- (id)init
{
    return [self initWithName:nil forTemplateClass:[NSObject class]];
}

- (void)dealloc
{
    [_filters release];
    [_lastFetchResults release];
    [_collectionName release];
}

// Override isEqual method to allow comparing of Collections
// A collection is equal if the name, object template and filter are the same
- (BOOL) isEqual:(id)object
{
    KCSCollection *c = (KCSCollection *)object;
    
    if (![object isKindOfClass:[self class]]){
        return NO;
    }
    
    if (![self.collectionName isEqualToString:c.collectionName]){
        return NO;
    }
    
    if (![c.objectTemplate isEqual:c.objectTemplate]){
        return NO;
    }
    
    if (![self.filters isEqualToArray:c.filters]){
        return NO;
    }
    
    return YES;
}



+ (KCSCollection *)collectionFromString: (NSString *)string ofClass: (Class)templateClass
{
    KCSCollection *collection = [[[KCSCollection alloc] initWithName:string forTemplateClass:templateClass] autorelease];
    return collection;
}



#pragma mark Basic Methods

- (void)fetchAllWithDelegate:(id<KCSCollectionDelegate>)delegate
{
    NSString *resource = [self.baseURL stringByAppendingFormat:@"%@/", self.collectionName];
    KCSRESTRequest *request = [KCSRESTRequest requestForResource:resource usingMethod:kGetRESTMethod];

    KCSConnectionCompletionBlock cBlock = makeCollectionCompletionBlock(self, delegate);
    KCSConnectionFailureBlock fBlock = makeCollectionFailureBlock(self, delegate);
    KCSConnectionProgressBlock pBlock = makeCollectionProgressBlock(self, delegate);
    
    // Make the request happen
    [[request withCompletionAction:cBlock failureAction:fBlock progressAction:pBlock] start];
}

// Private class helper method...
+ (NSString *)getOperatorString: (int)op
{
    switch (op) {
        case KCS_EQUALS_OPERATOR:
            return nil;
            break;
        case KCS_LESS_THAN_OPERATOR:
            return @"$lt";
            break;
        case KCS_GREATER_THAN_OPERATOR:
            return @"$gt";
            break;
        case KCS_LESS_THAN_OR_EQUAL_OPERATOR:
            return @"$lte";
            break;
        case KCS_GREATER_THAN_OR_EQUAL_OPERATOR:
            return @"$gte";
            break;
            
        default:
            return nil;
            break;
    }
}

- (NSString *)buildQueryForProperty: (NSString *)property withValue: (id)value filteredByOperator: (int)op
{
    NSString *query;
    
    NSString *stringValue;
    
    // Check to see if the object is a string or a real object
    // surround strings with quotes, values without
    if ([value isKindOfClass:[NSString class]]){
        stringValue = [NSString stringWithFormat:@"\"%@\"", value];
    } else {
        stringValue = [NSString stringWithFormat:@"%@", value];
    }
    
    if (op == KCS_EQUALS_OPERATOR){
        query = [NSString stringWithFormat:@"\"%@\": %@", property, stringValue];
    } else {
        query = [NSString stringWithFormat:@"\"%@\": {\"%@\": %@}", property, [KCSCollection getOperatorString:op], stringValue];
    }
    return query;
    
}

- (NSString *)buildQueryForFilters: (NSArray *)filters
{
    NSString *outputString = @"{";
    for (NSString *filter in filters) {
        outputString = [outputString stringByAppendingFormat:@"%@, ", filter];
    }
    
    // String the trailing ','
    if ([outputString characterAtIndex:[outputString length]-2] == ','){
        outputString = [outputString substringToIndex:[outputString length] -2];
    }
    
    return [outputString stringByAppendingString:@"}"];
}


#pragma mark Query Methods
- (void)addFilterCriteriaForProperty: (NSString *)property withBoolValue: (BOOL) value filteredByOperator: (int)operator
{
    [[self filters] addObject:[self buildQueryForProperty:property withValue:[NSNumber numberWithBool:value] filteredByOperator:operator]];
}

- (void)addFilterCriteriaForProperty: (NSString *)property withDoubleValue: (double)value filteredByOperator: (int)operator
{
    [[self filters] addObject:[self buildQueryForProperty:property withValue:[NSNumber numberWithBool:value] filteredByOperator:operator]];
	
}

- (void)addFilterCriteriaForProperty: (NSString *)property withIntegerValue: (int)value filteredByOperator: (int)operator
{
    [[self filters] addObject:[self buildQueryForProperty:property withValue:[NSNumber numberWithBool:value] filteredByOperator:operator]];
	
}

- (void)addFilterCriteriaForProperty: (NSString *)property withStringValue: (NSString *)value filteredByOperator: (int)operator
{
    [[self filters] addObject:[self buildQueryForProperty:property withValue:value filteredByOperator:operator]];
	
}

- (void)resetFilterCriteria
{
    [self.filters removeAllObjects];
}

- (void)fetchWithDelegate:(id<KCSCollectionDelegate>)delegate
{
    // Guard against an empty filter
    if (self.filters.count == 0){
        NSException* myException = [NSException
                                    exceptionWithName:NSInvalidArgumentException
                                    reason:@"Attempt to fetch from a Kinvey Collection with an empty filter, use fetchAll instead."
                                    userInfo:nil];
        
        @throw myException;
    }
    
    NSString *resource = [self.baseURL stringByAppendingFormat:@"%@/?query=%@",
                             self.collectionName, [NSString stringbyPercentEncodingString:[self buildQueryForFilters:[self filters]]]];

    KCSRESTRequest *request = [KCSRESTRequest requestForResource:resource usingMethod:kGetRESTMethod];
    
    
    KCSConnectionCompletionBlock cBlock = makeCollectionCompletionBlock(self, delegate);
    KCSConnectionFailureBlock fBlock = makeCollectionFailureBlock(self, delegate);
    KCSConnectionProgressBlock pBlock = makeCollectionProgressBlock(self, delegate);
    
    // Make the request happen
    [[request withCompletionAction:cBlock failureAction:fBlock progressAction:pBlock] start];
}

#pragma mark Utility Methods

- (void)entityCountWithDelegate:(id<KCSInformationDelegate>)delegate
{
    NSString *resource = [self.baseURL stringByAppendingFormat:@"%@/%@", _collectionName, @"_count"];
    KCSRESTRequest *request = [KCSRESTRequest requestForResource:resource usingMethod:kGetRESTMethod];
    
    KCSConnectionCompletionBlock cBlock = ^(KCSConnectionResponse *response){
        NSDictionary *jsonResponse = [response.responseData objectFromJSONData];
#if 0
        // Needs KCS update for this feature
        NSDictionary *responseToReturn = [jsonResponse valueForKey:@"result"];
#else
        NSDictionary *responseToReturn = jsonResponse;
#endif
        int count;

        if (response.responseCode != KCS_HTTP_STATUS_OK){
            NSDictionary *userInfo = [KCSErrorUtilities createErrorUserDictionaryWithDescription:@"Information request was unsuccessful."
                                                                               withFailureReason:[NSString stringWithFormat:@"JSON Error: %@", responseToReturn]
                                                                          withRecoverySuggestion:@"Retry request based on information in JSON Error"
                                                                             withRecoveryOptions:nil];
            NSError *error = [NSError errorWithDomain:KCSAppDataErrorDomain
                                                 code:[response responseCode]
                                             userInfo:userInfo];
            
            [delegate collection:self informationOperationFailedWithError:error];
            return;
        }

        NSString *val = [responseToReturn valueForKey:@"count"];
        
        if (val){
            count = [val intValue];
        } else {
            count = 0;
        }
        [delegate collection:self informationOperationDidCompleteWithResult:count];
    };
    
    KCSConnectionFailureBlock fBlock = ^(NSError *error){
        [delegate collection:self informationOperationFailedWithError:error];
    };
    
    KCSConnectionProgressBlock pBlock = ^(KCSConnectionProgress *collection) {};
        
    // Make the request happen
    [[request withCompletionAction:cBlock failureAction:fBlock progressAction:pBlock] start];
}

// AVG is not in the REST docs anymore


@end