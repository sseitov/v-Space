//
//  Cloud.swift
//  v-Space
//
//  Created by Сергей Сейтов on 23.04.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit
import CloudKit
import Photos
import GoogleMaps
import GooglePlaces

let photoNotification = Notification.Name("NEW_PHOTO")

@objc class Cloud: NSObject {
    
    static let shared = Cloud()
    
    var cloudDB: CKDatabase?
    
    private override init() {
        super.init()
        
        let container = CKContainer.default()
        cloudDB = container.privateCloudDatabase
    }

    // MARK: - Photos

    private func photoID(_ photos:[PHAsset], forDate:Double) -> String? {
        for photo in photos {
            let date = photo.creationDate!.timeIntervalSince1970
            if Int64(date) == Int64(forDate) {
                return photo.localIdentifier
            }
        }
        return nil
    }
    
    func syncTrackPhotos(_ track:Track) {
        
        let predicate = NSPredicate(format: "trackID = %@", track.uid!)
        let query = CKQuery(recordType: "Photo", predicate: predicate)
        
        cloudDB!.perform(query, inZoneWith: nil) { results, error in
            guard error == nil else {
                print(error!.localizedDescription)
                return
            }
            DispatchQueue.main.async {
                if results != nil {
                    for record in results! {
                        
                    }
                }
                NotificationCenter.default.post(name: photoNotification, object: nil)
            }
        }
    }

    // MARK: - Tracks

