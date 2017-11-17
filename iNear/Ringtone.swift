//
//  Ringtone.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 06.03.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import Foundation
import AVFoundation

class Ringtone {
    
    static let shared = Ringtone()
    
    private var ringPlayer:AVAudioPlayer?
  
    private init() {
    }
    
    func playCall() {
        ringPlayer?.stop()
        
        try? AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, with:[.mixWithOthers])
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
        try? AVAudioSession.sharedInstance().setActive(true)

        ringPlayer = try? AVAudioPlayer(contentsOf: Bundle.main.url(forResource: "calling", withExtension: "wav")!)
        ringPlayer?.numberOfLoops = -1
        
        if ringPlayer!.prepareToPlay() {
            ringPlayer!.play()
        }
    }
    
    func playBusy() {
        ringPlayer?.stop()
        
        try? AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, with:[.mixWithOthers])
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
        try? AVAudioSession.sharedInstance().setActive(true)
        
        ringPlayer = try? AVAudioPlayer(contentsOf: Bundle.main.url(forResource: "busy", withExtension: "wav")!)
        ringPlayer?.numberOfLoops = -1
        
        if ringPlayer!.prepareToPlay() {
            ringPlayer!.play()
        }
    }

    func stop() {
        ringPlayer?.stop()
    }

}
