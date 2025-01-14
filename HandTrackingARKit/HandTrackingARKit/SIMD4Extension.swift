//
//  SIMD4Extension.swift
//  HandTrackingARKit
//
//  Created by akito.yoshikawa on 2025/01/14.
//

import ARKit

extension SIMD4 {
    var xyz: SIMD3<Scalar> {
        self[SIMD3(0, 1, 2)]
    }
}
