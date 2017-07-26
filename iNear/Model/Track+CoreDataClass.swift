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
    
    func speed() -> Double {
        if distance > 0 && startDate != nil && finishDate != nil {
            let timeSec = finishDate!.timeIntervalSince1970 - startDate!.timeIntervalSince1970
            return distance / ( timeSec * 60 * 60 )
        } else {
            return 0
        }
    }
    
}
