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
    var latestHandTracking: HandsUpdates? = .init(left: nil, right: nil)

    struct HandsUpdates {
        var left: HandAnchor?
        var right: HandAnchor?
    }
    
    func setupContentEntity() -> Entity {
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
            
            switch update.event {
            case .updated:
                let anchor = update.anchor
                
                if anchor.chirality == .left {
                    latestHandTracking?.left = anchor
                    spawnSphereOnGunGesture(handAnchor: latestHandTracking?.left)
                } else if anchor.chirality == .right {
                    latestHandTracking?.right = anchor
                    spawnSphereOnGunGesture(handAnchor: latestHandTracking?.right)
                }
            default:
                break
                
            }
//            for jointName in HandSkeleton.JointName.allCases {
//                guard let joint = handAnchor.handSkeleton?.joint(jointName),
//                      let jointEntity = contentEntity.findEntity(named: "\(jointName)\(handAnchor.chirality)") else {
//                    continue
//                }
//                
//                let origin = handAnchor.originFromAnchorTransform * joint.anchorFromJointTransform
//                jointEntity.setTransformMatrix(origin, relativeTo: nil)
//            }
        }
    }
    
    func spawnSphereOnGunGesture(handAnchor: HandAnchor?) {
        guard let handAnchor = handAnchor,
        let handLocation = detectGunGestureTransform(handAnchor: handAnchor) else {
            return
        }
        
        // 球体のModelEntity
        let entity = ModelEntity(
            mesh: .generateSphere(radius: 0.05),
            materials: [SimpleMaterial(color: .white, isMetallic: true)],
            collisionShape: .generateSphere(radius: 0.05),
            mass: 1.0
        )
        
        // 球体を生成する位置
        entity.transform.translation = Transform(matrix: handLocation).translation + calculateTranslationOffset(handAnchor: handAnchor)
        // 球体を飛ばす方向
        let forceDirection = calculateForceDirection(handAnchor: handAnchor)
        entity.addForce(forceDirection * 300, relativeTo: nil)
        // 球体をcontentEntityの子として追加
        contentEntity.addChild(entity)
    }
    
    /// 銃を撃つポーズの計算
    func detectGunGestureTransform(handAnchor: HandAnchor?) -> simd_float4x4? {
        // TODO: コード解析
        
        guard let handAnchor = handAnchor else { return nil }
        guard
            let handThumbTip = handAnchor.handSkeleton?.joint(.thumbTip),
            let handIndexFingerKnuckle = handAnchor.handSkeleton?.joint(.indexFingerKnuckle),
            handThumbTip.isTracked &&
                handIndexFingerKnuckle.isTracked
        else {
            return nil
        }
        
        let originFromHandThumbTipTransform = matrix_multiply(
            handAnchor.originFromAnchorTransform, handThumbTip.anchorFromJointTransform
        ).columns.3.xyz
        
        let originFromHandIndexFingerKnuckleTransform = matrix_multiply(
            handAnchor.originFromAnchorTransform, handIndexFingerKnuckle.anchorFromJointTransform
        ).columns.3.xyz
        
        let thumbToIndexFingerDistance = distance(
            originFromHandThumbTipTransform,
            originFromHandIndexFingerKnuckleTransform
        )
        
        // 親指と人差し指の根本が接触しているか判断
        if thumbToIndexFingerDistance < 0.04 { // 接触していると見なす距離の閾値
            return handAnchor.originFromAnchorTransform
        } else {
            return nil
        }
    }
    
    /// 指の長さに相当するoffsetを定義
    func calculateTranslationOffset(handAnchor: HandAnchor) -> SIMD3<Float> {
        // TODO: コード解析
        let handRotation = Transform(matrix: handAnchor.originFromAnchorTransform).rotation
        return handRotation.act(handAnchor.chirality == .left ? SIMD3(0.25, 0, 0) : SIMD3(-0.25, 0, 0))
    }
    
    /// 手の向きに基づいて力を加える方向を計算
    func calculateForceDirection(handAnchor: HandAnchor) -> SIMD3<Float> {
        // TODO: コード解析
        let handRotation = Transform(matrix: handAnchor.originFromAnchorTransform).rotation
        return handRotation.act(handAnchor.chirality == .left ? SIMD3(1, 0, 0) : SIMD3(-1, 0, 0))
    }
}
