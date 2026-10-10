//
//  Error.swift
//  action-camera
//
//  Created by Will Robinson on 10/9/26.
//

import Foundation


extension ActionCamera {
    public struct Error: Swift.Error, LocalizedError {
        public let message: String
        
        
        public var errorDescription: String? {
            return message
        }
        
        
        public init(message: String) {
            self.message = message
        }
    }
}
