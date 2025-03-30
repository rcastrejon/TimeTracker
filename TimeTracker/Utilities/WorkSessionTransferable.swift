//
//  WorkSessionTransferable.swift
//  TimeTracker
//
//  Created by Rodrigo Castrejón on 27/03/25.
//

import SwiftUI
import UniformTypeIdentifiers
import SwiftData

/// Represents the transferable data for a WorkSession during drag and drop.
struct WorkSessionTransferable: Codable, Transferable {
    let id: PersistentIdentifier
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .workSessionID)
        // ProxyRepresentation(exporting: \.id.description) // Alternative: simpler for just string ID
    }
}

extension UTType {
    private static let workSessionIdentifier = "dev.rcastrejon.TimeTracker.worksessionid"
    static var workSessionID: UTType = UTType(exportedAs: workSessionIdentifier)
}
