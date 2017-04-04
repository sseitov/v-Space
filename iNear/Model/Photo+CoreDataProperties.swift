//
//  Photo+CoreDataProperties.swift
//  v-Space
//
//  Created by Сергей Сейтов on 03.04.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import Foundation
import CoreData


extension Photo {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Photo> {
        return NSFetchRequest<Photo>(entityName: "Photo")
    }

    @NSManaged public var creationDate: NSDate?
    @NSManaged public var uid: String?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var track: Track?

}
