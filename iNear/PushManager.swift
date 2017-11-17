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
import AWSSNS

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
            let data:[String:Any] = ["requester" : Auth.auth().currentUser!.uid]
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
    
    func pushCommand(_ uid:String, command:String, success: @escaping(Bool) -> ()) {
        AuthModel.shared.userEndpoint(uid, endpoint: { point in
            if point != nil {
                let message = AWSSNSPublishInput()
                message?.targetArn = point!
                message?.message = command
                AWSSNS.default().publish(message!).continueOnSuccessWith(executor: AWSExecutor.mainThread(), block: { task in
                    if task.error != nil {
                        print(task.error!.localizedDescription)
                    }
                    success(true)
                    return nil
                })
            } else {
                success(false)
            }
        })
    }
    
    func callRequest(_ callID:String, toID:String, success: @escaping(Bool) -> ()) {
        AuthModel.shared.userEndpoint(toID, endpoint: { point in
            if point != nil {
                let message = AWSSNSPublishInput()
                message?.targetArn = point!
                let name = Auth.auth().currentUser!.displayName != nil ? Auth.auth().currentUser!.displayName! : "anonymous"
                let request = ["callID" : callID, "userID" : Auth.auth().currentUser!.uid, "userName" : name]
                if let data = try? JSONSerialization.data(withJSONObject: request, options: []) {
                    message?.message = String(data: data, encoding:.utf8)
                    AWSSNS.default().publish(message!).continueOnSuccessWith(executor: AWSExecutor.mainThread(), block: { task in
                        if task.error != nil {
                            print(task.error!.localizedDescription)
                        }
                        success(true)
                        return nil
                    })
                } else {
                    success(false)
                }
            } else {
                success(false)
            }
        })
    }
}
