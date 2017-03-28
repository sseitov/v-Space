//
//  Utilities.swift
//  iNear
//
//  Created by Сергей Сейтов on 18.11.16.
//  Copyright © 2016 Сергей Сейтов. All rights reserved.
//

import Foundation

func generateUDID() -> String {
    return UUID().uuidString
}

func iNearError(_ text:String) -> NSError {
    return NSError(domain: "iNear", code: -1, userInfo: [NSLocalizedDescriptionKey:text])
}

func WAIT(_ condition:NSCondition) {
    condition.lock()
    condition.wait()
    condition.unlock()
}

func SIGNAL(_ condition:NSCondition) {
    condition.lock()
    condition.signal()
    condition.unlock()
}

func stringFromData(_ data:Data) -> String {
    return data.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
}

func dataFromString(_ string:String) -> Data? {
    return Data(base64Encoded: string, options: NSData.Base64DecodingOptions(rawValue: 0))
}
