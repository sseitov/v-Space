//
//  TrackListController.swift
//  v-Space
//
//  Created by Сергей Сейтов on 28.03.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit
import Photos

class TrackListController: UITableViewController, LastTrackCellDelegate {

    var tracks:[Track] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTitle("My Tracks")
        tracks = LocationManager.shared.allTracks()
    }
    
    @IBAction func refresh(_ sender: UIRefreshControl) {
        self.tracks = LocationManager.shared.allTracks()
        let nextConfition = NSCondition()
        DispatchQueue.global().async {
            for track in self.tracks {
                DispatchQueue.main.async {
                    self.putPhotoOnTrack(track, success: { success in
                        nextConfition.lock()
                        nextConfition.signal()
                        nextConfition.unlock()
                    })
                }
                nextConfition.lock()
                nextConfition.wait()
                nextConfition.unlock()
            }
            DispatchQueue.main.async {
                self.tableView.reloadData()
                sender.endRefreshing()
            }
        }
        
//        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5, execute: {
//        })
    }
    
    func saveLastTrack() {
        let ask = TextInput.create(cancelHandler: {
            LocationManager.shared.clearLastTrack()
        }, acceptHandler: { name in
            let track = LocationManager.shared.createTrack(name)
            self.putPhotoOnTrack(track, success: { success in
                self.tableView.beginUpdates()
                self.tracks.insert(track, at: 0)
                self.tableView.insertRows(at: [IndexPath(row: 0, section: 1)], with: .bottom)
                self.tableView.endUpdates()
            })
        })
        ask?.show()
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
            let startDate = track!.trackDate(false)
            let finishDate = track!.trackDate(true)
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
            tableView.beginUpdates()
            let track = tracks[indexPath.row]
            LocationManager.shared.deleteTrack(track)
            tracks.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .top)
            tableView.endUpdates()
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
        let nav = segue.destination as! UINavigationController
        let controller = nav.topViewController as! TrackController
        controller.track = sender as? Track
    }

}
