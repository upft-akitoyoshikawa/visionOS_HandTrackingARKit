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
    
    // 前回の手の位置を保持するプロパティ
    var previousHandPosition: SIMD3<Float>? = nil
    
    let noiseThreshold: Double = 0.005
    
    private var counter = 0
    
    private let checkInterval = 50
    
    func spawnSphereOnGunGesture(handAnchor: HandAnchor?) {
        guard let handAnchor = handAnchor,
        let handLocation = detectOpenHandGestureTransform(handAnchor: handAnchor) else {
            return
        }
        
        let currentHandPosition = SIMD3<Float>(handLocation.columns.3.x,
                                               handLocation.columns.3.y,
                                               handLocation.columns.3.z)
        
        if previousHandPosition == nil {
            previousHandPosition = currentHandPosition
            counter = 0
            return
        }
        counter += 1  // カウンターを増やす
        
        if counter >= self.checkInterval {
            if let previousHandPosition = previousHandPosition {
                 let deltaX = Double(currentHandPosition.x) - Double(previousHandPosition.x)
                 
                 print("currentHandPosition.x: \(currentHandPosition.x)")
                 print("previousHandPosition.x: \(previousHandPosition.x)")
                 print("deltaX: \(deltaX)")
                 
                 // 差分がノイズ閾値より大きい場合、手を振ったと判定
                 if abs(deltaX) > noiseThreshold {
                     print("手を振った動作を検知しました！")
                 }
             }
             
             // カウンターと前回の位置をリセット
             self.previousHandPosition = currentHandPosition
             counter = 0
        }
        
        // 前回の手の位置が存在する場合、X軸の差分をチェック
//        if let previousHandPosition = previousHandPosition {
//            
//            
//            let deltaX = Double(currentHandPosition.x) - Double(previousHandPosition.x)
//            
//            print("currentHandPosition.x: \(currentHandPosition.x)")
//            print("previousHandPosition.x: \(previousHandPosition.x)")
//
//            print("deltaX: \(deltaX)")
//            
//            // ノイズ（微小な動き）を無視
//            if abs(deltaX) < noiseThreshold {
//                return
//            }
//        }
        
        // 現在の位置を前回の位置として保持
        previousHandPosition = currentHandPosition
        
//        // 球体のModelEntity
//        let entity = ModelEntity(
//            mesh: .generateSphere(radius: 0.05),
//            materials: [SimpleMaterial(color: .white, isMetallic: true)],
//            collisionShape: .generateSphere(radius: 0.05),
//            mass: 1.0
//        )
//        
//        // 球体を生成する位置
//        entity.transform.translation = Transform(matrix: handLocation).translation + calculateTranslationOffset(handAnchor: handAnchor)
//        // 球体を飛ばす方向
//        let forceDirection = calculateForceDirection(handAnchor: handAnchor)
//        entity.addForce(forceDirection * 300, relativeTo: nil)
//        // 球体をcontentEntityの子として追加
//        contentEntity.addChild(entity)
    }
    
    /// 手をパーに広げるジェスチャーを検出する
    func detectOpenHandGestureTransform(handAnchor: HandAnchor?) -> simd_float4x4? {
        
        guard let handAnchor = handAnchor else { return nil }
                
        // 3(親指), 7(人差し指), 12(中指), 17(薬指), 23(小指)
        guard
            // 3(親指)
            let handThumbIntermediateTip = handAnchor.handSkeleton?.joint(.thumbIntermediateTip),
            // 7(人差し指)
            let handIndexFingerIntermediateBase = handAnchor.handSkeleton?.joint(.indexFingerIntermediateBase),
            // 12(中指)
            let handMiddleFingerIntermediateBase = handAnchor.handSkeleton?.joint(.middleFingerIntermediateBase),
            // 17(薬指)
            let handRingFingerIntermediateBase = handAnchor.handSkeleton?.joint(.ringFingerIntermediateBase),
            // 23(小指)
            let handLittleFingerIntermediateTip = handAnchor.handSkeleton?.joint(.littleFingerIntermediateTip),
            // すべての指がトラッキングされているかどうか
                handThumbIntermediateTip.isTracked &&
                handIndexFingerIntermediateBase.isTracked &&
                handMiddleFingerIntermediateBase.isTracked &&
                handRingFingerIntermediateBase.isTracked &&
                handLittleFingerIntermediateTip.isTracked
        else {
            return nil
        }
        
        // 親指
        let originFromhandThumbIntermediateTipTransform = matrix_multiply(
            handAnchor.originFromAnchorTransform, handThumbIntermediateTip.anchorFromJointTransform
        ).columns.3.xyz
        
        // 人差し指
        let originFromHandIndexFingerIntermediateBaseTransform = matrix_multiply(
            handAnchor.originFromAnchorTransform, handIndexFingerIntermediateBase.anchorFromJointTransform
        ).columns.3.xyz
        
        // 中指
        let originFromHandMiddleFingerIntermediateBaseTransform = matrix_multiply(
            handAnchor.originFromAnchorTransform, handMiddleFingerIntermediateBase.anchorFromJointTransform
        ).columns.3.xyz
        
        // 薬指
        let originFromHandRingFingerIntermediateBaseTransform = matrix_multiply(
            handAnchor.originFromAnchorTransform, handRingFingerIntermediateBase.anchorFromJointTransform
        ).columns.3.xyz
        
        // 小指
        let originFromHandLittleFingerIntermediateTipTransform = matrix_multiply(
            handAnchor.originFromAnchorTransform, handLittleFingerIntermediateTip.anchorFromJointTransform
        ).columns.3.xyz
        
        // 親指と人差し指の距離計算
        let thumbToIndexFingerDistance = distance(
            originFromhandThumbIntermediateTipTransform,
            originFromHandIndexFingerIntermediateBaseTransform
        )
        let isThumbToindexFingerDistance = thumbToIndexFingerDistance > 0.05
        
        // 人差し指と中指の距離計算
        let indexFingerToMiddleFingerDistance = distance(
            originFromHandIndexFingerIntermediateBaseTransform,
            originFromHandMiddleFingerIntermediateBaseTransform
        )
        let isIndexFingerToMiddleFingerDistance = indexFingerToMiddleFingerDistance > 0.03
        
        // 中指と薬指の距離計算
        let middleFingerToRingFingerDistance = distance(
            originFromHandMiddleFingerIntermediateBaseTransform,
            originFromHandRingFingerIntermediateBaseTransform
        )
        let isMiddleFingerToRingFingerDistance = middleFingerToRingFingerDistance > 0.023
        
        // 薬指と小指の距離計算
        let ringFingerToLittleFingerDistance = distance(
            originFromHandRingFingerIntermediateBaseTransform,
            originFromHandLittleFingerIntermediateTipTransform
        )
        let isRingFingerToLittleFingerDistance = ringFingerToLittleFingerDistance > 0.027
        
        if isThumbToindexFingerDistance &&
            isIndexFingerToMiddleFingerDistance &&
            isMiddleFingerToRingFingerDistance &&
            isRingFingerToLittleFingerDistance {
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
