//
//  TrackListController.swift
//  v-Space
//
//  Created by Сергей Сейтов on 28.03.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit
import Photos
import SVProgressHUD
import GoogleMaps
import GooglePlaces
import GooglePlacePicker

class TrackListController: UITableViewController, LastTrackCellDelegate {

    var tracks:[Track] = []
    
    private func IS_PAD() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTitle("My Tracks")
        tracks = LocationManager.shared.allTracks()
        if IS_PAD() {
            if tracks.count > 0 {
                performSegue(withIdentifier: "showDetail", sender: tracks[0])
            } else {
                performSegue(withIdentifier: "showDetail", sender: nil)
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.refreshCurrentTrack), name: newPointNotification, object: nil)
    }
    
    func refreshCurrentTrack() {
        let indexPath = IndexPath(row: 0, section: 0)
        tableView.reloadRows(at: [indexPath], with: .fade)
    }
    
    @IBAction func refresh() {
        if PHPhotoLibrary.authorizationStatus() != .authorized {
            PHPhotoLibrary.requestAuthorization({ status in
                DispatchQueue.main.async {
                    if status == .authorized {
                        SVProgressHUD.show(withStatus: "Sync...")
                        self.syncTracks({ error in
                            SVProgressHUD.dismiss()
                            if error != nil {
                                self.showMessage(error!.localizedDescription, messageType: .error)
                            } else {
                                self.finishSync()
                            }
                        })
                    } else {
                        self.showMessage(NSLocalizedString("photoLibrary", comment: ""), messageType: .error)
                    }
                }
            })
        } else {
            SVProgressHUD.show(withStatus: "Sync...")
            self.syncTracks({ error in
                SVProgressHUD.dismiss()
                if error != nil {
                    self.showMessage(error!.localizedDescription, messageType: .error)
                } else {
                    self.finishSync()
                }
            })
        }
    }

    func finishSync() {
        tracks = LocationManager.shared.allTracks()
        tableView.reloadData()
        if IS_PAD() {
            if tracks.count > 0 {
                performSegue(withIdentifier: "showDetail", sender: tracks[0])
            } else {
                performSegue(withIdentifier: "showDetail", sender: nil)
            }
        }
    }
    
    func syncTracks(_ error:@escaping (NSError?) -> ()) {
        let syncedResult = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumMyPhotoStream, options: nil)
        if syncedResult.count > 0 {
            let collection = syncedResult.object(at: 0)
            let options = PHFetchOptions()
            options.sortDescriptors = [ NSSortDescriptor(key: "creationDate", ascending: false) ]
            let fetchResult = PHAsset.fetchAssets(in: collection, options: options)
            var assets:[PHAsset] = []
            fetchResult.enumerateObjects({ asset, index, _ in
                assets.append(asset)
            })
            DispatchQueue.main.async {
                if assets.count == 0 {
                    error(cloudError(NSLocalizedString("photoCount", comment: "")))
                } else {
                    Cloud.shared.syncTracks(assets, error: { err in
                        error(err)
                    })
                }
            }
        } else {
            error(cloudError(NSLocalizedString("photoStream", comment: "")))
        }
    }
    
    func saveLastTrack() {
        if let points = LocationManager.shared.lastTrack() {
            if points.count < 2 {
                LocationManager.shared.clearLastTrack()
                return
            }
            let path = GMSMutablePath()
            for pt in points {
                path.add(CLLocationCoordinate2D(latitude: pt.latitude, longitude: pt.longitude))
            }
            let ask = TextInput.create(cancelHandler: {
                LocationManager.shared.clearLastTrack()
            }, acceptHandler: { name in
                let track = LocationManager.shared.createTrack(name, path: path.encodedPath(), start: points.last!.date, finish: points.first!.date)
                LocationManager.shared.clearLastTrack()
                self.putPhotoOnTrack(track, success: { success in
                    if success {
                        Cloud.shared.putTrack(track)
                        self.tableView.beginUpdates()
                        self.tracks.insert(track, at: 0)
                        self.tableView.insertRows(at: [IndexPath(row: 0, section: 1)], with: .bottom)
                        self.tableView.endUpdates()
                    } else {
                        self.showMessage(NSLocalizedString("photoLibrary", comment: ""), messageType: .error)
                    }
                })
            })
            ask?.show()
        }

    }

    func putPhotoOnTrack(_ track:Track?, success:@escaping (Bool) -> ()) {
        if PHPhotoLibrary.authorizationStatus() != .authorized {
            PHPhotoLibrary.requestAuthorization({ status in
                DispatchQueue.main.async {
                    if status == .authorized {
                        self.scanCameraRollForTrack(track)
                        success(true)
                    } else {
                        success(false)
                    }
                }
            })
        } else {
            self.scanCameraRollForTrack(track)
            success(true)
        }
    }
    
    func scanCameraRollForTrack(_ track:Track?) {
        let syncedResult = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil)
        if syncedResult.count > 0 {
            let collection = syncedResult.object(at: 0)
            let options = PHFetchOptions()
            options.sortDescriptors = [ NSSortDescriptor(key: "creationDate", ascending: false) ]
            let startDate = track!.startDate! as Date
            let finishDate = track!.finishDate! as Date
            options.predicate = NSPredicate(format: "creationDate > %@ AND creationDate < %@",
                                            startDate as CVarArg, finishDate as CVarArg)
            let fetchResult = PHAsset.fetchAssets(in: collection, options: options)
            var assets:[PHAsset] = []
            fetchResult.enumerateObjects({ asset, index, _ in
                assets.append(asset)
            })
            LocationManager.shared.addPhotos(assets, into: track)
        }
    }
    
    @IBAction func nearByMe(_ sender: Any) {
        SVProgressHUD.show(withStatus: "Get location...")
        LocationManager.shared.getCurrentLocation({ location in
            SVProgressHUD.dismiss()
            if location != nil {
                let center = location!.coordinate
                let northEast = CLLocationCoordinate2D(latitude: center.latitude + 0.1, longitude: center.longitude + 0.1)
                let southWest = CLLocationCoordinate2D(latitude: center.latitude - 0.1, longitude: center.longitude - 0.1)
                let viewport = GMSCoordinateBounds(coordinate: northEast, coordinate: southWest)
                let config = GMSPlacePickerConfig(viewport: viewport)
                let placePicker = GMSPlacePicker(config: config)
                
                placePicker.pickPlace(callback: {(place, error) -> Void in
                    if let error = error {
                        print("Pick Place error: \(error.localizedDescription)")
                        return
                    }
                    
                    if let place = place {
                        self.performSegue(withIdentifier: "placeInfo", sender: place)
                    }
                })
            } else {
                self.showMessage("Can not get current location", messageType: .error)
            }
        })
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 1 : tracks.count
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.section == 0 ? 60 : 80
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "current track" : "saved tracks"
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "lastTrack", for: indexPath) as! LastTrackCell
            cell.delegate = self
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "savedTrack", for: indexPath) as! SavedTrackCell
            cell.track = tracks[indexPath.row]
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return (indexPath.section > 0)
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let track = tracks[indexPath.row]
            SVProgressHUD.show(withStatus: "Delete...")
            Cloud.shared.deleteTrack(track, complete: {
                SVProgressHUD.dismiss()
                self.tableView.beginUpdates()
                self.tracks.remove(at: indexPath.row)
                self.tableView.deleteRows(at: [indexPath], with: .top)
                self.tableView.endUpdates()
            })
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0  {
            if LocationManager.shared.lastTrackSize() > 1 {
                performSegue(withIdentifier: "showDetail", sender: nil)
            }
        } else {
            performSegue(withIdentifier: "showDetail", sender: tracks[indexPath.row])
        }
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            let nav = segue.destination as! UINavigationController
            let controller = nav.topViewController as! TrackController
            controller.track = sender as? Track
        } else if segue.identifier == "placeInfo" {
            let controller = segue.destination as! PlaceInfoController
            controller.place = sender as? GMSPlace
            controller.myCoordinate = LocationManager.shared.currentLocation?.coordinate
        }
    }

}
