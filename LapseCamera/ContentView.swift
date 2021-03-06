//
//  ContentView.swift
//  LapseCamera
//
//  Created by Chris Davis on 15/04/2021.
//

import SwiftUI

struct ContentView: View {
  
  @State var takingPhoto: Bool = false
  @State var reset: Bool = false
  @State var seconds: TimeInterval = 0.82
  @State var shrinkView: Bool = true
  @State var shouldTakePhoto: Bool = true
  @State var bluMax: CGFloat = 30
  
  @State var width: CGFloat = .infinity
  @State var height: CGFloat = .infinity
  
  func resizeCameraContainer() {
    
    guard shrinkView else {
      return
    }
    
    withAnimation {
      width = 280
      height = 280
    }
  }
  
  var body: some View {
    
    ZStack {
      
      Color.blue
        .ignoresSafeArea()
      
      CameraViewRepresentable(takePhoto: $takingPhoto, reset: $reset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .mask(
          Rectangle()
            .frame(maxWidth: width, maxHeight: height)
            .cornerRadius((takingPhoto && shrinkView) == false ? 0 : 20)
            .animation(
              Animation.timingCurve(0.22, 1, 0.36, 1, duration: seconds) // https://easings.net/#easeOutQuint
            )
        )
      
      VStack {
        
        Spacer()
        
        HStack {
          
          Button(action: {
            //Camera.shared.stop()
            Camera.shared.fauxStop()
            takingPhoto = true
            resizeCameraContainer()
            CameraEffectAnimator.shared.start = Date()
            Camera.shared.takePhoto()
            
          }, label: {
            Image(systemName: "camera")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .foregroundColor(.white)
              .frame(width: 44, height: 44)
          })
          .onReceive(Camera.shared.photoComplete, perform: { (ok) in
            
          })
          .padding(.trailing, 16)
          
          
          Button(action: {
            Camera.shared.fauxStart()
            //Camera.shared.start()
            reset = true
            width = .infinity
            height = .infinity
            takingPhoto = false
          }, label: {
            Image(systemName: "xmark")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .foregroundColor(.white)
              .frame(width: 44, height: 44)
          })
          .padding(.leading, 16)
          
        }
        .padding(.bottom, 32)
        
        HStack {
          Text("Time: \(seconds)")
            .foregroundColor(.green)
          Slider(value: $seconds, in: 0.1...2.0)
            .onChange(of: seconds) { (newValue) in
              CameraEffectAnimator.shared.totalDuration = seconds
            }
        }
        
        HStack {
          Toggle("Shrink view?", isOn: $shrinkView)
            .foregroundColor(.green)
        }
        
        HStack {
          Toggle("Take photo?", isOn: $shouldTakePhoto)
            .foregroundColor(.green)
            .onChange(of: shouldTakePhoto) { (newValue) in
              Camera.shared.shouldTakePhoto = shouldTakePhoto
            }
        }
        
        HStack {
          Text("Blur Max: \(bluMax)")
            .foregroundColor(.green)
          Slider(value: $bluMax, in: 10...40)
            .onChange(of: bluMax) { (newValue) in
              CameraEffectAnimator.shared.blurMax = Float(bluMax)
            }
        }
        
      }
      .padding()
      
    }
    
    
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