    func syncTracks(_ result:@escaping (String?) -> ()) {
       
        let localTracks = LocationManager.shared.allTracks()
        
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "Track", predicate: predicate)
        cloudDB!.perform(query, inZoneWith: nil) { results, error in
            guard error == nil else {
                DispatchQueue.main.async {
                    result("iCloud error: \(error!.localizedDescription)")
                }
                return
            }
            
            DispatchQueue.main.async {
                var cloudTracks:[Track] = []
                for record in results! {
                    if let uid = record.value(forKey: "uid") as? String,
                        let place = record.value(forKey: "place") as? String,
                        let path = record.value(forKey: "track") as? String,
                        let date = record.value(forKey: "date") as? Double,
                        let startDate = record.value(forKey: "startDate") as? Double,
                        let distance = record.value(forKey: "distance") as? Double
                    {
                        var track = LocationManager.shared.getTrack(uid)
                        if track == nil {
                            track = LocationManager.shared.saveTrack(uid, name: place, path: path, start: startDate, finish:date, distance: distance)
                            self.syncTrackPhotos(track!)
                        }
                        cloudTracks.append(track!)
                    }
                }
                for track in localTracks {
                    if !cloudTracks.contains(track) {
                        LocationManager.shared.managedObjectContext.delete(track)
                        LocationManager.shared.saveContext()
                    }
                }
                result(nil)
            }
        }
    }
    
    func saveTrack(_ track:Track, assets:[PHAsset]) {
        
        func saveTrackPhotos(_ photos:[Photo]) {
            for photo in photos {
                let record = CKRecord(recordType: "Photo")
                record.setValue(photo.date, forKey: "photoDate")
                record.setValue(photo.latitude, forKey: "latitude")
                record.setValue(photo.longitude, forKey: "longitude")
                record.setValue(photo.track!.uid!, forKey: "trackID")
                self.cloudDB!.save(record, completionHandler: { record, error in
                    if error != nil {
                        print(error!.localizedDescription)
                    }
                })
            }
        }
        
        let photos = LocationManager.shared.addPhotosIntoTrack(track, assets: assets)
        if photos.count > 0 {
            saveTrackPhotos(photos)
        }
        
        let record = CKRecord(recordType: "Track")
        record.setValue(track.path!, forKey: "track")
        record.setValue(track.place!, forKey: "place")
        record.setValue(track.finishDate!.timeIntervalSince1970, forKey: "date")
        record.setValue(track.startDate!.timeIntervalSince1970, forKey: "startDate")
        record.setValue(track.distance, forKey: "distance")
        record.setValue(track.uid!, forKey: "uid")
        self.cloudDB!.save(record, completionHandler: { record, error in
            if error != nil {
                print(error!.localizedDescription)
            }
        })
    }
    
    func deleteTrack(_ track:Track, complete:@escaping () -> ()) {
        
        func deleteTrackPhotos(_ trackID:String) {
            let predicate = NSPredicate(format: "trackID = %@", trackID)
            let query = CKQuery(recordType: "Photo", predicate: predicate)
            
            cloudDB!.perform(query, inZoneWith: nil) { results, error in
                guard error == nil else {
                    print(error!.localizedDescription)
                    return
                }
                if results != nil {
                    for record in results! {
                        self.cloudDB?.delete(withRecordID: record.recordID, completionHandler: { _, error in
                            print(error!.localizedDescription)
                        })
                    }
                }
            }
        }
        
        let predicate = NSPredicate(format: "uid = %@", track.uid!)
        let query = CKQuery(recordType: "Track", predicate: predicate)
        self.cloudDB!.perform(query, inZoneWith: nil) { results, error in
            guard error == nil else {
                DispatchQueue.main.async {
                    print(error!.localizedDescription)
                    complete()
                }
                return
            }
            
            DispatchQueue.main.async {
                
                deleteTrackPhotos(track.uid!)
                if let photos = track.photos?.allObjects as? [Photo] {
                    for photo in photos {
                        LocationManager.shared.managedObjectContext.delete(photo)
                    }
                }
                LocationManager.shared.managedObjectContext.delete(track)
                LocationManager.shared.saveContext()
                
                if let record = results!.first {
                    self.cloudDB?.delete(withRecordID: record.recordID, completionHandler: { _, error in
                        DispatchQueue.main.async {
                            if error != nil {
                                print(error!.localizedDescription)
                            }
                            complete()
                        }
                    })
                } else {
                    complete()
                }
            }
        }
    }

    // MARK: - Places

    func syncPlaces(_ result:@escaping (String?) -> ()) {
        
        let localPlaces = LocationManager.shared.allPlaces()
        
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "Place", predicate: predicate)
        cloudDB!.perform(query, inZoneWith: nil) { results, error in
            guard error == nil else {
                DispatchQueue.main.async {
                    result("iCloud error: \(error!.localizedDescription)")
                }
                return
            }
            
            DispatchQueue.main.async {
                var cloudPlaces:[Place] = []
                for record in results! {
                    if let placeID = record.value(forKey: "placeID") as? String,
                        let name = record.value(forKey: "name") as? String,
                        let latitude = record.value(forKey: "latitude") as? Double,
                        let longitude = record.value(forKey: "longitude") as? Double
                    {
                        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                        let phone = record.value(forKey: "phone") as? String
                        let address = record.value(forKey: "address") as? String
                        let website = record.value(forKey: "website") as? String
                        let url = website != nil ? URL(string: website!) : nil
                        let place = LocationManager.shared.createPlace(placeID,
                                                           name: name,
                                                           coordinate: coordinate,
                                                           phone: phone,
                                                           address: address,
                                                           website: url)
                        cloudPlaces.append(place)
                    }
                }
                for place in localPlaces {
                    if !cloudPlaces.contains(place) {
                        LocationManager.shared.managedObjectContext.delete(place)
                        LocationManager.shared.saveContext()
                    }
                }
                result(nil)
            }
        }
    }
    
    func savePlace(_ gmsPlace:GMSPlace, result:@escaping (String?) -> ()) {
        
        if LocationManager.shared.getPlace(gmsPlace.placeID) == nil {
            let place = LocationManager.shared.createPlace(gmsPlace.placeID,
                                               name: gmsPlace.name,
                                               coordinate: gmsPlace.coordinate,
                                               phone: gmsPlace.phoneNumber,
                                               address: gmsPlace.formattedAddress,
                                               website: gmsPlace.website)
            let record = CKRecord(recordType: "Place")
            record.setValue(place.placeID, forKey: "placeID")
            record.setValue(place.name, forKey: "name")
            record.setValue(place.latitude, forKey: "latitude")
            record.setValue(place.longitude, forKey: "longitude")
            if place.phone != nil {
                record.setValue(place.phone!, forKey: "phone")
            }
            if place.address != nil {
                record.setValue(place.address!, forKey: "address")
            }
            if place.website != nil {
                record.setValue(place.website!, forKey: "website")
            }
            self.cloudDB!.save(record, completionHandler: { record, error in
                DispatchQueue.main.async {
                    if let error = error {
                        result("iCloud error: \(error.localizedDescription)")
                    } else {
                        result(nil)
                    }
                }
            })
        } else {
            result("Place already synced.")
        }
    }
    
    func deletePlace(_ place:Place, complete:@escaping () -> ()) {
        
        let predicate = NSPredicate(format: "placeID = %@", place.placeID!)
        let query = CKQuery(recordType: "Place", predicate: predicate)
        self.cloudDB!.perform(query, inZoneWith: nil) { results, error in
            guard error == nil else {
                DispatchQueue.main.async {
                    print(error!.localizedDescription)
                    complete()
                }
                return
            }
            if let record = results!.first {
                self.cloudDB?.delete(withRecordID: record.recordID, completionHandler: { _, error in
                    DispatchQueue.main.async {
                        if error != nil {
                            print(error!.localizedDescription)
                        }
                        LocationManager.shared.managedObjectContext.delete(place)
                        LocationManager.shared.saveContext()
                        complete()
                    }
                })
            } else {
                DispatchQueue.main.async {
                    LocationManager.shared.managedObjectContext.delete(place)
                    LocationManager.shared.saveContext()
                    complete()
                }
            }
        }
    }
}
