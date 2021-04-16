//
//  Logging.swift
//  LapseCamera
//
//  Created by Chris Davis on 15/04/2021.
//

import Foundation
import os.log

extension OSLog {
  
  // MARK: - Subsystem
  
  /// The subsystem for the app
  public static var appSubsystem = "com.lapse.camera"
  
  // MARK: - Categories
  
  /// General
  static let general = OSLog(subsystem: OSLog.appSubsystem, category: "General")
  
  /// Effects
  static let effects = OSLog(subsystem: OSLog.appSubsystem, category: "Effects")
}
