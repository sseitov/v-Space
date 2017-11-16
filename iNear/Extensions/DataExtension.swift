//
//  DataExtension.swift
//
//  Created by Сергей Сейтов on 22.05.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit

extension Data {
    
    func isEqualInConsistentTime(_ otherData:Data) -> Bool {
        // The point of this routine is XOR the bytes of each data and accumulate the results with OR.
        // If any bytes are different, then the OR will accumulate some non-0 value.
        if otherData.count - self.count != 0 {
            return false
        }
        
        var result:UInt8 = 0  // Start with 0 (equal) only if our lengths are equal
        
        let myBytes =  (self as NSData).bytes.bindMemory(to: UInt8.self, capacity: self.count)
        let myLength = self.count
        let otherBytes =  (otherData as NSData).bytes.bindMemory(to: UInt8.self, capacity: otherData.count)
        let otherLength = otherData.count
        
        for i in 0..<otherLength {
            // Use mod to wrap around ourselves if they are longer than we are.
            // Remember, we already broke equality if our lengths are different.
            result |= myBytes[i % myLength] ^ otherBytes[i];
        }
        
        return (result == 0)
    }
    
    /// Return hexadecimal string representation of Data bytes
    public var hexadecimalString: String {
        var bytes = [UInt8](repeating: 0, count: count)
        copyBytes(to: &bytes, count: count)
        
        let hexString = NSMutableString()
        for byte in bytes {
            hexString.appendFormat("%02x", UInt(byte))
        }
        
        return String(hexString)
    }
}
