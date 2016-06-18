//
//  Metadata.swift
//  Kinvey
//
//  Created by Victor Barros on 2015-12-08.
//  Copyright © 2015 Kinvey. All rights reserved.
//

import Foundation
import Realm
import RealmSwift
import ObjectMapper

/// This class represents the metadata information for a record
public class Metadata: Object, Mappable {
    
    /// Last Modification Time Key.
    public static let LmtKey = "lmt"
    
    /// Entity Creation Time Key.
    public static let EctKey = "ect"
    
    /// Authentication Token Key.
    public static let AuthTokenKey = "authtoken"
    
    private dynamic var lmt: String?
    private dynamic var ect: String?
    
    /// Last Modification Time.
    public var lastModifiedtime: NSDate? {
        get {
            return self.lmt?.toDate()
        }
        set {
            lmt = newValue?.toString()
        }
    }
    
    /// Entity Creation Time.
    public var entityCreationTime: NSDate? {
        get {
            return self.ect?.toDate()
        }
        set {
            ect = newValue?.toString()
        }
    }
    
    /// Authentication Token.
    public internal(set) var authtoken: String?
    
    public required init?(_ map: Map) {
        super.init()
    }
    
    public required init() {
        super.init()
    }
    
    public required init(realm: RLMRealm, schema: RLMObjectSchema) {
        super.init(realm: realm, schema: schema)
    }
    
    public required init(value: AnyObject, schema: RLMSchema) {
        super.init(value: value, schema: schema)
    }
    
    public func mapping(map: Map) {
        lmt <- map[Metadata.LmtKey]
        ect <- map[Metadata.EctKey]
        authtoken <- map[Metadata.AuthTokenKey]
    }
    
    public override class func ignoredProperties() -> [String] {
        return ["lastModifiedtime", "entityCreationTime"]
    }

}
