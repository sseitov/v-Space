//
//  CallController.swift
//  v-Space
//
//  Created by Сергей Сейтов on 16.11.2017.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit
import Firebase

class CallController: UIViewController {

    @IBOutlet weak var ringView: UIImageView!
    
    var userName:String?
    var userID:String?
    var callID:String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackButton()
        if userName != nil {
            setupTitle(userName!)
        }
        if callID == nil {
            var gifs:[UIImage] = []
            for i in 0..<24 {
                gifs.append(UIImage(named: "ring_frame_\(i).gif")!)
            }
            self.ringView.animationImages = gifs
            self.ringView.animationDuration = 2
            self.ringView.animationRepeatCount = 0
            self.ringView.startAnimating()
            
            if let name = Auth.auth().currentUser?.displayName {
                PushManager.shared.callRequest("TEST CALL ID", from: name, toID: userID!, success: { isSuccess in
                    if !isSuccess {
                        self.showMessage(LOCALIZE("requestError"), messageType: .error, messageHandler: {
                            self.goBack()
                        })
                    }
                })
            }
        }
    }

    override func goBack() {
        dismiss(animated: true, completion: nil)
    }
}
