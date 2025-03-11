//
//  ContentView.swift
//  HandTrackingARKit
//
//  Created by akito.yoshikawa on 2025/01/14.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    
    @Environment(HandTrackingModel.self) var model
    
    var body: some View {
        
        let handTrakingScreen = HandTrakingScreen.from(state: model)
        
        Group {
            
            switch handTrakingScreen {
                
            case .StartScreen:
                VStack {
                    Model3D(named: "Scene", bundle: realityKitContentBundle)
                        .padding(.bottom, 50)
                    
                    Text("Hello, world!")
                    
                    ToggleImmersiveSpaceButton()
                }
                .padding()
                
            case .HandTrackingScreen:
                // ハンドジェスチャーを表示
                HandGestureView(handGesture: model.handGesture)
            }
        }
    }
}

enum HandTrakingScreen {
    
    @MainActor static func from(state: HandTrackingModel) -> Self {
        if state.isPlaying {
            return .HandTrackingScreen
        } else {
            return .StartScreen
        }
    }
    
    case StartScreen
    case HandTrackingScreen
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
