//
//  GetOperationTest.swift
//  Kinvey
//
//  Created by Victor Barros on 2016-02-15.
//  Copyright © 2016 Kinvey. All rights reserved.
//

import XCTest

class GetOperationTest: StoreTestCase {
    
    func testForceNetwork() {
        weak var expectationSave = expectationWithDescription("Save")
        
        store.save(person, writePolicy: .ForceNetwork) { (person, error) -> Void in
            XCTAssertNotNil(person)
            XCTAssertNil(error)
            
            if let person = person {
                XCTAssertEqual(person, self.person)
                XCTAssertNotNil(person.personId)
            }
            
            expectationSave?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationSave = nil
        }
        
        XCTAssertNotNil(person.personId)
        if let personId = person.personId {
            weak var expectationGet = expectationWithDescription("Get")
            
            store.findById(personId, readPolicy: .ForceNetwork) { (person, error) -> Void in
                XCTAssertNotNil(person)
                XCTAssertNil(error)
                
                expectationGet?.fulfill()
            }
            
            waitForExpectationsWithTimeout(defaultTimeout) { error in
                expectationGet = nil
            }
        }
    }
    
    func testForceLocal() {
        weak var expectationSave = expectationWithDescription("Save")
        
        store.save(person, writePolicy: .ForceLocal) { (person, error) -> Void in
            XCTAssertNotNil(person)
            XCTAssertNil(error)
            
            if let person = person {
                XCTAssertEqual(person, self.person)
                XCTAssertNotNil(person.personId)
            }
            
            expectationSave?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationSave = nil
        }
        
        XCTAssertNotNil(person.personId)
        if let personId = person.personId {
            weak var expectationGet = expectationWithDescription("Get")
            
            store.findById(personId, readPolicy: .ForceLocal) { (person, error) -> Void in
                XCTAssertNotNil(person)
                XCTAssertNil(error)
                
                expectationGet?.fulfill()
            }
            
            waitForExpectationsWithTimeout(defaultTimeout) { error in
                expectationGet = nil
            }
        }
    }
    
    func testBoth() {
        weak var expectationSaveLocal = expectationWithDescription("SaveLocal")
        weak var expectationSaveNetwork = expectationWithDescription("SaveNetwork")
        
        var isLocal = true
        
        store.save(person, writePolicy: .LocalThenNetwork) { (person, error) -> Void in
            XCTAssertNotNil(person)
            XCTAssertNil(error)
            
            if let person = person {
                XCTAssertEqual(person, self.person)
                XCTAssertNotNil(person.personId)
            }
            
            if isLocal {
                expectationSaveLocal?.fulfill()
                isLocal = false
            } else {
                expectationSaveNetwork?.fulfill()
            }
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationSaveLocal = nil
            expectationSaveNetwork = nil
        }
        
        XCTAssertNotNil(person.personId)
        if let personId = person.personId {
            weak var expectationGetLocal = expectationWithDescription("GetLocal")
            weak var expectationGetNetwork = expectationWithDescription("GetNetwork")
            
            var isLocal = true
            
            store.findById(personId, readPolicy: .Both) { (person, error) -> Void in
                XCTAssertNotNil(person)
                XCTAssertNil(error)
                
                if isLocal {
                    expectationGetLocal?.fulfill()
                    isLocal = false
                } else {
                    expectationGetNetwork?.fulfill()
                }
            }
            
            waitForExpectationsWithTimeout(defaultTimeout) { error in
                expectationGetLocal = nil
                expectationGetNetwork = nil
            }
        }
    }
    
}
