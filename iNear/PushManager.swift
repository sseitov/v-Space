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

class PushManager: NSObject {
    static let shared = PushManager()

    private override init() {
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
                "body" : "\(name) \("invite".localized)",
                "content_available": true]
            let data:[String:Any] = ["requester" : Auth.auth().currentUser!.uid, "command" : "invite"]
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
    
    func pushCommand(_ token:String, command:String, success: @escaping(Bool) -> ()) {
        let notification:[String:Any] = [
            "command" : command,
            "content_available": true]
        let data:[String:Any] = ["requester" : Auth.auth().currentUser!.uid, "command" : command]
        let message:[String:Any] = ["to" : token, "priority" : "high", "notification" : notification, "data" : data]
        httpManager.post("send", parameters: message, progress: nil, success: { task, response in
            success(true)
        }, failure: { task, error in
            print("SEND PUSH CALL ERROR: \(error)")
            success(false)
        })
    }
}
