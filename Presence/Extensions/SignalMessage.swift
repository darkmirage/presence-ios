//
//  SignalMessage.swift
//  Presence
//
//  Created by Raven Jiang on 6/28/20.
//  Copyright © 2020 Apple. All rights reserved.
//

import Foundation
import WebRTC
import HandyJSON

struct Offer: HandyJSON {
    var sdp: String!
    var type: String! = "offer"
    
    init() {}
    
    init(rtcSdp: RTCSessionDescription) {
        self.sdp = rtcSdp.sdp
    }
}

struct SignalMessage: HandyJSON {
    var channelId: String?
    var offer: Offer!
}

struct IceCandidate: HandyJSON {
    let candidate: String
    let sdpMLineIndex: Int32
    let sdpMid: String?
    
    init() {
        fatalError("Not supported")
    }
    
    init(from dict: NSDictionary) {
        self.sdpMLineIndex = dict["sdpMLineIndex"] as! Int32
        self.sdpMid = dict["sdpMid"] as! String?
        self.candidate = dict["candidate"] as! String
    }
    
    init(from iceCandidate: RTCIceCandidate) {
        self.sdpMLineIndex = iceCandidate.sdpMLineIndex
        self.sdpMid = iceCandidate.sdpMid
        self.candidate = iceCandidate.sdp
    }
    
    var rtcIceCandidate: RTCIceCandidate {
        return RTCIceCandidate(sdp: self.candidate, sdpMLineIndex: self.sdpMLineIndex, sdpMid: self.sdpMid)
    }
}
