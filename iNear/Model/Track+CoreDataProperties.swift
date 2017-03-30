//
//  Track+CoreDataProperties.swift
//  v-Space
//
//  Created by Сергей Сейтов on 30.03.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import Foundation
import CoreData


extension Track {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Track> {
        return NSFetchRequest<Track>(entityName: "Track")
    }

    @NSManaged public var uid: String?
    @NSManaged public var place: String?
    @NSManaged public var points: NSSet?

}

// MARK: Generated accessors for points
extension Track {

    @objc(addPointsObject:)
    @NSManaged public func addToPoints(_ value: Location)

    @objc(removePointsObject:)
    @NSManaged public func removeFromPoints(_ value: Location)

    @objc(addPoints:)
    @NSManaged public func addToPoints(_ values: NSSet)

    @objc(removePoints:)
    @NSManaged public func removeFromPoints(_ values: NSSet)

}
