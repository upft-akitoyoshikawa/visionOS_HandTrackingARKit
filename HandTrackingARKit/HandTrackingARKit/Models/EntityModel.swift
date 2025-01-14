//
//  EntityModel.swift
//  HandTrackingARKit
//
//  Created by akito.yoshikawa on 2025/01/14.
//

import ARKit
import RealityKit

@Observable
@MainActor
class EntityModel {

    let seession = ARKitSession()
    
    let handTracking = HandTrackingProvider()
    
    var contentEntity = Entity()
    
    func setupContentEntity() -> Entity {
        
        for chiality in [HandAnchor.Chirality.left, .right] {
            
            for jointName in HandSkeleton.JointName.allCases {
                
                let entity = ModelEntity(mesh: .generateSphere(radius: 0.005),
                                         materials: [UnlitMaterial(color: .cyan)],
                                         collisionShape: .generateSphere(radius: 0.005),
                                         mass: 0.0)
                entity.name = "\(jointName)\(chiality)"
                contentEntity.addChild(entity)
            }
        }
                
        return contentEntity
    }
    
    // ハンドトラッキングがサポートされているかどうか
    var handTrakingProviderSupported: Bool {
        HandTrackingProvider.isSupported
    }
    
    var isReadyToRun: Bool {
        handTracking.state == .initialized || handTracking.state == .paused
    }
    
    /// ARKitからハンドトラッキング情報を更新する
    func processHandUpdated() async {
        // 毎回呼ばれる
        for await update in handTracking.anchorUpdates {
            let handAnchor = update.anchor
            
            for jointName in HandSkeleton.JointName.allCases {
                guard let joint = handAnchor.handSkeleton?.joint(jointName),
                      let jointEntity = contentEntity.findEntity(named: "\(jointName)\(handAnchor.chirality)") else {
                    continue
                }
                
                let origin = handAnchor.originFromAnchorTransform * joint.anchorFromJointTransform
                jointEntity.setTransformMatrix(origin, relativeTo: nil)
            }
        }
    }
}
