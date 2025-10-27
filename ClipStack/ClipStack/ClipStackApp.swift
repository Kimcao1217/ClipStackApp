//
//  ClipStackApp.swift
//  ClipStack
//
//  Created by Kim Cao on 13/10/2025.
//

import SwiftUI
import CoreData
import WidgetKit

@main
struct ClipStackApp: App {
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
