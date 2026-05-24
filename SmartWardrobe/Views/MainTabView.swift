import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            WardrobeListView()
                .tabItem {
                    Label("衣橱", systemImage: "hanger")
                }

            OutfitListView()
                .tabItem {
                    Label("搭配", systemImage: "person.bust")
                }

            TagListView()
                .tabItem {
                    Label("标签", systemImage: "tag")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
