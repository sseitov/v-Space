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

let updateFriendsNotification = Notification.Name("UPDATE_FRIENDS")
let updateLocationNotification = Notification.Name("UPDATE_LOCATION")

func currentUid() -> String? {
    return Auth.auth().currentUser?.uid
}

class AuthModel: NSObject {
    static let shared = AuthModel()
    
    private var newFriendRefHandle: DatabaseHandle?
    private var deleteFriendRefHandle: DatabaseHandle?
    private var updateLocationRefHandle: DatabaseHandle?

    func startObservers() {
        if newFriendRefHandle == nil {
            observeFriends()
        }
        if updateLocationRefHandle == nil {
            observeLocations()
        }
    }
    
    func signOut(_ completion: @escaping() -> ()) {
        if let uid = Auth.auth().currentUser?.uid {
            let ref = Database.database().reference()
            ref.child("locations").child(uid).removeValue()
            ref.child("users").child(uid).removeValue(completionBlock: { _, _ in
                GIDSignIn.sharedInstance().signOut()
                try? Auth.auth().signOut()
                self.newFriendRefHandle = nil
                self.deleteFriendRefHandle = nil
                self.updateLocationRefHandle = nil
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
            var token = Messaging.messaging().fcmToken
            if token == nil {
                token = ""
            }
            if let endpoint = UserDefaults.standard.object(forKey: "endpoint") as? String {
                publishEndpoint(endpoint)
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
    
    func userData(_ uid:String, data : @escaping([String:Any]?) -> ()) {
        let ref = Database.database().reference()
        ref.child("users").child(uid).observeSingleEvent(of: .value, with: { snapshot in
            if let result = snapshot.value as? [String:Any] {
                data(result)
            }
        })
    }
    
    private func observeFriends() {
        let ref = Database.database().reference()
        let friendQuery = ref.child("friends").queryLimited(toLast:25)
        
        newFriendRefHandle = friendQuery.observe(.childAdded, with: { (snapshot) -> Void in
            NotificationCenter.default.post(name: updateFriendsNotification, object: nil)
        })
        
        deleteFriendRefHandle = friendQuery.observe(.childRemoved, with: { (snapshot) -> Void in
            NotificationCenter.default.post(name: updateFriendsNotification, object: nil)
        })

    }
    
    fileprivate func observeLocations() {
        let ref = Database.database().reference()
        let locationQuery = ref.child("locations").queryLimited(toLast:25)
        
        updateLocationRefHandle = locationQuery.observe(.childChanged, with: { (snapshot) -> Void in
            if let info = snapshot.value as? [String:Any] {
                NotificationCenter.default.post(name: updateLocationNotification, object: snapshot.key, userInfo: info)
            }
        })
    }
    
    func publishEndpoint(_ endpoint:String) {
        let ref = Database.database().reference()
        ref.child("endponts").child(Auth.auth().currentUser!.uid).setValue(endpoint)
    }
    
    func userEndpoint(_ uid:String, endpoint:@escaping(String?) -> ()) {
        let ref = Database.database().reference()
        ref.child("endponts").child(uid).observeSingleEvent(of: .value, with: { snapshot in
            endpoint(snapshot.value as? String)
        })
    }
}
