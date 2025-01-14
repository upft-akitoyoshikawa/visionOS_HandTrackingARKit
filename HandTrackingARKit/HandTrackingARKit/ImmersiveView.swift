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

    @Environment(EntityModel.self) var model
    
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    
    var body: some View {
        RealityView { content in
            content.add(model.setupContentEntity())
        }
        .task {
            do {
                if model.handTrakingProviderSupported && model.isReadyToRun {
                    try await model.seession.run([model.handTracking])
                } else {
                    await dismissImmersiveSpace()
                }
            } catch {
                print("session run 失敗: \(error)")
                await dismissImmersiveSpace()
            }
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
