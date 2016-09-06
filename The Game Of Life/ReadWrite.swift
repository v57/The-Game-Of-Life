//
//  ReadWrite.swift
//  Life engine
//
//  Created by Dmitry Kozlov on 11/09/14.
//  Copyright (c) 2014 Dmitry Kozlov. All rights reserved.
//

import Foundation

class File {
    
    class func exists (path: String) -> Bool {
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as String
        let p = paths.stringByAppendingPathComponent(path)
        return NSFileManager().fileExistsAtPath(p)
    }
    
    class func read (path: String) -> String? {
        if File.exists(path) {
            var paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as String
            var p = paths.stringByAppendingPathComponent(path)
            return String(contentsOfFile: p, encoding: NSUTF8StringEncoding, error: nil)
        }
        
        return nil
    }
    
    class func write (path: String, content: String) -> Bool {
        var paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as String
        var p = paths.stringByAppendingPathComponent(path)
        return content.writeToFile(p, atomically: true, encoding: NSUTF8StringEncoding, error: nil)
    }
    class func readSysPlist(path: String) -> NSDictionary? {
        let p = NSBundle.mainBundle().pathForResource(path, ofType: "plist")
        return NSDictionary(contentsOfFile: p!)
    }
    class func readPlist(path: String) -> NSMutableDictionary? {
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as String
        let p = paths.stringByAppendingPathComponent(path + ".plist")
        return NSMutableDictionary(contentsOfFile: p)
    }
    class func writePlist(path: String, data: NSDictionary?) {
        var paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as String
        var p = paths.stringByAppendingPathComponent(path + ".plist")
        var fileManager = NSFileManager.defaultManager()
        if (!fileManager.fileExistsAtPath(p)) {
            fileManager.copyItemAtPath(path + ".plist", toPath: p, error:nil)
        }
        data?.writeToFile(p, atomically: true)
    }
    class func createDirectory(path: String) {
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as String
        let p = paths.stringByAppendingPathComponent(path)
        print("created \(p)")
        NSFileManager.defaultManager().createDirectoryAtPath(p, withIntermediateDirectories: true, attributes: nil, error: nil)
    }
}