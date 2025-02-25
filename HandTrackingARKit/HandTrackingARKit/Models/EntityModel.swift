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
    
    var handGesture: HandGestureType = .None
    
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
    
    
    var isPlaying = false
    
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
//                    latestHandTracking?.left = anchor
//                    spawnSphereOnWaveHand(handAnchor: latestHandTracking?.left)
                } else if anchor.chirality == .right {
                    latestHandTracking?.right = anchor
                    spawnSphereOnWaveHand(handAnchor: latestHandTracking?.right)
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
        
    func spawnSphereOnWaveHand(handAnchor: HandAnchor?) {
        
        // 手をパーに広げるジェスチャーを検出、検出したらsimd_float4x4を返す
        guard let handAnchor = handAnchor else {
            self.handGesture = .None
            return
        }

        if detectHandGesture(handAnchor: handAnchor) {
            // TODO: なんかここがすごい反応していたから、確認
            print("手をパーに広げるジェスチャーを検出 time: \(Date())")
            self.handGesture = .Hand
        } else if detectThumsupGesture(handAnchor: handAnchor) {
            // TODO: 明日確認する
            print("サムズアップジェスチャーを検出 time: \(Date())")
            self.handGesture = .ThumbsUp
        } else {
            self.handGesture = .None
        }

    }
    
    private func updateCounterAndCheckGesture(current: SIMD3<Float>, previous: SIMD3<Float>) {
        counter += 1
        
        guard counter >= checkInterval else { return }
        
        if detectHandShakeGesture(current: current, previous: previous) {
            print("手を振った動作を検知しました！")
        }
        
        resetCount()
    }
    
    private func detectHandShakeGesture(current: SIMD3<Float>, previous: SIMD3<Float>) -> Bool {
        let deltaX = Double(current.x) - Double(previous.x)
        
        print("currentHandPosition.x: \(current.x)")
        print("previousHandPosition.x: \(previous.x)")
        print("deltaX: \(deltaX)")
        
        // 差分がノイズ閾値より大きい場合、手を振ったと判定
        return abs(deltaX) > noiseThreshold
    }
    
    private func resetCount() {
        counter = 0
    }
    
    /// 手をパーに広げるジェスチャーを検出する
    func detectHandGesture(handAnchor: HandAnchor) -> Bool {
        
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
            return false
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
            return true
        } else {
            return false
        }
    }
    
    /// 手をサムズアップしたジェスチャーを検出する
    func detectThumsupGesture(handAnchor: HandAnchor) -> Bool {
        
        // 0（手首）, 4（親指の先端）, 7（人差し指の第一関節
        // 9（人差し指の先端）, 14（中指の先端）, 19（薬指の先端）, 24（小指の先端）
        guard
            // 0（手首）
            let handWrist = handAnchor.handSkeleton?.joint(.wrist),
            // 4（親指の先端）
            let handThumbTip = handAnchor.handSkeleton?.joint(.thumbTip),
            // 7（人差し指の第一関節）
            let handIndexFingerIntermediateBase = handAnchor.handSkeleton?.joint(.indexFingerIntermediateBase),
                
            // 他の4本の指（人差し指、中指、薬指、小指）の先端
            // 9（人差し指の先端）
            let handIndexTip = handAnchor.handSkeleton?.joint(.indexFingerTip),
            // 14（中指の先端）
            let hendMiddleTip = handAnchor.handSkeleton?.joint(.middleFingerTip),
            // 19（薬指の先端）
            let handRingTip = handAnchor.handSkeleton?.joint(.ringFingerTip),
            // 24（小指の先端）
            let handLittleTip = handAnchor.handSkeleton?.joint(.littleFingerTip),
            
            // すべての指がトラッキングされているかどうか
            handWrist.isTracked &&
            handThumbTip.isTracked &&
            handIndexFingerIntermediateBase.isTracked &&
            handIndexTip.isTracked &&
            hendMiddleTip.isTracked &&
            handRingTip.isTracked &&
            handLittleTip.isTracked
        else {
            return false
        }
        
        // 各関節のワールド座標を取得
        // 手首
        let originFromHandWristTransform = matrix_multiply(
            handAnchor.originFromAnchorTransform, handWrist.anchorFromJointTransform
        ).columns.3.xyz
                
        // 親指の先端
        let originFromHandThumbTipTransform = matrix_multiply(
            handAnchor.originFromAnchorTransform, handThumbTip.anchorFromJointTransform
        ).columns.3.xyz
        
        // 人差し指の第一関節
        let originFromHandIndexIntermediateBaseTransform = matrix_multiply(
            handAnchor.originFromAnchorTransform, handIndexFingerIntermediateBase.anchorFromJointTransform
        ).columns.3.xyz
        
        // 人差し指の先端
        let originFromHandIndexTipTransform = matrix_multiply(
            handAnchor.originFromAnchorTransform, handIndexTip.anchorFromJointTransform
        ).columns.3.xyz
        
        // 中指の先端
        let originFromHandMiddleTipTransform = matrix_multiply(
            handAnchor.originFromAnchorTransform, hendMiddleTip.anchorFromJointTransform
        ).columns.3.xyz
        
        // 薬指の先端
        let originFromHandRingTipTransform = matrix_multiply(
            handAnchor.originFromAnchorTransform, handRingTip.anchorFromJointTransform
        ).columns.3.xyz
        
        // 小指の先端
        let originFromHandLittleTipTransform = matrix_multiply(
            handAnchor.originFromAnchorTransform, handLittleTip.anchorFromJointTransform
        ).columns.3.xyz
        
        // サムズアップの判定
        print("-----------------------------")
        
        // 親指が人差し指の第一関節よりも上にある
        let isThumbUp = distance(originFromHandThumbTipTransform, originFromHandIndexIntermediateBaseTransform) > 0.05
        print("isThumbUp: \(isThumbUp)")
        
        // 他の4本の指が手首の近く（折りたたまれている）
        let isIndexBent = distance(originFromHandWristTransform, originFromHandIndexTipTransform) < 0.09
        print("isIndexBent: \(isIndexBent)")
        let isMiddleBent = distance(originFromHandWristTransform, originFromHandMiddleTipTransform) < 0.09
        print("isMiddleBent: \(isMiddleBent)")
        let isRingBent = distance(originFromHandWristTransform, originFromHandRingTipTransform) < 0.09
        print("isRingBent: \(isRingBent)")
        let isLittleBent = distance(originFromHandWristTransform, originFromHandLittleTipTransform) < 0.09
        print("isLittleBent: \(isLittleBent)")
        
        print("-----------------------------")
        
        // 全ての条件を満たす場合、サムズアップと判定
        if isThumbUp && isIndexBent && isMiddleBent && isRingBent && isLittleBent {
            return true
        } else {
            return false
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
