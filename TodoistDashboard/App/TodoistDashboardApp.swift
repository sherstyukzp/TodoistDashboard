import SwiftUI
import SwiftData

@main
struct TodoistDashboardApp: App {
    let modelContainer: ModelContainer
    let dataSyncService: DataSyncService
    @StateObject private var appState: AppState
    
    init() {
        // Initialize SwiftData container
        let schema = Schema([
            SDUser.self,
            SDProject.self,
            SDTask.self,
            SDSection.self,
            SDCollaborator.self,
            SDCompletedTask.self,
            SDActivityEvent.self,
            SDUserStats.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        
        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            modelContainer = container
            
            let syncService = DataSyncService(modelContainer: container)
            dataSyncService = syncService
            
            // Initialize AppState with DataSyncService
            _appState = StateObject(wrappedValue: AppState(dataSyncService: syncService))
            
            #if DEBUG
            print("✅ SwiftData initialized successfully")
            #endif
        } catch {
            fatalError("Failed to initialize SwiftData: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            if appState.isAuthenticated {
                MainTabView()
                    .environmentObject(appState)
            } else {
                AuthView()
                    .environmentObject(appState)
            }
        }
        .modelContainer(modelContainer)
    }
}
