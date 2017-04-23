//
//  UserInfo.swift
//  v-Space
//
//  Created by Сергей Сейтов on 23.04.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import Foundation
import CloudKit

class UserInfo {
    
    // MARK: - Properties
    let container: CKContainer
    var userRecordID: CKRecordID!
    var contacts: [AnyObject] = []
    
    // MARK: - Initializers
    init (container: CKContainer) {
        self.container = container;
    }
    
    func loggedInToICloud(_ completion: (_ accountStatus: CKAccountStatus, _ error: NSError?) -> ()) {
        // Capability not yet implemented.
        completion(.couldNotDetermine, nil)
    }
    
    func userID(_ completion: @escaping (_ userRecordID: CKRecordID?, _ error: NSError?)->()) {
        
        guard userRecordID != nil else {
            container.fetchUserRecordID() { recordID, error in
                
                if recordID != nil {
                    self.userRecordID = recordID
                }
                completion(recordID, error as NSError?)
            }
            return
        }
        completion(userRecordID, nil)
    }
    
    func userInfo(_ recordID: CKRecordID!, completion:(_ userInfo: CKUserIdentity?, _ error: NSError?)->()) {
        // Capability not yet implemented.
        completion(nil, nil)
    }
    
    func requestDiscoverability(_ completion: (_ discoverable: Bool) -> ()) {
        // Capability not yet implemented.
        completion(false)
    }
    
    func userInfo(_ completion: @escaping (_ userInfo: CKUserIdentity?, _ error: NSError?)->()) {
        
        requestDiscoverability() { discoverable in
            self.userID() { [weak self] recordID, error in
                
                guard error != nil else {
                    self?.userInfo(recordID, completion: completion)
                    return
                }
                completion(nil, error)
            }
        }
    }
    
    func findContacts(_ completion: (_ userInfos:[AnyObject]?, _ error: NSError?)->()) {
        completion([CKRecordID](), nil)
    }
}
