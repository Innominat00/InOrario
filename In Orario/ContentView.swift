import SwiftUI
import Combine
import Foundation
import CoreLocation
import ActivityKit


struct NewsBannerView: View {
    let news: [NewsItem]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(news) { item in
                HStack {
                    Image(systemName: item.isUrgent ? "exclamationmark.triangle.fill" : "info.circle.fill")
                        .foregroundColor(item.isUrgent ? .white : .orange)
                        .font(.title3)
                    
                    VStack(alignment: .leading) {
                        Text(item.title)
                            .font(.headline)
                        Text(item.content)
                            .font(.subheadline)
                    }
                    .foregroundColor(item.isUrgent ? .white : .primary)
                    Spacer()
                }
                .padding()
                .background(item.isUrgent ? Color.red : Color.orange.opacity(0.2))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
        }
        .padding(.bottom, 8)
    }
}

struct ContentView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var manager: TrainManager
    @EnvironmentObject var metroCache: MetroCache
    
    @State private var newsItems: [NewsItem] = []
    @State private var allNewsItems: [NewsItem] = []
    
    @State private var isPassanteExpanded = false
    @State private var isFavoritesExpanded = true
    @State private var isMyStationsExpanded = true
    @State private var showSearchSheet = false
    @State private var showReorderSheet = false
    @State private var showNewsCenter = false
    @State private var showOnboarding = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    @State private var deepLinkTrain: Train? = nil
    @State private var selectedFavoriteTrain: Train? = nil
    
    var appTitle: String {
        if hasUrgentNews {
            return "In Orario? No!"
        }
        return "In Orario"
    }
    
    var hasUrgentNews: Bool {
        newsItems.contains { $0.isUrgent }
    }
    
    let passanteStations = [
        Station(name: "Certosa", rfiID: "1708", vtID: nil, lat: 45.5085, lon: 9.1272),
        Station(name: "Villapizzone", rfiID: "3099", vtID: nil, lat: 45.4998, lon: 9.1465),
        Station(name: "Lancetti", rfiID: "1713", vtID: nil, lat: 45.4925, lon: 9.1751),
        Station(name: "P. Garibaldi Passante", rfiID: "1714", vtID: nil, lat: 45.4844, lon: 9.1887),
        Station(name: "Repubblica", rfiID: "1719", vtID: nil, lat: 45.4795, lon: 9.1963),
        Station(name: "Porta Venezia", rfiID: "1723", vtID: nil, lat: 45.4746, lon: 9.2052),
        Station(name: "Dateo", rfiID: "3468", vtID: nil, lat: 45.4682, lon: 9.2158),
        Station(name: "Porta Vittoria", rfiID: "1718", vtID: nil, lat: 45.4613, lon: 9.2227),
        Station(name: "Forlanini", rfiID: "3169", vtID: nil, lat: 45.4625, lon: 9.2368)
    ]
    
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                if !manager.activeLiveActivities.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(manager.activeLiveActivities), id: \.self) { trainNum in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                    Text("Treno \(trainNum)")
                                        .font(.caption)
                                        .bold()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.15))
                                .foregroundColor(.red)
                                .cornerRadius(16)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Il banner enorme è stato rimosso per un design più pulito e premium.
                // Lo stato degli scioperi critici viene ora mostrato con un triangolo pulsante di fianco al saluto.
                
                List {
                    ForEach(manager.sectionOrder, id: \.self) { section in
                        switch section {
                        case .nearby:
                            if let nearby = locationManager.nearbyStation {
                                Section(header: Text("📍 Stazione Vicina").font(.subheadline.bold())) {
                                    NavigationLink(destination: SmartBoardView(station: nearby)) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Sei qui").font(.caption2).fontWeight(.heavy).foregroundColor(.orange).textCase(.uppercase)
                                                Text(nearby.name).font(.title3).bold().foregroundColor(.primary)
                                            }
                                            Spacer()
                                            Image(systemName: "location.circle.fill").font(.title).foregroundColor(.orange)
                                        }
                                        .padding(.vertical, 8)
                                        .contentShape(Rectangle())
                                    }
                                }
                            }
                            
                        case .favoriteTrains:
                            if !manager.favoriteTrains.isEmpty {
                                Section {
                                    DisclosureGroup(isExpanded: $isFavoritesExpanded) {
                                        ForEach(manager.favoriteTrains) { fav in
                                            let dummy = manager.createDummyTrain(from: fav)
                                            Button {
                                                selectedFavoriteTrain = dummy
                                            } label: {
                                                HStack {
                                                    Image(systemName: "train.side.front.car").foregroundColor(.blue)
                                                    VStack(alignment: .leading) {
                                                        Text("Treno \(fav.number)").font(.headline)
                                                        Text(fav.description).font(.caption).foregroundColor(.secondary)
                                                    }
                                                }
                                                .padding(.vertical, 4)
                                                .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)
                                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                Button(role: .destructive) {
                                                    manager.toggleFavorite(trainNumber: fav.number, description: fav.description)
                                                } label: {
                                                    Label("Rimuovi", systemImage: "trash.fill")
                                                }
                                            }
                                        }
                                    } label: {
                                        Label("I miei Treni", systemImage: "star.fill").font(.headline).foregroundColor(.yellow).padding(.vertical, 4)
                                    }
                                    .onChange(of: isFavoritesExpanded) { oldValue, newValue in
                                        Haptics.play(.light)
                                    }
                                }
                            }
                            

                            
                        case .myStations:
                            if !manager.myStations.isEmpty {
                                Section {
                                    DisclosureGroup(isExpanded: $isMyStationsExpanded) {
                                        ForEach(manager.myStations) { s in
                                            NavigationLink(destination: SmartBoardView(station: s)) {
                                                Label(s.name, systemImage: "building.2.crop.circle.fill")
                                                    .foregroundColor(.blue)
                                                    .font(.headline)
                                                    .padding(.vertical, 4)
                                                    .contentShape(Rectangle())
                                            }
                                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                Button(role: .destructive) {
                                                    if let vtID = s.vtID {
                                                        manager.removeMyStation(vtID: vtID)
                                                    }
                                                } label: {
                                                    Label("Rimuovi", systemImage: "trash.fill")
                                                }
                                            }
                                        }
                                    } label: {
                                        Label("Le Mie Stazioni", systemImage: "building.2.crop.circle.fill")
                                            .font(.headline)
                                            .foregroundColor(.blue)
                                            .padding(.vertical, 4)
                                    }
                                    .onChange(of: isMyStationsExpanded) { oldValue, newValue in
                                        Haptics.play(.light)
                                    }
                                }
                            }
                            
                        case .passante:
                            Section {
                                DisclosureGroup(isExpanded: $isPassanteExpanded) {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 0) {
                                            ForEach(Array(passanteStations.enumerated()), id: \.element.id) { index, station in
                                                let isNearby = locationManager.nearbyStation?.rfiID == station.rfiID
                                                NavigationLink(destination: SmartBoardView(station: station)) {
                                                    PassanteNodeView(station: station, isFirst: index == 0, isLast: index == passanteStations.count - 1, isNearby: isNearby)
                                                }
                                            }
                                        }
                                        .padding(.vertical, 25)
                                        .padding(.horizontal, 15)
                                    }
                                    .listRowInsets(EdgeInsets())
                                } label: {
                                    Label("Passante Ferroviario", systemImage: "tram.fill")
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                        .padding(.vertical, 4)
                                }
                                .onChange(of: isPassanteExpanded) { oldValue, newValue in
                                    Haptics.play(.light)
                                }
                            }
                        }
                    }
                    
                    Section {
                        Button {
                            Haptics.play(.medium)
                            showReorderSheet = true
                        } label: {
                            HStack { Spacer(); Label("Personalizza Dashboard", systemImage: "slider.horizontal.3").foregroundColor(.blue).font(.subheadline.bold()); Spacer() }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                .refreshable {
                    Haptics.play(.medium)
                    await loadNews()
                    manager.loadFavorites()
                }
            }
            .navigationTitle(appTitle)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 20) {
                        Button {
                            Haptics.play(.medium)
                            showNewsCenter = true
                        } label: {
                            Image(systemName: "newspaper.fill")
                                .foregroundColor(hasUrgentNews ? .red : .blue)
                                .overlay(
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 10, y: -10)
                                        .opacity(newsItems.isEmpty ? 0 : 1)
                                )
                        }
                        
                        NavigationLink(destination: SavedTripsView()) {
                            Image(systemName: "bookmark.fill")
                                .foregroundColor(.green)
                                .overlay(
                                    Group {
                                        if !manager.savedTrips.isEmpty {
                                            Text("\(manager.savedTrips.count)")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 2)
                                                .background(Color.green)
                                                .clipShape(Capsule())
                                                .offset(x: 10, y: -10)
                                        }
                                    }
                                )
                        }
                        
                        Button {
                            Haptics.play(.medium)
                            showSearchSheet = true
                        } label: { Image(systemName: "magnifyingglass").fontWeight(.bold) }
                    }
                }
            }
            .sheet(isPresented: $showSearchSheet, onDismiss: { manager.loadFavorites() }) { SearchView() }
            .sheet(isPresented: $showReorderSheet) { ReorderSectionsView() }
            .sheet(isPresented: $showNewsCenter) { NewsCenterView(news: allNewsItems) }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(showOnboarding: $showOnboarding)
                    .environmentObject(locationManager)
                    .onDisappear {
                        hasCompletedOnboarding = true
                        locationManager.requestAuthorization()
                    }
            }
            .onAppear {
                manager.loadFavorites()
                manager.syncLiveActivities()
                if hasCompletedOnboarding {
                    locationManager.requestLocation()
                } else {
                    showOnboarding = true
                }
                withAnimation(.spring()) { }
            }
            .task { await loadNews() }
            
        }
        .environmentObject(metroCache)
        
        .sheet(item: $selectedFavoriteTrain) { t in
            NavigationStack {
                TrainStopsView(train: t)
            }
        }
        .sheet(item: $deepLinkTrain) { t in
            NavigationStack {
                TrainStopsView(train: t)
            }
        }
        .onOpenURL { url in
            guard url.scheme == "inorario" else { return }
            
            let number = url.path.replacingOccurrences(of: "/", with: "")
            let finalNumber = number.isEmpty ? (url.host ?? "") : number
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let dummy = Train(category: "Treno", number: finalNumber, destination: "Caricamento...", time: "--:--", delay: "In orario", platform: "--")
                self.deepLinkTrain = dummy
            }
        }
        
    }
    
    func loadNews() async {
        guard let url = URL(string: "https://inorario.toreroclub.com/news") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decodedNews = try JSONDecoder().decode([NewsItem].self, from: data)
            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    self.allNewsItems = decodedNews
                    self.newsItems = decodedNews.filter { $0.title != "Info" || $0.isUrgent }
                }
            }
        } catch {
            print("Errore fetch news: \(error)")
        }
    }
}

