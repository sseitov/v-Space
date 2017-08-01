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
    
    func allPhotos() -> [Photo] {
        if let all = photos?.allObjects as? [Photo] {
            return all
        } else {
            return []
        }
    }
}
