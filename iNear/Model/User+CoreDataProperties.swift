//
//  User+CoreDataProperties.swift
//  v-Space
//
//  Created by Сергей Сейтов on 28.03.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import Foundation
import CoreData


extension User {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<User> {
        return NSFetchRequest<User>(entityName: "User");
    }

    @NSManaged public var email: String?
    @NSManaged public var familyName: String?
    @NSManaged public var givenName: String?
    @NSManaged public var image: String?
    @NSManaged public var imageData: NSData?
    @NSManaged public var name: String?
    @NSManaged public var type: Int16
    @NSManaged public var uid: String?

}
