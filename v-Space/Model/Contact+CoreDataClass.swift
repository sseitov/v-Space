//
//  Contact+CoreDataClass.swift
//  iNear
//
//  Created by Сергей Сейтов on 15.12.16.
//  Copyright © 2016 Сергей Сейтов. All rights reserved.
//

import Foundation
import CoreData


enum ContactStatus:Int16 {
    case requested = 1
    case approved = 2
    case rejected = 3
}

public class Contact: NSManagedObject {

    func getContactStatus() -> ContactStatus {
        switch status {
        case 1:
            return .requested
        case 2:
            return .approved
        default:
            return .rejected
        }
    }
    
    func getData() -> [String:Any] {
        Model.shared.saveContext()
        let data:[String:Any] = ["uid" : uid!, "initiator" : initiator!, "requester" : requester!, "status" : Int(status)]
        return data
    }
    
    func setData(_ data:[String:Any]) {
        initiator = data["initiator"] as? String
        requester = data["requester"] as? String
        if let st = data["status"] as? Int {
            status = Int16(st)
        }
        Model.shared.saveContext()
    }

}
