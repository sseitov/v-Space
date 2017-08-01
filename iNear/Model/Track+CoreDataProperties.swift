//
//  Track+CoreDataProperties.swift
//  v-Space
//
//  Created by Sergey Seitov on 01.08.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import Foundation
import CoreData


extension Track {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Track> {
        return NSFetchRequest<Track>(entityName: "Track")
    }

    @NSManaged public var distance: Double
    @NSManaged public var finishDate: NSDate?
    @NSManaged public var path: String?
    @NSManaged public var place: String?
    @NSManaged public var startDate: NSDate?
    @NSManaged public var uid: String?
    @NSManaged public var synced: Bool
    @NSManaged public var photos: NSSet?

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
