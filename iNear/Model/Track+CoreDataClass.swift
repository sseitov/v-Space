//
//  Track+CoreDataClass.swift
//  v-Space
//
//  Created by Сергей Сейтов on 30.03.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import Foundation
import CoreData

public class Track: NSManagedObject {

    func trackPoints() -> [Location] {
        if let all = points?.allObjects as? [Location] {
            return all.sorted(by: { loc1, loc2 in
                return loc1.date > loc2.date
            })
        } else {
            return []
        }
    }
    
    func trackDate(_ last:Bool = true) -> Date {
        if date != nil {
            return date! as Date
        } else {
            if let all = points?.allObjects as? [Location] {
                let sorted = all.sorted(by: { loc1, loc2 in
                    return loc1.date < loc2.date
                })
                if last {
                    return Date(timeIntervalSince1970: sorted.last!.date)
                } else {
                    return Date(timeIntervalSince1970: sorted.first!.date)
                }
            } else {
                return Date()
            }
        }
    }
}
