//
//  Loggly.swift
//  SwiftLoggly
//
//  Created by Vignesh on 30/01/17.
//  Copyright © 2017 vigneshuvi. All rights reserved.
//

import Foundation


extension String {
    var length: Int {
        return self.characters.count
    }
}

extension Dictionary {
    var jsonString: String {
        let invalidJson = "Not a valid JSON"
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: self, options: .prettyPrinted)
            return String(bytes: jsonData, encoding: String.Encoding.utf8) ?? invalidJson
        } catch {
            return invalidJson
        }
    }
    
    func printJson() {
        print(jsonString)
    }
}


extension NSDictionary {
    var jsonString: String {
        let invalidJson = "Not a valid JSON"
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: self, options: .prettyPrinted)
            return String(bytes: jsonData, encoding: String.Encoding.utf8) ?? invalidJson
        } catch {
            return invalidJson
        }
    }
    
    func printJson() {
        print(jsonString)
    }
}

// Struct for Color Log
struct ColorLog {
    static let ESCAPE = "\u{001b}["
    
    static let RESET_FG = ESCAPE + "fg;" // Clear any foreground color
    static let RESET_BG = ESCAPE + "bg;" // Clear any background color
    static let RESET = ESCAPE + ";"   // Clear any foreground or background color
    
    static func red<T>(object: T) {
        print("\(ESCAPE)fg255,0,0;\(object)\(RESET)", terminator: "")
    }
    
    static func green<T>(object: T) {
        print("\(ESCAPE)fg0,255,0;\(object)\(RESET)", terminator: "")
    }
    
    static func blue<T>(object: T) {
        print("\(ESCAPE)fg0,0,255;\(object)\(RESET)", terminator: "")
    }
}

// Public Enumaration for log type
public enum LogType {
    case LogInfo
    case LogError
    case LogWarn
}

open class Loggly {

    ///The max size a log file can be in Kilobytes. Default is 1024 (1 MB)
    open var maxFileSize: UInt64 = 1024;
    
    ///The max number of log file that will be stored. Once this point is reached, the oldest file is deleted.
    open var maxFileCount = 4;
    
    ///The directory in which the log files will be written
    open var directory = Loggly.defaultDirectory();
    
    //The name of the log files.
    open var name = "logglyfile";
    
    //The date format of the log time.
    open var logDateFormat = "";
    
    ///logging singleton
    open class var logger: Loggly {
        
        struct Static {
            static let instance: Loggly = Loggly()
        }
        return Static.instance
    }
    
    //the date formatter
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        if !logDateFormat.isEmpty && logDateFormat.length > 0 {
            formatter.dateFormat = "MMMM dd yyyy"
        } else {
            formatter.timeStyle = .medium
            formatter.dateStyle = .medium
        }
        return formatter
    }
    
    ///gets the log type with String
    func logTypeName(_ type: LogType) -> String {
        var logTypeStr = "";
        switch type {
        case .LogInfo:
           logTypeStr = "Info - "
        case .LogWarn:
             logTypeStr = "Warn - "
        case .LogError:
             logTypeStr = "Error - "
        }
        return logTypeStr;
    }
    
    /// Prints the log type with String and type color code.
    func printLog(_ type: LogType, text:String) {
        switch type {
        case .LogInfo:
            ColorLog.blue(object: text)
        case .LogWarn:
            ColorLog.blue(object: text)
        case .LogError:
            ColorLog.red(object: text)
        }
    }
    
    ///write content to the current log file.
    open func write(_ type: LogType, text: String) {
        let path = "\(directory)/\(logName(0))"
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: path) {
            do {
                try "".write(toFile: path, atomically: true, encoding: String.Encoding.utf8)
            } catch _ {
            }
        }
        if let fileHandle = FileHandle(forWritingAtPath: path) {
            let dateStr = dateFormatter.string(from: Date())
            let writeText = "[\(logTypeName(type)) \(dateStr)]: \(text)\n"
            fileHandle.seekToEndOfFile()
            fileHandle.write(writeText.data(using: String.Encoding.utf8)!)
            fileHandle.closeFile()
            printLog(type, text: text)
            cleanup()
        }
    }
    
    ///do the checks and cleanup
    func cleanup() {
        let path = "\(directory)/\(logName(0))"
        let size = fileSize(path)
        let maxSize: UInt64 = maxFileSize*1024
        if size > 0 && size >= maxSize && maxSize > 0 && maxFileCount > 0 {
            rename(0)
            //delete the oldest file
            let deletePath = "\(directory)/\(logName(maxFileCount))"
            let fileManager = FileManager.default
            do {
                try fileManager.removeItem(atPath: deletePath)
            } catch _ {
            }
        }
    }
    
    ///check the size of a file
    func fileSize(_ path: String) -> UInt64 {
        let fileManager = FileManager.default
        let attrs: NSDictionary? = try! fileManager.attributesOfItem(atPath: path) as NSDictionary?
        if let dict = attrs {
            return dict.fileSize()
        }
        return 0
    }
    
    ///Recursive method call to rename log files
    func rename(_ index: Int) {
        let fileManager = FileManager.default
        let path = "\(directory)/\(logName(index))"
        let newPath = "\(directory)/\(logName(index+1))"
        if fileManager.fileExists(atPath: newPath) {
            rename(index+1)
        }
        do {
            try fileManager.moveItem(atPath: path, toPath: newPath)
        } catch _ {
        }
    }
    
    ///gets the log name
    func logName(_ num :Int) -> String {
        return "\(name)-\(num).log"
    }
    
    ///get the default log directory
    class func defaultDirectory() -> String {
        var path = ""
        let fileManager = FileManager.default
        #if os(iOS)
            let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
            path = "\(paths[0])/Logs"
        #elseif os(OSX)
            let urls = fileManager.urls(for: .libraryDirectory, in: .userDomainMask)
            if let url = urls.last?.path {
                path = "\(url)/Logs"
            }
        #endif
        if !fileManager.fileExists(atPath: path) && path != ""  {
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
            } catch _ {
            }
        }
        return path
    }
    
}

///a free function to make writing to the log with Log type
public func loggly(_ type: LogType, text: String) {
    Loggly.logger.write(type, text: text)
}

///a free function to make writing to the log with Log type
public func loggly(_ type: LogType, dictionary: Dictionary<AnyHashable, Any>) {
    Loggly.logger.write(type, text: dictionary.jsonString)
}

///a free function to make writing to the log with Log type
public func loggly(_ type: LogType, dictionary: NSDictionary) {
    Loggly.logger.write(type, text: dictionary.jsonString)
}
