//
//  Model.swift
//  iNear
//
//  Created by Сергей Сейтов on 01.03.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit
import CoreData
import Photos
import MapKit

// MARK: - Date formatter

func dateFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
    return formatter
}

func textDateFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    formatter.doesRelativeDateFormatting = true
    return formatter
}

func textShortDateFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .none
    formatter.doesRelativeDateFormatting = true
    return formatter
}

func textYearFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    formatter.timeStyle = .none
    return formatter
}

func textTimeFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter
}

let newPointNotification = Notification.Name("NEW_POINT")
let newPlaceNotification = Notification.Name("NEW_PLACE")


class Model: NSObject {
    
    static let shared = Model()

    // MARK: - CoreData stack
    
    lazy var sharedDocumentsDirectory: URL = {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.vchannel.iNearby")!
    }()
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        let modelURL = Bundle.main.url(forResource: "LocationModel", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.sharedDocumentsDirectory.appendingPathComponent("LocationModel.sqlite")
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
    
    // MARK: - Location table
    
    func addCoordinate(_ coordinate:CLLocationCoordinate2D, at:Double) {
        let point = NSEntityDescription.insertNewObject(forEntityName: "Location", into: managedObjectContext) as! Location
        point.date = at
        point.latitude = coordinate.latitude
        point.longitude = coordinate.longitude
        NotificationCenter.default.post(name: newPointNotification, object: nil)
        saveContext()
    }

    func lastLocation() -> CLLocationCoordinate2D {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Location")
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchRequest.fetchLimit = 1
        if let all = try? managedObjectContext.fetch(fetchRequest) as! [Location], let location = all.first {
            return CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        } else {
            return CLLocationCoordinate2D()
        }
    }
    
    func lastLocationDate(first:Bool = false) -> Date? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Location")
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: first)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchRequest.fetchLimit = 1
        if let all = try? managedObjectContext.fetch(fetchRequest) as! [Location], let location = all.first {
            return Date(timeIntervalSince1970: location.date)
        } else {
            return nil
        }
    }

    func lastTrack() -> [Location]? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Location")
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        return try? managedObjectContext.fetch(fetchRequest) as! [Location]
    }

    func lastTrackDistance() -> Double {
        if let track = lastTrack(), track.count > 1 {
            var distance:Double = 0
            for i in 1..<track.count {
                let prev = track[i-1]
                let curr = track[i]
  
                let pt1 = MKMapPointForCoordinate(CLLocationCoordinate2D(latitude: prev.latitude, longitude: prev.longitude))
                let pt2 = MKMapPointForCoordinate(CLLocationCoordinate2D(latitude: curr.latitude, longitude: curr.longitude))
                distance += MKMetersBetweenMapPoints(pt1, pt2)
            }
            return distance / 1000.0
        } else {
            return 0
        }
    }
    
    func lastTrackSpeed() -> Double {
        if let track = lastTrack(), track.count > 1, let last = track.first, let first = track.last {
            let distance = lastTrackDistance()
            if distance < 0.01 {
                return 0
            } else {
                let time = (last.date - first.date) / (60*60)
                return distance / time
            }
        } else {
            return 0
        }
    }
    
    func clearLastTrack() {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Location")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        _ = try? persistentStoreCoordinator.execute(deleteRequest, with: managedObjectContext)
    }
    
    func lastTrackSize(_ uid:String? = nil) -> Int {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Location")
        if let count = try? managedObjectContext.count(for: fetchRequest) {
            return count
        } else {
            return 0
        }
    }
    
    func trackerIsRunning() -> Bool {
        if let track = lastTrack(), track.count > 0 {
            return true
        } else {
            return false
        }
    }
    
    // MARK: - Track table

    func getTrack(_ uid:String) -> Track? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Track")
        fetchRequest.predicate = NSPredicate(format: "uid = %@", uid)
        do {
            return try managedObjectContext.fetch(fetchRequest).first as? Track
        } catch {
            return nil
        }
    }
 
    func saveTrack(_ uid:String, name:String, path:String, start:Double, finish:Double, distance:Double) -> Track {
        let track = NSEntityDescription.insertNewObject(forEntityName: "Track", into: managedObjectContext) as! Track
        track.uid = uid
        track.synced = true
        track.place = name
        track.path = path
        track.startDate = NSDate(timeIntervalSince1970: start)
        track.finishDate = NSDate(timeIntervalSince1970: finish)
        saveContext()
        return track
    }
   
    func createTrack(_ name:String, path:String, start:Double, finish:Double, distance: Double) -> Track {
        let track = NSEntityDescription.insertNewObject(forEntityName: "Track", into: managedObjectContext) as! Track
        track.uid = UUID().uuidString
        track.synced = false
        track.place = name
        track.path = path
        track.startDate = NSDate(timeIntervalSince1970: start)
        track.finishDate = NSDate(timeIntervalSince1970: finish)
        track.distance = distance
        saveContext()
        return track
    }
    
    func allTracks() -> [Track] {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Track")
        let sortDescriptor = NSSortDescriptor(key: "finishDate", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        if let all = try? managedObjectContext.fetch(fetchRequest) as! [Track] {
            return all
        } else {
            return []
        }
    }
    
    func unsyncedTracks() -> [Track] {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Track")
        fetchRequest.predicate = NSPredicate(format: "synced == %@", NSNumber(booleanLiteral: false))
        if let all = try? managedObjectContext.fetch(fetchRequest) as! [Track] {
            return all
        } else {
            return []
        }
    }
    
    // MARK: - Place table
    
    func getPlace(_ uid:String) -> Place? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Place")
        fetchRequest.predicate = NSPredicate(format: "placeID = %@", uid)
        do {
            return try managedObjectContext.fetch(fetchRequest).first as? Place
        } catch {
            return nil
        }
    }
    
    func createPlace(_ placeID:String, name:String, coordinate:CLLocationCoordinate2D, phone:String?, address:String?, website:URL?) -> Place? {
        var place = getPlace(placeID)
        if place == nil {
            place = NSEntityDescription.insertNewObject(forEntityName: "Place", into: managedObjectContext) as? Place
            place?.placeID = placeID
            place?.synced = false
            place?.name = name
            place?.latitude = coordinate.latitude
            place?.longitude = coordinate.longitude
            place?.phone = phone
            place?.address = address
            if website != nil {
                place?.website = website!.absoluteString
            }
            saveContext()
            return place
        } else {
            return place
        }
    }
    
    func allPlaces() -> [Place] {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Place")
        let sortDescriptor = NSSortDescriptor(key: "name", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        if let all = try? managedObjectContext.fetch(fetchRequest) as! [Place] {
            return all
        } else {
            return []
        }
    }
    
    func unsyncedPlaces() -> [Place] {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Place")
        fetchRequest.predicate = NSPredicate(format: "synced == %@", NSNumber(booleanLiteral: false))
        if let all = try? managedObjectContext.fetch(fetchRequest) as! [Place] {
            return all
        } else {
            return []
        }
    }

    // MARK: - Photo table

    func getPhoto(_ uid:String) -> Photo? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Photo")
        fetchRequest.predicate = NSPredicate(format: "uid = %@", uid)
        do {
            return try managedObjectContext.fetch(fetchRequest).first as? Photo
        } catch {
            return nil
        }
    }
  
    func addPhotosIntoTrack(_ track:Track, assets:[PHAsset]) {
        var newPhotos:[Photo] = []
        for asset in assets {
            var photo = getPhoto(asset.localIdentifier)
            if photo == nil {
                photo = NSEntityDescription.insertNewObject(forEntityName: "Photo", into: managedObjectContext) as? Photo
                photo!.uid = asset.localIdentifier
                photo!.date = asset.creationDate!.timeIntervalSince1970
                photo!.latitude = asset.location!.coordinate.latitude
                photo!.longitude = asset.location!.coordinate.longitude
                photo!.track = track
                photo!.synced = false
                track.addToPhotos(photo!)
                newPhotos.append(photo!)
            }
        }
        saveContext()
    }
    
    func deletePhotosFromTrack(_ track:Track, photos:[Photo], result: @escaping(Error?) -> ()) {
        var uids:[String] = []
        for photo in photos {
            uids.append(photo.uid!)
        }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: uids, options: nil)
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assets)
        }, completionHandler: { success, error in
            DispatchQueue.main.async {
                if error == nil {
                    for photo in photos {
                        track.removeFromPhotos(photo)
                        Model.shared.managedObjectContext.delete(photo)
                    }
                    Model.shared.saveContext()
                }
                result(error)
            }
        })
    }
}
