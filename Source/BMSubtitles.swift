//
//  BMSubtitles.swift
//  Pods
//
//  Created by BrikerMan on 2017/4/2.
//
//

import Foundation

public enum ParseSubtitleError: Error {
    case Failed
    case InvalidFormat
}

public class BMSubtitles: NSObject {
    public var titles: [Title]?
    
    public init(url: URL) {
        super.init()
        
        do {
            
            do {
                let fileContent = try String(contentsOf: url, encoding: String.Encoding.utf8)
                titles = try self.parseSRTSub(fileContent)
            }
            catch {
                debugPrint(error)
            }
        }
        catch {
            debugPrint(error)
        }
    }
    
    func parseSRTSub(_ rawSub: String) throws -> [Title] {
        var allTitles = [Title]()
        var components = rawSub.components(separatedBy: "\r\n\r\n")
        
        // Fall back to \n\n separation
        if components.count == 1 {
            components = rawSub.components(separatedBy: "\n\n")
        }
        
        for component in components {
            if component.isEmpty {
                continue
            }
            
            let scanner = Scanner(string: component)
            
            var indexResult: Int = -99
            var startResult: NSString?
            var endResult: NSString?
            var textResult: NSString?
            
            let indexScanSuccess = scanner.scanInt(&indexResult)
            let startTimeScanResult = scanner.scanUpToCharacters(from: CharacterSet.whitespaces, into: &startResult)
            let dividerScanSuccess = scanner.scanUpTo("> ", into: nil)
            if (scanner.scanLocation + 2 <= scanner.string.count) {
            scanner.scanLocation += 2
            }
            let endTimeScanResult = scanner.scanUpToCharacters(from: CharacterSet.newlines, into: &endResult)
            if (scanner.scanLocation + 1 <= scanner.string.count) {

            scanner.scanLocation += 1
            }
            var textLines = [String]()
            
            // Iterate over text lines
            while scanner.isAtEnd == false {
                let textLineScanResult = scanner.scanUpToCharacters(from: CharacterSet.newlines, into: &textResult)
                
                guard textLineScanResult else {
                    throw ParseSubtitleError.InvalidFormat
                }
                
                textLines.append(textResult as! String)
            }
            
            guard indexScanSuccess && startTimeScanResult && dividerScanSuccess && endTimeScanResult else {
                throw ParseSubtitleError.InvalidFormat
            }
            
            let startTimeInterval: TimeInterval = timeIntervalFromString(startResult! as String)
            let endTimeInterval: TimeInterval = timeIntervalFromString(endResult! as String)
            
            let title = Title(withTexts: textLines, start: startTimeInterval, end: endTimeInterval, index: indexResult)
            allTitles.append(title)
        }
        
        return allTitles
    }
    
    // TODO: Throw
    func timeIntervalFromString(_ timeString: String) -> TimeInterval {
        let scanner = Scanner(string: timeString)
        
        var hoursResult: Int = 0
        var minutesResult: Int = 0
        var secondsResult: NSString?
        var millisecondsResult: NSString?
        
        // Extract time components from string
        scanner.scanInt(&hoursResult)
        scanner.scanLocation += 1
        scanner.scanInt(&minutesResult)
        scanner.scanLocation += 1
        scanner.scanUpTo(",", into: &secondsResult)
        scanner.scanLocation += 1
        scanner.scanUpToCharacters(from: CharacterSet.newlines, into: &millisecondsResult)
        
        let secondsString = secondsResult! as String
        let seconds = Int(secondsString)
        
        let millisecondsString = millisecondsResult! as String
        let milliseconds = Int(millisecondsString)
        
        let timeInterval: Double = Double(hoursResult) * 3600 + Double(minutesResult) * 60 + Double(seconds!) + Double(Double(milliseconds!)/1000)
        
        return timeInterval as TimeInterval
    }
    public func search(for time: TimeInterval) -> Title? {
        let result = titles?.first(where: { group -> Bool in
              if group.start <= time && group.end >= time {
                  return true
              }
              return false
          })
          return result
      }
}

public class Title: NSObject {
    public var texts: [String]
    public var start: TimeInterval
    public var end: TimeInterval
    public var index: Int?
    public var text:String {
        return texts.joined(separator: "\n")
    }
    
    public init(withTexts: [String], start: TimeInterval, end: TimeInterval, index: Int) {
//        super.init()
        
        self.texts = withTexts
        self.start = start
        self.end = end
        self.index = index
    }
}

class OpenSubtitlesHash: NSObject {
    static let chunkSize: Int = 65536
    
    struct VideoHash {
        var fileHash: String
        var fileSize: UInt64
    }
    
    public class func hashFor(_ url: URL) -> VideoHash {
        return self.hashFor(url.path)
    }
    
    public class func hashFor(_ path: String) -> VideoHash {
        var fileHash = VideoHash(fileHash: "", fileSize: 0)
        let fileHandler = FileHandle(forReadingAtPath: path)!
        
        let fileDataBegin: NSData = fileHandler.readData(ofLength: chunkSize) as NSData
        fileHandler.seekToEndOfFile()
        
        let fileSize: UInt64 = fileHandler.offsetInFile
        if (UInt64(chunkSize) > fileSize) {
            return fileHash
        }
        
        fileHandler.seek(toFileOffset: max(0, fileSize - UInt64(chunkSize)))
        let fileDataEnd: NSData = fileHandler.readData(ofLength: chunkSize) as NSData
        
        var hash: UInt64 = fileSize
        
        var data_bytes = UnsafeBufferPointer<UInt64>(
            start: UnsafePointer(fileDataBegin.bytes.assumingMemoryBound(to: UInt64.self)),
            count: fileDataBegin.length/MemoryLayout<UInt64>.size
        )
        
        hash = data_bytes.reduce(hash,&+)
        
        data_bytes = UnsafeBufferPointer<UInt64>(
            start: UnsafePointer(fileDataEnd.bytes.assumingMemoryBound(to: UInt64.self)),
            count: fileDataEnd.length/MemoryLayout<UInt64>.size
        )
        
        hash = data_bytes.reduce(hash,&+)
        
        fileHash.fileHash = String(format:"%016qx", arguments: [hash])
        fileHash.fileSize = fileSize
        
        fileHandler.closeFile()
        
        return fileHash
    }
}
