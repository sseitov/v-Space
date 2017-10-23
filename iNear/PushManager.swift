//
//  PushManager.swift
//  v-Space
//
//  Created by Сергей Сейтов on 22.10.2017.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit
import AFNetworking
import Firebase

enum PushType:Int {
    case unknown = 0
    case invite = 1
    case askLocation = 2
}

class PushManager: NSObject {
    static let shared = PushManager()

    override init() {
        super.init()
    }
    
    fileprivate lazy var httpManager:AFHTTPSessionManager = {
        let manager = AFHTTPSessionManager(baseURL: URL(string: "https://fcm.googleapis.com/fcm/"))
        manager.requestSerializer = AFJSONRequestSerializer()
        manager.requestSerializer.setValue("application/json", forHTTPHeaderField: "Content-Type")
        manager.requestSerializer.setValue("key=\(pushServerKey)", forHTTPHeaderField: "Authorization")
        manager.responseSerializer = AFHTTPResponseSerializer()
        return manager
    }()

    func pushInvite(_ token:String, success: @escaping(Bool) -> ()) {
        if let name = Auth.auth().currentUser?.displayName {
            let notification:[String:Any] = [
                "title" : "v-Space",
                "sound" : "default",
                "body" : "\(name) \(LOCALIZE("invite"))",
                "content_available": true]
            let data:[String:Any] = ["pushType" : PushType.invite.rawValue, "requester" : Auth.auth().currentUser!.uid]
            let message:[String:Any] = ["to" : token, "priority" : "high", "notification" : notification, "data" : data]
            httpManager.post("send", parameters: message, progress: nil, success: { task, response in
                success(true)
            }, failure: { task, error in
                print("SEND PUSH CALL ERROR: \(error)")
                success(false)
            })
        } else {
            success(false)
        }
    }
    
    func askLocation(_ token:String) {
        if let name = Auth.auth().currentUser?.displayName {
            let notification:[String:Any] = [
                "title" : "v-Space",
                "sound" : "default",
                "body" : "\(name) \(LOCALIZE("askLocation"))",
                "content_available": true]
            let data:[String:Any] = ["pushType" : PushType.askLocation.rawValue]
            let message:[String:Any] = ["to" : token, "priority" : "high", "notification" : notification, "data" : data]
            httpManager.post("send", parameters: message, progress: nil, success: { task, response in
                print("SUCCESS")
            }, failure: { task, error in
                print("SEND PUSH CALL ERROR: \(error)")
            })
        }
    }
}