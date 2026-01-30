//
//  PencilManager.swift
//  EE267 Project
//
//  Concluded by Chester Pan on 6/3/25
//
//  Brief: Manages Apple Pencil interaction and mode switching.
//  This class handles Apple Pencil input events and maintains the state of
//  different drawing modes (regular drawing and ruler mode).
//

import Foundation
import UIKit
import SwiftUI
import ARKit

@MainActor
class PencilManager: NSObject, ObservableObject {
    static let shared = PencilManager()
    @Published var switchOne: Bool = false  // Double tap mode switch
    @Published var switchTwo: Bool = false  // Squeeze mode switch
    
    override init() {
        super.init()
    }
}

// Apple Pencil interaction delegate
@available(iOS 17.5, *)
extension PencilManager: UIPencilInteractionDelegate {
    // Handle double tap gesture
    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        switchOne.toggle()  // Toggle between regular and ruler mode
    }
    
    // Handle squeeze gesture
    func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
        guard squeeze.phase == .ended else { return }
        switchTwo.toggle()  // Toggle drawing state
    }
} 
 