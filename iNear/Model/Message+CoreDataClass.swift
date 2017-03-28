//
//  Message+CoreDataClass.swift
//  iNear
//
//  Created by Сергей Сейтов on 10.12.16.
//  Copyright © 2016 Сергей Сейтов. All rights reserved.
//

import Foundation
import CoreData
import CoreLocation

public class Message: NSManagedObject {

    func setData(_ data:[String:Any], new:Bool, completion:@escaping () -> ()) {
        from = data["from"] as? String
        to = data["to"] as? String
        text = data["text"] as? String
        imageURL = data["image"] as? String
        isNew = new
        if let dateVal = data["date"] as? String {
            date = Model.shared.dateFormatter.date(from: dateVal) as NSDate?
        } else {
            date = nil
        }
        if let lat = data["latitude"] as? Double, let lon = data["longitude"] as? Double {
            latitude = lat
            longitude = lon
        }
        track = data["track"] as? String
        
        if imageURL != nil {
            let ref = Model.shared.storageRef.child(imageURL!)
            ref.data(withMaxSize: INT64_MAX, completion: { data, error in
                self.imageData = data as NSData?
                Model.shared.saveContext()
                completion()
            })
        } else {
            Model.shared.saveContext()
            completion()
        }
    }

    func setLocationData(_ data:[String:Any]) {
        if from != nil && date != nil {
            if let lat = data["latitude"] as? Double, let lon = data["longitude"] as? Double {
                let coordinate = CLLocationCoordinate2D(latitude:lat, longitude:lon)
                Model.shared.setCoordinateForUser(coordinate, at: date!.timeIntervalSince1970, userID: from!)
            }
        }
    }

}
