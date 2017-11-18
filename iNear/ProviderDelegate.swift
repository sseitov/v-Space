//
//  ProviderDelegate.swift
//  v-Space
//
//  Created by Сергей Сейтов on 17.11.2017.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import CallKit

class ProviderDelegate: NSObject {
    
    fileprivate let callManager: CallManager
    fileprivate let provider: CXProvider
    
    fileprivate var rejected:Bool = true
    fileprivate var activeCall:Call?
    
    init(callManager: CallManager) {
        self.callManager = callManager
        provider = CXProvider(configuration: type(of: self).providerConfiguration)
        
        super.init()
        provider.setDelegate(self, queue: nil)
    }
    
    static var providerConfiguration: CXProviderConfiguration {
        let providerConfiguration = CXProviderConfiguration(localizedName: "v-Space")
        
        providerConfiguration.supportsVideo = true
        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.maximumCallGroups = 1
        providerConfiguration.supportedHandleTypes = [.generic]
        if let iconMaskImage = UIImage(named: "provider") {
            providerConfiguration.iconTemplateImageData = UIImagePNGRepresentation(iconMaskImage)
        }

        return providerConfiguration
    }
    
    func reportIncomingCall(callID:String, userName: String, userID:String, completion: ((NSError?) -> Void)?) {
        
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: userName)
        update.hasVideo = true
        update.supportsHolding = false
        update.localizedCallerName = userName
        
        rejected = true
        
        let uuid = UUID(uuidString: callID)
        provider.reportNewIncomingCall(with: uuid!, update: update) { error in
            if error == nil {
                self.activeCall = Call(callID: callID, userID: userID, userName: userName)
                self.callManager.add(call: self.activeCall!)
            }
            
            completion?(error as NSError?)
        }
    }
    
    func closeIncomingCall() {
        if activeCall != nil {
            rejected = false
            callManager.end(call: activeCall!)
            activeCall = nil
        }
    }

}

// MARK: - CXProviderDelegate

extension ProviderDelegate: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        
        for call in callManager.calls {
            call.end()
        }
        callManager.removeAllCalls()
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        guard let call = callManager.callWithUUID(uuid: action.callUUID) else {
            action.fail()
            return
        }
        activeCall = call
        call.answer()
        action.fulfill()
        PushManager.shared.pushCommand(call.userID, command: "accept", success: { isSuccess in
            if isSuccess {
                ShowCall(userName: call.userName, userID: call.userID, callID: call.callID)
            } else {
                self.rejected = true
                self.callManager.end(call: call)
            }
        })
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        guard let call = callManager.callWithUUID(uuid: action.callUUID) else {
            action.fail()
            return
        }
        
        if rejected {
            PushManager.shared.pushCommand(call.userID, command: "hangup", success: { _ in
                call.end()
                action.fulfill()
                self.callManager.remove(call: call)
            })
        } else {
            call.end()
            action.fulfill()
            callManager.remove(call: call)
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        guard let call = callManager.callWithUUID(uuid: action.callUUID) else {
            action.fail()
            return
        }
        
        call.state = action.isOnHold ? .held : .active
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
    }
}
