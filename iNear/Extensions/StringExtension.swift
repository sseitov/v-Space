//
//  StringExtension.swift
//
//  Created by Сергей Сейтов on 22.05.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit

extension String {
    
    var localized : String {
        return NSLocalizedString(self, comment: "")
    }
    
    static func generateUDID() -> String {
        return UUID().uuidString
    }

    func isEmail() -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,6}"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: self)
    }
    
    
    func normalizeEmail() -> String {
        let components = self.components(separatedBy: "@")
        if components.count < 2 {
            return self
        }
        
        do {
            let regex:NSRegularExpression = try NSRegularExpression(pattern: "(\\+\\d+)$", options: .caseInsensitive)
            var new = regex.stringByReplacingMatches(in: components[0], options: .withoutAnchoringBounds, range: NSMakeRange(0, (components[0] as NSString).length), withTemplate: "")
            new = new.replacingOccurrences(of: ".", with: "")
            return new + "@" + components[1]
        } catch {
            print(error)
            return self
        }
    }
    
    func partInRange(_ start:Int, end:Int) -> String {
        let startIndex = self.index(self.startIndex, offsetBy: start)
        let endIndex = self.index(self.startIndex, offsetBy: end)
        return String(self[startIndex..<endIndex])
    }

    func length() -> Int {
        return (self as NSString).length
    }
    
    func digitsFromString() -> String {
        let digitSet = CharacterSet.decimalDigits
        let filteredCharacters = self.filter {
            return  String($0).rangeOfCharacter(from: digitSet) != nil
        }
        return String(filteredCharacters)
    }
    
    
    func hasSpecialCharacters() -> Bool {
        let characterset = CharacterSet(charactersIn: " abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLKMNOPQRSTUVWXYZ0123456789")
        if self.rangeOfCharacter(from: characterset.inverted) != nil {
            return true
        } else {
            return false
        }
    }

}
