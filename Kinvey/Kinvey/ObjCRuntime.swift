//
//  ObjCRuntime.swift
//  Kinvey
//
//  Created by Victor Barros on 2016-05-10.
//  Copyright © 2016 Kinvey. All rights reserved.
//

import Foundation
import ObjectiveC

@objc(__KNVObjCRuntime)
internal class ObjCRuntime: NSObject {
    
    private override init() {
    }
    
    internal class func type(target: AnyClass, isSubtypeOf cls: AnyClass) -> Bool {
        if target == cls {
            return true
        }
        
        if let superCls = class_getSuperclass(target) {
            return type(superCls, isSubtypeOf: cls)
        }
        return false
    }
    
    internal class func types(forType cls: AnyClass) -> [AnyClass] {
        var result = [AnyClass]()
        var classCount: UInt32 = 0
        let classList = objc_copyClassList(&classCount)
        for i in 0..<Int(classCount) {
            if let subCls = classList[i] where type(subCls, isSubtypeOf: cls) {
                result.append(subCls)
            }
        }
        return result
    }
    
    internal class func propertyNamesForTypeInClass(cls: AnyClass, type: AnyClass) -> [String]? {
        var propertyNames = [String]()
        let regexClassName = try! NSRegularExpression(pattern: "@\"(\\w+)(?:<(\\w+)>)?\"", options: [])
        var propertyCount = UInt32(0)
        let properties = class_copyPropertyList(cls, &propertyCount)
        defer { free(properties) }
        for i in UInt32(0) ..< propertyCount {
            let property = properties[Int(i)]
            if let propertyName = String.fromCString(property_getName(property)) {
                var attributeCount = UInt32(0)
                let attributes = property_copyAttributeList(property, &attributeCount)
                defer { free(attributes) }
                for x in UInt32(0) ..< attributeCount {
                    let attribute = attributes[Int(x)]
                    if let attributeName = String.fromCString(attribute.name) where attributeName == "T",
                        let attributeValue = String.fromCString(attribute.value),
                        let textCheckingResult = regexClassName.matchesInString(attributeValue, options: [], range: NSMakeRange(0, attributeValue.characters.count)).first
                    {
                        let attributeValueNSString = attributeValue as NSString
                        let propertyTypeName = attributeValueNSString.substringWithRange(textCheckingResult.rangeAtIndex(1))
                        if let propertyTypeNameClass = NSClassFromString(propertyTypeName) where propertyTypeNameClass == type {
                            propertyNames.append(propertyName)
                        }
                    }
                }
            }
        }
        return propertyNames.isEmpty ? nil : propertyNames
    }
    
    internal class func typeForPropertyName(cls: AnyClass, propertyName: String) -> AnyClass? {
        let regexClassName = try! NSRegularExpression(pattern: "@\"(\\w+)(?:<(\\w+)>)?\"", options: [])
        
        let property = class_getProperty(cls, propertyName)
        let attributeValueCString = property_copyAttributeValue(property, "T")
        defer { free(attributeValueCString) }
        if let attributeValue = String.fromCString(attributeValueCString),
            let textCheckingResult = regexClassName.matchesInString(attributeValue, options: [], range: NSMakeRange(0, attributeValue.characters.count)).first
        {
            let attributeValueNSString = attributeValue as NSString
            let propertyTypeName = attributeValueNSString.substringWithRange(textCheckingResult.rangeAtIndex(1))
            return NSClassFromString(propertyTypeName)
        }
        return nil
    }
    
