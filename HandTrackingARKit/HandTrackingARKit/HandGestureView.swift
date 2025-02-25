//
//  HandGestureView.swift
//  HandTrackingARKit
//
//  Created by akito.yoshikawa on 2025/02/12.
//

import SwiftUI

struct HandGestureView: View {
    var handGesture: HandGestureType

    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.7))
                .frame(width: 200, height: 100)
                .overlay(
                    VStack {
                        Image(systemName: handGesture.iconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.white)
                            .padding(.bottom, 5)
                        
                        Text(handGesture.displayName)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                )
                .shadow(radius: 10)
                .transition(.opacity)
                .animation(.easeInOut, value: handGesture)
        }
    }
}
