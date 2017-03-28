//
//  Message+CoreDataProperties.swift
//  iNear
//
//  Created by Сергей Сейтов on 05.03.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import Foundation
import CoreData


extension Message {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Message> {
        return NSFetchRequest<Message>(entityName: "Message");
    }

    @NSManaged public var date: NSDate?
    @NSManaged public var from: String?
    @NSManaged public var imageData: NSData?
    @NSManaged public var imageURL: String?
    @NSManaged public var isNew: Bool
    @NSManaged public var text: String?
    @NSManaged public var to: String?
    @NSManaged public var uid: String?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var track: String?

}
