//
//  DirectoryEntry.swift
//  Kinvey
//
//  Created by Victor Barros on 2016-04-19.
//  Copyright © 2016 Kinvey. All rights reserved.
//

import Foundation
import ObjectMapper
@testable import Kinvey

class DirectoryEntry: Entity {
    
    dynamic var uniqueId: String?
    dynamic var nameFirst: String?
    dynamic var nameLast: String?
    dynamic var email: String?
    
    dynamic var refProject: RefProject?
    
    override class func kinveyCollectionName() -> String {
        return "HelixProjectDirectory"
    }
    
    override func mapping(map: Map) {
        super.mapping(map)
        
        uniqueId <- map[PersistableIdKey]
        nameFirst <- map["nameFirst"]
        nameLast <- map["nameLast"]
        email <- map["email"]
    }
    
}
