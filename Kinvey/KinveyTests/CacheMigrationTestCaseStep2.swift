//
//  CacheMigrationTestCase.swift
//  Kinvey
//
//  Created by Victor Barros on 2016-03-22.
//  Copyright © 2016 Kinvey. All rights reserved.
//

import XCTest
import ObjectiveC
import RealmSwift
@testable import Kinvey

class Person: Entity {
    
    dynamic var personId: String?
    dynamic var fullName: String?
    
    override class func collectionName() -> String {
        return "CacheMigrationTestCase_Person"
    }
    
    override func propertyMapping(map: Map) {
        super.propertyMapping(map)
        
        personId <- map[PersistableIdKey]
        fullName <- map["fullName"]
    }
    
}

class CacheMigrationTestCaseStep2: XCTestCase {
    
    let defaultTimeout = KinveyTestCase.defaultTimeout
    
    override func tearDown() {
        let realmConfiguration = Realm.Configuration.defaultConfiguration
        if let fileURL = realmConfiguration.fileURL, var path = fileURL.path {
            var pathComponents = (path as NSString).pathComponents
            pathComponents[pathComponents.count - 1] = "com.kinvey.appKey_cache.realm"
            path = NSString.pathWithComponents(pathComponents)
            let fileManager = NSFileManager.defaultManager()
            if fileManager.fileExistsAtPath(path) {
                do {
                    try fileManager.removeItemAtPath(path)
                } catch {
                    XCTFail()
                    return
                }
            }
        }
    }
    
    func testMigration() {
        var migrationCalled = false
        var migrationPersonCalled = false
        
        Kinvey.sharedClient.initialize(appKey: "appKey", appSecret: "appSecret", schemaVersion: 2) { migration, oldSchemaVersion in
            migrationCalled = true
            migration.execute(Person.self) { (oldEntity) in
                migrationPersonCalled = true
                
                var newEntity = oldEntity
                if oldSchemaVersion < 2 {
                    newEntity["fullName"] = "\(oldEntity["firstName"]!) \(oldEntity["lastName"]!)"
                    newEntity.removeValueForKey("firstName")
                    newEntity.removeValueForKey("lastName")
                }
                
                return newEntity
            }
        }
        
        XCTAssertTrue(migrationCalled)
        XCTAssertTrue(migrationPersonCalled)
        
        let store = DataStore<Person>.collection(.Sync)
        
        weak var expectationFind = expectationWithDescription("Find")
        
        store.find { persons, error in
            XCTAssertNotNil(persons)
            XCTAssertNil(error)
            
            if let persons = persons {
                XCTAssertEqual(persons.count, 1)
                
                if let person = persons.first {
                    XCTAssertEqual(person.fullName, "Victor Barros")
                }
            }
            
            expectationFind?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationFind = nil
        }
    }
    
}