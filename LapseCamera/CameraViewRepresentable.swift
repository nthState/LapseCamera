//
//  CameraViewRepresentable.swift
//  LapseCamera
//
//  Created by Chris Davis on 15/04/2021.
//

import Foundation
import SwiftUI

struct CameraViewRepresentable: UIViewRepresentable {
  
  typealias UIViewType = CameraView
  
  @Binding var takePhoto: Bool
  @Binding var reset: Bool
  
  func makeUIView(context: UIViewRepresentableContext<CameraViewRepresentable>) -> CameraView {
    let cameraView = CameraView()
    cameraView.uiDelegate = context.coordinator
    return cameraView
  }
  
  func updateUIView(_ uiView: CameraView, context: UIViewRepresentableContext<CameraViewRepresentable>) {
  }
  
  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }
}

class Coordinator {
  var parent: CameraViewRepresentable
  
  init(_ parent: CameraViewRepresentable) {
    self.parent = parent
  }
}
