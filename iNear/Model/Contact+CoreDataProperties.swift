//
//  Contact+CoreDataProperties.swift
//  iNear
//
//  Created by Сергей Сейтов on 29.01.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import Foundation
import CoreData


extension Contact {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Contact> {
        return NSFetchRequest<Contact>(entityName: "Contact");
    }

    @NSManaged public var initiator: String?
    @NSManaged public var requester: String?
    @NSManaged public var status: Int16
    @NSManaged public var uid: String?
    @NSManaged public var owner: User?

}
