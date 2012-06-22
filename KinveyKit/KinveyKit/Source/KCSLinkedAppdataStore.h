//
//  KCSLinkedAppdataStore.h
//  KinveyKit
//
//  Copyright (c) 2012 Kinvey. All rights reserved.
//

#import "KCSCachedStore.h"

/**
 This store will save linked resources to the backend when an entity is saved, and load such saved resources when an entity is fetched. **(This API is still in beta, please send us feedback)**. 
 
 To make use of this, have an entity map a `UIImage` property to the Kinvey dictionary in - [KCSPersistable hostToKinveyPropertyMapping], and save that entity. The associated image will be saved a a PNG blob in the backend and linked back to its entity, so that when the entity is loaded, the image will be fetched from the resource service.
 */
@interface KCSLinkedAppdataStore : KCSCachedStore

@end
