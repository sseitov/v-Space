//
//  Track+CoreDataProperties.swift
//  v-Space
//
//  Created by Сергей Сейтов on 23.04.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import Foundation
import CoreData


extension Track {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Track> {
        return NSFetchRequest<Track>(entityName: "Track")
    }

    @NSManaged public var place: String?
    @NSManaged public var uid: String?
    @NSManaged public var path: String?
    @NSManaged public var date: NSDate?
    @NSManaged public var photos: NSSet?
    @NSManaged public var points: NSSet?

}

// MARK: Generated accessors for photos
extension Track {

    @objc(addPhotosObject:)
    @NSManaged public func addToPhotos(_ value: Photo)

    @objc(removePhotosObject:)
    @NSManaged public func removeFromPhotos(_ value: Photo)

    @objc(addPhotos:)
    @NSManaged public func addToPhotos(_ values: NSSet)

    @objc(removePhotos:)
    @NSManaged public func removeFromPhotos(_ values: NSSet)

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
