//
//  HandGesture.swift
//  HandTrackingARKit
//
//  Created by akito.yoshikawa on 2025/02/12.
//

// ハンドジェスチャーの種類
enum HandGestureType {
    case None, Hand, ThumbsUp
    
    var displayName: String {
        switch self {
        case .None: return "No Gesture"
        case .Hand: return "Open Hand ✋"
        case .ThumbsUp: return "Thumbs Up 👍"
        }
    }
    
    var iconName: String {
        switch self {
        case .None: return "hand.raised.slash"
        case .Hand: return "hand.raised.fill"
        case .ThumbsUp: return "hand.thumbsup.fill"
        }
    }
}
