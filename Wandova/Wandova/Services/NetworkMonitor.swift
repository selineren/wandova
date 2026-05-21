//
//  NetworkMonitor.swift
//  Wandova
//
//  Created by seren on 16.03.2026.
//

import Foundation
import Network
import Combine

@MainActor
final class NetworkMonitor: ObservableObject, @unchecked Sendable {
    static let shared = NetworkMonitor()
    
    @Published private(set) var isConnected = true
    @Published private(set) var connectionType: ConnectionType = .unknown
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    enum ConnectionType {
        case wifi
        case cellular
        case wired
        case unknown
    }
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                
                self.isConnected = path.status == .satisfied
                
                if path.usesInterfaceType(.wifi) {
                    self.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionType = .wired
                } else {
                    self.connectionType = .unknown
                }
                
                #if DEBUG
                print("📡 Network status: \(self.isConnected ? "Connected" : "Disconnected") (\(self.connectionType))")
                #endif
            }
        }
        
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}
