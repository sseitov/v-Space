//
//  User+CoreDataClass.swift
//  iNear
//
//  Created by Сергей Сейтов on 09.12.16.
//  Copyright © 2016 Сергей Сейтов. All rights reserved.
//

import Foundation
import CoreData
import SDWebImage
import CoreLocation
import Firebase

enum SocialType:Int16 {
    case unknown = 0
    case facebook = 1
    case google = 2
    case email = 3
}

public class User: NSManagedObject {
    lazy var socialType: SocialType = {
        if let val = SocialType(rawValue: self.type) {
            return val
        } else {
            return .unknown
        }
    }()
    
    func socialTypeName() -> String {
        switch socialType {
        case .email:
            return "Email"
        case .facebook:
            return "Facebook"
        case .google:
            return "Google +"
        default:
            return "Unknown"
        }
    }
    
    lazy var imageURL: URL? = {
        if self.image != nil {
            return URL(string: self.image!)
        } else {
            return nil
        }
    }()
    
    lazy var shortName:String = {
        if self.givenName != nil {
            return self.givenName!
        } else if self.name != nil {
            return self.name!
        } else {
            return self.email!
        }
    }()
    
    func userData() -> [String:Any] {
        var profile:[String : Any] = ["socialType" : Int(type)]
        if email != nil {
            profile["email"] = email!
        }
        if name != nil {
            profile["name"] = name!
        }
        if givenName != nil {
            profile["givenName"] = givenName!
        }
        if familyName != nil {
            profile["familyName"] = familyName!
        }
        if image != nil {
            profile["imageURL"] = image!
        }

        return profile
    }
    
    func setUserData(_ profile:[String : Any], completion: @escaping() -> ()) {
        if let typeVal = profile["socialType"] as? Int {
            type = Int16(typeVal)
        } else {
            type = 0
        }
        email = profile["email"] as? String
        name = profile["name"] as? String
        givenName = profile["givenName"] as? String
        familyName = profile["familyName"] as? String

        image = profile["imageURL"] as? String
        if image != nil, let url = URL(string: image!) {
            SDWebImageDownloader.shared().downloadImage(with: url, options: [], progress: { _ in}, completed: { _, data, error, _ in
                if data != nil {
                    self.imageData = data as NSData?
                }
                Model.shared.saveContext()
                completion()
            })
        } else {
            imageData = nil
            completion()
        }
    }

    func getImage() -> UIImage {
        if imageData != nil {
            return UIImage(data: imageData! as Data)!
        } else {
            return UIImage.imageWithColor(
                ColorUtility.md5color(email!),
                size: CGSize(width: 100, height: 100)).addImage(UIImage(named: "question")!)
        }
    }
}