    internal class func properties(cls: AnyClass) -> [String : AnyClass] {
        let regexClassName = try! NSRegularExpression(pattern: "@\"(\\w+)(?:<(\\w+)>)?\"", options: [])
        var cls: AnyClass? = cls
        var results = [String : AnyClass]()
        while cls != nil {
            var propertyCount = UInt32(0)
            let properties = class_copyPropertyList(cls, &propertyCount)
            defer { free(properties) }
            for i in UInt32(0) ..< propertyCount {
                let property = properties[Int(i)]
                if let propertyName = String.fromCString(property_getName(property))
                {
                    var attributeCount = UInt32(0)
                    let attributes = property_copyAttributeList(property, &attributeCount)
                    defer { free(attributes) }
                    for x in UInt32(0) ..< attributeCount {
                        let attribute = attributes[Int(x)]
                        if let attributeName = String.fromCString(attribute.name) where attributeName == "T",
                            let attributeValue = String.fromCString(attribute.value),
                            let textCheckingResult = regexClassName.matchesInString(attributeValue, options: [], range: NSMakeRange(0, attributeValue.characters.count)).first
                        {
                            let attributeValueNSString = attributeValue as NSString
                            let propertyTypeName = attributeValueNSString.substringWithRange(textCheckingResult.rangeAtIndex(1))
                            if let propertyTypeNameClass = NSClassFromString(propertyTypeName) {
                                results[propertyName] = propertyTypeNameClass
                                break
                            }
                        }
                    }
                }
            }
            if cls == Entity.self {
                cls = nil
            } else {
                cls = class_getSuperclass(cls)
            }
        }
        return results
    }
    
    internal class func propertyNames(cls: AnyClass) -> [String] {
        let regexClassName = try! NSRegularExpression(pattern: "@\"(\\w+)(?:<(\\w+)>)?\"", options: [])
        var cls: AnyClass? = cls
        var results = [String]()
        while cls != nil {
            var propertyCount = UInt32(0)
            let properties = class_copyPropertyList(cls, &propertyCount)
            defer { free(properties) }
            for i in UInt32(0) ..< propertyCount {
                let property = properties[Int(i)]
                if let propertyName = String.fromCString(property_getName(property))
                {
                    results.append(propertyName)
                }
            }
            if cls == Entity.self {
                cls = nil
            } else {
                cls = class_getSuperclass(cls)
            }
        }
        return results
    }
    
    internal class func propertyDefaultValues(cls: AnyClass) -> [String : AnyObject] {
        let regexClassName = try! NSRegularExpression(pattern: "@\"(\\w+)(?:<(\\w+)>)?\"", options: [])
        var cls: AnyClass? = cls
        var results = [String : AnyObject]()
        while cls != nil {
            var propertyCount = UInt32(0)
            let properties = class_copyPropertyList(cls, &propertyCount)
            defer { free(properties) }
            for i in UInt32(0) ..< propertyCount {
                let property = properties[Int(i)]
                if let propertyName = String.fromCString(property_getName(property))
                {
                    var attributeCount = UInt32(0)
                    let attributes = property_copyAttributeList(property, &attributeCount)
                    defer { free(attributes) }
                    for x in UInt32(0) ..< attributeCount {
                        let attribute = attributes[Int(x)]
                        if let attributeName = String.fromCString(attribute.name) where attributeName == "T",
                            let attributeValue = String.fromCString(attribute.value)
                        {
                            if let textCheckingResult = regexClassName.matchesInString(attributeValue, options: [], range: NSMakeRange(0, attributeValue.characters.count)).first {
                                let attributeValueNSString = attributeValue as NSString
                                let propertyTypeName = attributeValueNSString.substringWithRange(textCheckingResult.rangeAtIndex(1))
                                if let propertyTypeNameClass = NSClassFromString(propertyTypeName) {
                                    results[propertyName] = (propertyTypeNameClass as! NSObject.Type).init()
                                    break
                                }
                            } else if attributeValue.characters.count > 0 {
                                switch attributeValue.characters.first! {
                                case "q":
                                    results[propertyName] = Int(0)
                                    break
                                default:
                                    break
                                }
                            }
                        }
                    }
                }
            }
            if cls == Entity.self {
                cls = nil
            } else {
                cls = class_getSuperclass(cls)
            }
        }
        return results
    }
    
}