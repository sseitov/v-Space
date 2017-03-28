//
//  Model.swift
//  iNear
//
//  Created by Сергей Сейтов on 09.12.16.
//  Copyright © 2016 Сергей Сейтов. All rights reserved.
//

import Foundation
import CoreData
import Firebase
import AFNetworking
import SDWebImage
import CoreLocation
import GoogleMaps

enum PushType:Int {
    case none = 0
    case newCoordinate = 1
    case newMessage = 2
}

let newMessageNotification = Notification.Name("NEW_MESSAGE")
let deleteMessageNotification = Notification.Name("DELETE_MESSAGE")
let readMessageNotification = Notification.Name("READ_MESSAGE")
let contactNotification = Notification.Name("CONTACT")

func currentUser() -> User? {
    if FIRAuth.auth()?.currentUser != nil {
        return Model.shared.getUser(FIRAuth.auth()!.currentUser!.uid)
    } else {
        return nil
    }
}

class Model : NSObject {
    
    static let shared = Model()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Date formatter
    
    lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter
    }()
    
    lazy var textDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()
    
    lazy var textYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    // MARK: - SignOut from cloud
    
    func signOut() {
        if currentUser() != nil {
            switch currentUser()!.socialType {
            case .google:
                GIDSignIn.sharedInstance().signOut()
            case .facebook:
                FBSDKLoginManager().logOut()
            default:
                break
            }
        }
        try? FIRAuth.auth()?.signOut()
        newMessageRefHandle = nil
        deleteMessageRefHandle = nil
        updateTokenRefHandle = nil
        newTokenRefHandle = nil
        updateContactRefHandle = nil
        newContactRefHandle = nil
        deleteContactRefHandle = nil
    }
    
    // MARK: - Cloud observers
    
    func startObservers() {
        if newMessageRefHandle == nil {
            observeMessages()
        }
        if updateTokenRefHandle == nil {
            observeTokens()
        }
        if updateContactRefHandle == nil {
            observeContacts()
        }
    }
    
    lazy var storageRef: FIRStorageReference = FIRStorage.storage().reference(forURL: firStorage)
    
    private var newMessageRefHandle: FIRDatabaseHandle?
    private var deleteMessageRefHandle: FIRDatabaseHandle?
    
    private var updateTokenRefHandle: FIRDatabaseHandle?
    private var newTokenRefHandle: FIRDatabaseHandle?
    
    private var updateContactRefHandle: FIRDatabaseHandle?
    private var newContactRefHandle: FIRDatabaseHandle?
    private var deleteContactRefHandle: FIRDatabaseHandle?
    
    // MARK: - Push notifications
    
    fileprivate lazy var httpManager:AFHTTPSessionManager = {
        let manager = AFHTTPSessionManager(baseURL: URL(string: "https://fcm.googleapis.com/fcm/"))
        manager.requestSerializer = AFJSONRequestSerializer()
        manager.requestSerializer.setValue("application/json", forHTTPHeaderField: "Content-Type")
        manager.requestSerializer.setValue("key=\(pushServerKey)", forHTTPHeaderField: "Authorization")
        manager.responseSerializer = AFHTTPResponseSerializer()
        return manager
    }()
    
    fileprivate func messagePush(_ text:String, to:User, from:User) {
        if to.token != nil {
            let data:[String:Int] = ["pushType" : PushType.newMessage.rawValue]
            let notification:[String:Any] = ["title" : "New message from \(from.shortName):",
                "body": text,
                "sound":"default",
                "content_available": true]
            let message:[String:Any] = ["to" : to.token!, "priority" : "high", "notification" : notification, "data" : data]
            httpManager.post("send", parameters: message, progress: nil, success: { task, response in
            }, failure: { task, error in
                print("SEND PUSH ERROR: \(error)")
            })
        } else {
            print("USER HAVE NO TOKEN")
        }
    }

    // MARK: - CoreData stack
    
    lazy var applicationDocumentsDirectory: URL = {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[urls.count-1]
    }()
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        let modelURL = Bundle.main.url(forResource: "iNear", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.appendingPathComponent("iNear.sqlite")
        do {
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true])
        } catch {
            print("CoreData data error: \(error)")
        }
        return coordinator
    }()
    
    lazy var managedObjectContext: NSManagedObjectContext = {
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()
    
    func saveContext () {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                print("Saved data error: \(error)")
            }
        }
    }
    
    // MARK: - User table
    
    func createUser(_ uid:String) -> User {
        var user = getUser(uid)
        if user == nil {
            user = NSEntityDescription.insertNewObject(forEntityName: "User", into: managedObjectContext) as? User
            user!.uid = uid
        }
        return user!
    }
    
    func getUser(_ uid:String) -> User? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "User")
        let predicate = NSPredicate(format: "uid = %@", uid)
        fetchRequest.predicate = predicate
        if let user = try? managedObjectContext.fetch(fetchRequest).first as? User {
            return user
        } else {
            return nil
        }
    }
    
    func deleteUser(_ user:User) {
        managedObjectContext.delete(user)
        saveContext()
    }
    
    func uploadUser(_ uid:String, result: @escaping(User?) -> ()) {
        if let existUser = getUser(uid) {
            result(existUser)
        } else {
            let ref = FIRDatabase.database().reference()
            ref.child("users").child(uid).observeSingleEvent(of: .value, with: { snapshot in
                if let userData = snapshot.value as? [String:Any] {
                    let user = self.createUser(uid)
                    user.setUserData(userData, completion: {
                        result(user)
                    })
                } else {
                    result(nil)
                }
            })
        }
    }
    
    func updateUser(_ user:User) {
        saveContext()
        let ref = FIRDatabase.database().reference()
        ref.child("users").child(user.uid!).setValue(user.userData())
    }
    
    func publishToken(_ user:FIRUser,  token:String) {
        let ref = FIRDatabase.database().reference()
        ref.child("tokens").child(user.uid).setValue(token)
    }
    
    fileprivate func observeTokens() {
        let ref = FIRDatabase.database().reference()
        let coordQuery = ref.child("tokens").queryLimited(toLast:25)
        
        newTokenRefHandle = coordQuery.observe(.childAdded, with: { (snapshot) -> Void in
            if let user = self.getUser(snapshot.key) {
                if let token = snapshot.value as? String {
                    user.token = token
                    self.saveContext()
                }
            }
        })
        
        updateTokenRefHandle = coordQuery.observe(.childChanged, with: { (snapshot) -> Void in
            if let user = self.getUser(snapshot.key) {
                if let token = snapshot.value as? String {
                    user.token = token
                    self.saveContext()
                }
            }
        })
    }
    
    func setEmailUser(_ user:FIRUser, email:String) {
        let cashedUser = createUser(user.uid)
        cashedUser.type = Int16(SocialType.email.rawValue)
        cashedUser.email = email
        updateUser(cashedUser)
    }
    
    func setFacebookUser(_ user:FIRUser, profile:[String:Any], completion: @escaping() -> ()) {
        let cashedUser = createUser(user.uid)
        cashedUser.type = Int16(SocialType.facebook.rawValue)
        cashedUser.email = profile["email"] as? String
        cashedUser.name = profile["name"] as? String
        cashedUser.givenName = profile["first_name"] as? String
        cashedUser.familyName = profile["last_name"] as? String
        if let picture = profile["picture"] as? [String:Any] {
            if let data = picture["data"] as? [String:Any] {
                cashedUser.image = data["url"] as? String
            }
        }
        if cashedUser.image != nil, let url = URL(string: cashedUser.image!) {
            SDWebImageDownloader.shared().downloadImage(with: url, options: [], progress: { _ in}, completed: { _, data, error, _ in
                if data != nil {
                    cashedUser.imageData = data as NSData?
                }
                self.updateUser(cashedUser)
                completion()
            })
        } else {
            cashedUser.imageData = nil
            updateUser(cashedUser)
            completion()
        }
    }
    
    func setGoogleUser(_ user:FIRUser, googleProfile: GIDProfileData!, completion: @escaping() -> ()) {
        let cashedUser = createUser(user.uid)
        cashedUser.type = Int16(SocialType.google.rawValue)
        cashedUser.email = googleProfile.email
        cashedUser.name = googleProfile.name
        cashedUser.givenName = googleProfile.givenName
        cashedUser.familyName = googleProfile.familyName
        if googleProfile.hasImage {
            if let url = googleProfile.imageURL(withDimension: 100) {
                cashedUser.image = url.absoluteString
            }
        }
        if cashedUser.image != nil, let url = URL(string: cashedUser.image!) {
            SDWebImageDownloader.shared().downloadImage(with: url, options: [], progress: { _ in}, completed: { _, data, error, _ in
                if data != nil {
                    cashedUser.imageData = data as NSData?
                }
                self.updateUser(cashedUser)
                completion()
            })
        } else {
            cashedUser.imageData = nil
            updateUser(cashedUser)
            completion()
        }
    }

    func allContacts() -> [User] {
        if currentUser() == nil {
            return[]
        }
        var users:[User] = []
        if let contacts = currentUser()!.contacts?.allObjects as? [Contact] {
            for contact in contacts {
                if contact.initiator! != currentUser()!.uid!, let peer = getUser(contact.initiator!) {
                    users.append(peer)
                } else if let peer = getUser(contact.requester!){
                    users.append(peer)
                }
            }
        }
        return users
    }
    
    // MARK: - Contacts table
    
    func createContact(_ uid:String) -> Contact {
        var contact = getContact(uid)
        if contact == nil {
            contact = NSEntityDescription.insertNewObject(forEntityName: "Contact", into: managedObjectContext) as? Contact
            contact!.uid = uid
        }
        return contact!
    }
    
    func getContact(_ uid:String) -> Contact? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Contact")
        let predicate = NSPredicate(format: "uid = %@", uid)
        fetchRequest.predicate = predicate
        if let contact = try? managedObjectContext.fetch(fetchRequest).first as? Contact {
            return contact
        } else {
            return nil
        }
    }

    func addContact(with:User) {
        let contact = createContact(generateUDID())
        contact.initiator = currentUser()!.uid
        contact.requester = with.uid!
        contact.status = ContactStatus.requested.rawValue
        contact.owner = currentUser()
        currentUser()?.addToContacts(contact)
        
        let ref = FIRDatabase.database().reference()
        ref.child("contacts").child(contact.uid!).setValue(contact.getData())
        let text = "\(currentUser()!.shortName) (\(currentUser()!.email!)) ask you to add him into contact list."
        messagePush(text, to: with, from: currentUser()!)

        NotificationCenter.default.post(name: contactNotification, object: nil)
    }
    
    func approveContact(_ contact:Contact) {
        let ref = FIRDatabase.database().reference()
        contact.status = ContactStatus.approved.rawValue
        ref.child("contacts").child(contact.uid!).setValue(contact.getData())
    }
    
    func rejectContact(_ contact:Contact) {
        let ref = FIRDatabase.database().reference()
        contact.status = ContactStatus.rejected.rawValue
        ref.child("contacts").child(contact.uid!).setValue(contact.getData())
    }
    
    func deleteContact(_ contact:Contact) {
        let ref = FIRDatabase.database().reference()
        ref.child("contacts").child(contact.uid!).removeValue()
        currentUser()?.removeFromContacts(contact)
        managedObjectContext.delete(contact)
        saveContext()
    }
    
    fileprivate func observeContacts() {
        let ref = FIRDatabase.database().reference()
        let contactQuery = ref.child("contacts").queryLimited(toLast:25)
        
        newContactRefHandle = contactQuery.observe(.childAdded, with: { (snapshot) -> Void in
            if self.getContact(snapshot.key) == nil {
                if let contactData = snapshot.value as? [String:Any] {
                    if let from = contactData["initiator"] as? String, let to = contactData["requester"] as? String {
                        if from == currentUser()!.uid! || to == currentUser()!.uid! {
                            self.uploadUser(from, result: { fromUser in
                                if fromUser != nil {
                                    self.uploadUser(to, result: { toUser in
                                        if toUser != nil {
                                            let contact = self.createContact(snapshot.key)
                                            contact.owner = currentUser()
                                            currentUser()?.addToContacts(contact)
                                            contact.setData(contactData)
                                            NotificationCenter.default.post(name: contactNotification, object: nil)
                                        }
                                    })
                                }
                            })
                        }
                    }
                }
            }
        })
        
        updateContactRefHandle = contactQuery.observe(.childChanged, with: { (snapshot) -> Void in
            if let contact = self.getContact(snapshot.key) {
                if let data = snapshot.value as? [String:Any] {
                    contact.setData(data)
                    NotificationCenter.default.post(name: contactNotification, object: contact)
                }
            }
        })
        
        deleteContactRefHandle = contactQuery.observe(.childRemoved, with: { (snapshot) -> Void in
            if let contact = self.getContact(snapshot.key) {
                currentUser()!.removeFromContacts(contact)
                self.managedObjectContext.delete(contact)
                self.saveContext()
                NotificationCenter.default.post(name: contactNotification, object: nil)
            }
        })

    }
    
    func contactWithUser(_ uid:String) -> Contact? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Contact")
        let predicate1  = NSPredicate(format: "initiator == %@", uid)
        let predicate2 = NSPredicate(format: "requester == %@", uid)
        fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [predicate1, predicate2])
        
        if let all = try? managedObjectContext.fetch(fetchRequest) as! [Contact] {
            return all.first
        } else {
            return nil
        }
    }
    
    // MARK: - Message table
    
    func createMessage(_ uid:String) -> Message {
        var message = getMessage(uid)
        if message == nil {
            message = NSEntityDescription.insertNewObject(forEntityName: "Message", into: managedObjectContext) as? Message
            message!.uid = uid
        }
        return message!
    }
    
    func getMessage(_ uid:String) -> Message? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        let predicate = NSPredicate(format: "uid = %@", uid)
        fetchRequest.predicate = predicate
        if let message = try? managedObjectContext.fetch(fetchRequest).first as? Message {
            return message
        } else {
            return nil
        }
    }
    
    func getMessage(from:User, date:Date) -> Message? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        let predicate1 = NSPredicate(format: "from = %@", from.uid!)
        let predicate2 = NSPredicate(format: "date = %@", date as NSDate)
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate1, predicate2])
        if let message = try? managedObjectContext.fetch(fetchRequest).first as? Message {
            return message
        } else {
            return nil
        }
    }
    
    func deleteMessage(_ message:Message, completion: @escaping() -> ()) {
        let ref = FIRDatabase.database().reference()
        if let image = message.imageURL {
            self.storageRef.child(image).delete(completion: { _ in
                ref.child("messages").child(message.uid!).removeValue(completionBlock:{_, _ in
                    completion()
                })
            })
        } else {
            ref.child("messages").child(message.uid!).removeValue(completionBlock: { _, _ in
                completion()
            })
        }
    }
    
    private func chatPredicate(with:String) -> NSPredicate {
        let predicate1  = NSPredicate(format: "from == %@", with)
        let predicate2 = NSPredicate(format: "to == %@", currentUser()!.uid!)
        let toPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate1, predicate2])
        let predicate3  = NSPredicate(format: "from == %@", currentUser()!.uid!)
        let predicate4 = NSPredicate(format: "to == %@", with)
        let fromPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate3, predicate4])
        return NSCompoundPredicate(orPredicateWithSubpredicates: [toPredicate, fromPredicate])
    }
    
    func chatMessages(with:String) -> [Message] {
        if currentUser() == nil {
            return []
        }
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        fetchRequest.predicate = chatPredicate(with: with)
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        if let all = try? managedObjectContext.fetch(fetchRequest) as! [Message] {
            return all
        } else {
            return []
        }
    }
    
    func unreadCountInChat(_ uid:String) -> Int {
        if currentUser() == nil {
            return 0
        }
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        let predicate = NSPredicate(format: "isNew == YES")
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [chatPredicate(with: uid), predicate])
        
        do {
            return try managedObjectContext.count(for: fetchRequest)
        } catch {
            return 0
        }
    }
    
    func lastMessageInChat(_ uid:String) -> Message? {
        if currentUser() == nil {
            return nil
        }
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        fetchRequest.predicate = chatPredicate(with: uid)
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchRequest.fetchLimit = 1
        if let all = try? managedObjectContext.fetch(fetchRequest) as! [Message] {
            return all.first
        } else {
            return nil
        }
    }
    
    func allUnreadCount() -> Int {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        fetchRequest.predicate = NSPredicate(format: "isNew == YES")
        do {
            return try managedObjectContext.count(for: fetchRequest)
        } catch {
            return 0
        }
    }
    
    func readMessage(_ message:Message) {
        message.isNew = false
        saveContext()
        NotificationCenter.default.post(name: readMessageNotification, object: message)
    }
    
    func myTrackLastDay() -> String? {
        if let all = LocationManager.shared.myTrackPointsForLastDay() {
            let path = GMSMutablePath()
            for pt in all {
                path.add(CLLocationCoordinate2D(latitude: pt.latitude, longitude: pt.longitude))
            }
            return path.encodedPath();
        } else {
            return nil
        }
    }

    func trackPoints(_ track:String) -> [CLLocationCoordinate2D] {
        var points:[CLLocationCoordinate2D] = []
        if let path = GMSPath(fromEncodedPath: track) {
            for i in 0..<path.count() {
                points.append(path.coordinate(at: i))
            }
        }
        return points
    }
    
    func sendTextMessage(_ text:String, to:String) {
        let ref = FIRDatabase.database().reference()
        let dateStr = dateFormatter.string(from: Date())
        let messageItem:[String:Any] = ["from" : currentUser()!.uid!,
                                        "to" : to,
                                        "text" : text,
                                        "date" : dateStr,
                                        "latitude" : LocationManager.shared.myLocation().latitude,
                                        "longitude" : LocationManager.shared.myLocation().longitude]
        ref.child("messages").childByAutoId().setValue(messageItem)
        if let toUser = getUser(to) {
            self.messagePush(text, to: toUser, from: currentUser()!)
        }
    }
    
    func sendTrackMessage(_ track:String, to:String) {
        let ref = FIRDatabase.database().reference()
        let dateStr = dateFormatter.string(from: Date())
        let messageItem:[String:Any] = ["from" : currentUser()!.uid!,
                                        "to" : to,
                                        "track" : track,
                                        "date" : dateStr,
                                        "latitude" : LocationManager.shared.myLocation().latitude,
                                        "longitude" : LocationManager.shared.myLocation().longitude]
        ref.child("messages").childByAutoId().setValue(messageItem)
        if let toUser = getUser(to) {
            self.messagePush("\(currentUser()!.name!) sent track.", to: toUser, from: currentUser()!)
        }
    }
    
    func sendImageMessage(_ image:UIImage, to:String, result:@escaping (NSError?) -> ()) {
        let toUser = getUser(to)
        if toUser == nil || currentUser() == nil {
            return
        }
        if let imageData = UIImageJPEGRepresentation(image, 0.5) {
            let meta = FIRStorageMetadata()
            meta.contentType = "image/jpeg"
            self.storageRef.child(generateUDID()).put(imageData, metadata: meta, completion: { metadata, error in
                if error != nil {
                    result(error as NSError?)
                } else {
                    let ref = FIRDatabase.database().reference()
                    let dateStr = self.dateFormatter.string(from: Date())
                    let messageItem:[String:Any] = ["from" : currentUser()!.uid!,
                                                    "to" : to,
                                                    "image" : metadata!.path!,
                                                    "date" : dateStr,
                                                    "latitude" : LocationManager.shared.myLocation().latitude,
                                                    "longitude" : LocationManager.shared.myLocation().longitude]
                    ref.child("messages").childByAutoId().setValue(messageItem)
                    self.messagePush("\(currentUser()!.name!) sent photo.", to: toUser!, from: currentUser()!)
                    result(nil)
                }
            })
        }
    }
    
    private func observeMessages() {
        let ref = FIRDatabase.database().reference()
        let messageQuery = ref.child("messages").queryLimited(toLast:25)
        
        newMessageRefHandle = messageQuery.observe(.childAdded, with: { (snapshot) -> Void in
            let messageData = snapshot.value as! [String:Any]
            if let from = messageData["from"] as? String, let to = messageData["to"] as? String {
                if currentUser() != nil && self.getMessage(snapshot.key) == nil {
                    let received = (to == currentUser()!.uid!)
                    let sended = (from == currentUser()!.uid!)
                    if received || sended {
                        let message = self.createMessage(snapshot.key)
                        message.setData(messageData, new: received, completion: {
                            if received {
                                message.setLocationData(messageData)
                            }
                            NotificationCenter.default.post(name: newMessageNotification, object: message)
                        })
                    }
                }
            } else {
                print("Error! Could not decode message data \(messageData)")
            }
        })
        
        deleteMessageRefHandle = messageQuery.observe(.childRemoved, with: { (snapshot) -> Void in
            if let message = self.getMessage(snapshot.key) {
                NotificationCenter.default.post(name: deleteMessageNotification, object: message)
                self.managedObjectContext.delete(message)
                self.saveContext()
            }
        })
    }
    
    func refreshMessages() {
        let ref = FIRDatabase.database().reference()
        ref.child("messages").queryOrdered(byChild: "date").observeSingleEvent(of: .value, with: { snapshot in
            if let values = snapshot.value as? [String:Any] {
                for (key, value) in values {
                    let messageData = value as! [String:Any]
                    if let from = messageData["from"] as? String, let to = messageData["to"] as? String {
                        if currentUser() != nil && self.getMessage(snapshot.key) == nil {
                            let received = (to == currentUser()!.uid!)
                            let sended = (from == currentUser()!.uid!)
                            if received || sended {
                                let message = self.createMessage(key)
                                message.setData(messageData, new: false, completion: {
                                    if received {
                                        message.setLocationData(messageData)
                                    }
                                    NotificationCenter.default.post(name: newMessageNotification, object: message)
                                })
                            }
                        }
                    } else {
                        print("Error! Could not decode message data \(messageData)")
                    }
                }
            }
        })
    }
    
    // MARK: - Coordinate table
    
    func setCoordinateForUser(_ coordinate:CLLocationCoordinate2D, at:Double, userID:String) {
        if let user = getUser(userID) {
            user.lastDate = at
            user.lastLatitude = coordinate.latitude
            user.lastLongitude = coordinate.longitude
            saveContext()
        }
    }
}
