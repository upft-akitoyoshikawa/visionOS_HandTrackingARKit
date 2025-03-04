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
                    latestHandTracking?.left = anchor
                } else {
                    latestHandTracking?.right = anchor
                }
                
                detectionHandGesture(leftHandAnchor: latestHandTracking?.left, rightHandAnchor: latestHandTracking?.right)
            default:
                break
            }
        }
    }
    
    func detectionHandGesture(leftHandAnchor: HandAnchor?, rightHandAnchor: HandAnchor?) {
        
        if detectHandGesture(handAnchor: rightHandAnchor) {
            self.handGesture = .Hand
        } else if detectThumsupGesture(handAnchor: rightHandAnchor) {
            self.handGesture = .ThumbsUp
        } else if detectHeartGesture(leftHandAnchor: leftHandAnchor, rightHandAnchor: rightHandAnchor) {
            self.handGesture = .heart
        } else {
            self.handGesture = .None
        }
    }
    
    /// 手をパーに広げるジェスチャーを検出する
    func detectHandGesture(handAnchor: HandAnchor?) -> Bool {
        
        guard let handAnchor = handAnchor,
              handAnchor.isTracked else {
            return false
        }
        
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
    func detectThumsupGesture(handAnchor: HandAnchor?) -> Bool {
        
        guard let handAnchor = handAnchor,
              handAnchor.isTracked else {
            return false
        }
        
        // 0（手首）, 4（親指の先端）, 7（人差し指の第2関節）
        // 9（人差し指の先端）, 14（中指の先端）, 19（薬指の先端）, 24（小指の先端）
        guard
            // 0（手首）
            let handWrist = handAnchor.handSkeleton?.joint(.wrist),
            // 4（親指の先端）
            let handThumbTip = handAnchor.handSkeleton?.joint(.thumbTip),
            // 7（人差し指の第2関節）
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
        
        // 人差し指の第2関節
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
        
        // 親指が人差し指の第一関節よりも上にある
        let isThumbUp = distance(originFromHandThumbTipTransform, originFromHandIndexIntermediateBaseTransform) > 0.05
        
        // 他の4本の指が手首の近く（折りたたまれている）
        let isIndexBent = distance(originFromHandWristTransform, originFromHandIndexTipTransform) < 0.09
        let isMiddleBent = distance(originFromHandWristTransform, originFromHandMiddleTipTransform) < 0.09
        let isRingBent = distance(originFromHandWristTransform, originFromHandRingTipTransform) < 0.09
        let isLittleBent = distance(originFromHandWristTransform, originFromHandLittleTipTransform) < 0.09
        
        // 全ての条件を満たす場合、サムズアップと判定
        if isThumbUp && isIndexBent && isMiddleBent && isRingBent && isLittleBent {
            return true
        } else {
            return false
        }
    }
    
    /// 両手を使った指ハートジェスチャを検出する
    private func detectHeartGesture(leftHandAnchor: HandAnchor?, rightHandAnchor: HandAnchor?) -> Bool {
        
        guard let leftHandAnchor = leftHandAnchor,
              let rightHandAnchor = rightHandAnchor,
              leftHandAnchor.isTracked, rightHandAnchor.isTracked else {
            return false
        }
        
        guard
            // 8（左手 人差し指の第1関節）
            let leftHandIndexFingerIntermediateBase = leftHandAnchor.handSkeleton?.joint(.indexFingerIntermediateTip),
            // 9（左手 人差し指の先端）
            let reftHandindexFingerTip = leftHandAnchor.handSkeleton?.joint(.indexFingerTip),
            // 14（左手 中指の先端）
            let reftHandMiddleFingerTip = leftHandAnchor.handSkeleton?.joint(.middleFingerTip),
            
            // 8（右手 人差し指の第1関節）
            let rightHandIndexFingerIntermediateBase = rightHandAnchor.handSkeleton?.joint(.indexFingerIntermediateTip),
            // 9（右手 人差し指の先端）
            let rightHandindexFingerTip = rightHandAnchor.handSkeleton?.joint(.indexFingerTip),
            // 14（右手 中指の先端）
            let rightHandMiddleFingerTip = rightHandAnchor.handSkeleton?.joint(.middleFingerTip),

            // すべての指がトラッキングされているかどうか
            leftHandIndexFingerIntermediateBase.isTracked &&
            reftHandindexFingerTip.isTracked &&
            reftHandMiddleFingerTip.isTracked &&
            rightHandindexFingerTip.isTracked &&
            rightHandMiddleFingerTip.isTracked else {
            
            return false
        }
        
        // 各関節のワールド座標を取得
        // 左手 第一関節
        let originFromLeftHandIndexFingerIntermediateBaseTransform = matrix_multiply(
            leftHandAnchor.originFromAnchorTransform, leftHandIndexFingerIntermediateBase.anchorFromJointTransform
        ).columns.3.xyz
        
        // 左手 人差し指の先端
        let originFromReftHandIndexFingerTipTransform = matrix_multiply(
            leftHandAnchor.originFromAnchorTransform, reftHandindexFingerTip.anchorFromJointTransform
        ).columns.3.xyz
        
        // 左手 中指の先端
        let originFromReftHandMiddleFingerTipTransform = matrix_multiply(
            leftHandAnchor.originFromAnchorTransform, reftHandMiddleFingerTip.anchorFromJointTransform
        ).columns.3.xyz
        
        // 右手 第一関節
        let originFromRightHandIndexFingerIntermediateBaseTransform = matrix_multiply(
            rightHandAnchor.originFromAnchorTransform, rightHandIndexFingerIntermediateBase.anchorFromJointTransform
        ).columns.3.xyz
        
        // 右手 人差し指の先端
        let originFromRightHandIndexFingerTipTransform = matrix_multiply(
            rightHandAnchor.originFromAnchorTransform, rightHandindexFingerTip.anchorFromJointTransform
        ).columns.3.xyz
        
        // 右手 中指の先端
        let originFromRightHandMiddleFingerTipTransform = matrix_multiply(
            rightHandAnchor.originFromAnchorTransform, rightHandMiddleFingerTip.anchorFromJointTransform
        ).columns.3.xyz
        
        // 指ハートを検出
        // 左手の人差し指の先端と、右手の人差し指の先端の、距離が近い場合を判定
        let indexFingersDistance = distance(originFromReftHandIndexFingerTipTransform, originFromRightHandIndexFingerTipTransform)
        let isIndexFingersDistance = indexFingersDistance < 0.012
        // 左手の人差し指第一関節と、右手の人差し指第一関節の距離が近い場合を判定
        let originFromDistance = distance(originFromLeftHandIndexFingerIntermediateBaseTransform, originFromRightHandIndexFingerIntermediateBaseTransform)
        let isOriginFromDistance = originFromDistance < 0.042
        
        // 左手の中指の先端と、右手の中指の先端の距離が近い場合を判定
        let middleFingersDistance = distance(originFromReftHandMiddleFingerTipTransform, originFromRightHandMiddleFingerTipTransform)
        let isMiddleFingersDistance = middleFingersDistance < 0.02
        
        if isIndexFingersDistance && isOriginFromDistance && isMiddleFingersDistance {
            return true
        } else {
            return false
        }
    }
}
