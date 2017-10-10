//
//  AuthModel.swift
//  v-Space
//
//  Created by Сергей Сейтов on 10.10.2017.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit
import Firebase
import GoogleSignIn

struct Person : Codable {
    let email:String
    let displayName:String
    let photoURL:String
    let token:String
    
    var dictionary: [String: Any]? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data, options: .allowFragments)).flatMap { $0 as? [String: Any] }
    }
}

class AuthModel: NSObject {
    static let shared = AuthModel()
    
    func signOut(_ completion: @escaping() -> ()) {
        if let uid = Auth.auth().currentUser?.uid {
            let ref = Database.database().reference()
            ref.child("users").child(uid).removeValue(completionBlock: { _, _ in
                GIDSignIn.sharedInstance().signOut()
                try? Auth.auth().signOut()
                completion()
            })
        }
    }

    func updatePerson(_ user:User?) -> Bool {
        if let uid = user?.uid, let email = user?.email, let name = user?.displayName {
            let ref = Database.database().reference()
            var photoURL:String?
            if user?.photoURL != nil {
                photoURL = user!.photoURL!.absoluteString
            } else {
                photoURL = ""
            }
            var token = UserDefaults.standard.object(forKey: "token") as? String
            if token == nil {
                token = ""
            }
            let person = Person(email: email, displayName: name, photoURL: photoURL!, token: token!)
            if let data = person.dictionary {
                ref.child("users").child(uid).setValue(data)
                return true
            } else {
                return false
            }
        } else {
            return false
        }
    }

}
