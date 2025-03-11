//
//  ImmersiveView.swift
//  HandTrackingARKit
//
//  Created by akito.yoshikawa on 2025/01/14.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {

    @Environment(HandTrackingModel.self) var model
    
    var body: some View {
        RealityView { content in
            content.add(model.setupContentEntity())
        }
        .task {
            await model.startHandTracking()
        }
        .task {
            await model.processHandUpdated()
        }
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
