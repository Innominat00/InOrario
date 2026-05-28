import SwiftUI
import Combine
import Foundation
import CoreLocation
import ActivityKit


struct SmartBoardView: View {
    let station: Station
    @EnvironmentObject var manager: TrainManager
    
    var body: some View {
        if let rfi = station.rfiID, !rfi.isEmpty {
            StationBoardView(station: station)
        } else if let vt = station.vtID, !vt.isEmpty {
            VTStationBoardView(stationName: station.name, vtID: vt)
        } else {
            Text("Errore: Nessun ID stazione valido.")
        }
    }
}

struct StationBoardView: View {
    let station: Station
    @State private var showingDepartures = true
    @State private var onlyMagenta = false
    @EnvironmentObject var manager: TrainManager
    @State private var selectedTrain: Train?
    
    @State private var isMetroExpanded = false
    @State private var isAlertExpanded = false
    
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var filteredTrains: [Train] {
        var result = manager.trains
        if onlyMagenta && station.name != "Magenta" {
            result = result.filter { t in
                let c = t.category.uppercased()
                let d = t.destination.lowercased()
                if c.contains("FR") || c.contains("FA") || c.contains("FB") || c.contains("IC") || c.contains("EC") || c.contains("ITA") || c.contains("NTV") || c.contains("AV") { return false }
                return d.contains("torino") || d.contains("novara") || d.contains("magenta") || d.contains("trecate")
            }
        }
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            HStack(alignment: .center) {
                Text(station.name)
                    .font(.title)
                    .bold()
                
                Spacer()
                
                // Pilotine per Partenze (P) e Arrivi (A)
                HStack(spacing: 8) {
                    Button {
                        if !showingDepartures {
                            showingDepartures = true
                            Haptics.play(.medium)
                        }
                    } label: {
                        Text("P")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .frame(width: 36, height: 36)
                            .background(showingDepartures ? Color.orange : Color(.systemGray5))
                            .foregroundColor(showingDepartures ? .white : .primary)
                            .clipShape(Circle())
                    }
                    
                    Button {
                        if showingDepartures {
                            showingDepartures = false
                            Haptics.play(.medium)
                        }
                    } label: {
                        Text("A")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .frame(width: 36, height: 36)
                            .background(!showingDepartures ? Color.orange : Color(.systemGray5))
                            .foregroundColor(!showingDepartures ? .white : .primary)
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            // BLOCCO INFO STAZIONE: Salute della linea e Avvisi stazione
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Circle()
                        .fill(manager.lineHealth.color)
                        .frame(width: 10, height: 10)
                    Text(manager.lineHealth.message)
                        .font(.subheadline.bold())
                        .foregroundColor(manager.lineHealth.color)
                    Spacer()
                    
                    if manager.isLoading {
                        ProgressView()
                    } else if manager.stationAlerts != nil && !isAlertExpanded {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .transition(.scale)
                    }
                }
                
                if let alerts = manager.stationAlerts {
                    Divider()
                    DisclosureGroup(isExpanded: $isAlertExpanded) {
                        Text(alerts)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.subheadline)
                            Text("Avvisi della Stazione")
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                        }
                    }
                    .tint(.orange)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.top, 10)

            // CARD FISSA DELLA METROPOLITANA
            if !station.metroLines.isEmpty {
                VStack(spacing: 0) {
                    DisclosureGroup(isExpanded: $isMetroExpanded) {
                        VStack(spacing: 8) {
                            ForEach(station.metroLines) { metro in
                                MetroRowView(metro: metro, currentTime: currentTime)
                            }
                        }
                        .padding(.top, 10)
                    } label: {
                        Label("Metropolitana", systemImage: "tram.fill")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .onChange(of: isMetroExpanded) { oldValue, newValue in Haptics.play(.light) }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 10)
            }
            
            Spacer().frame(height: 10)

            // LA LISTA DEI TRENI RFI
            List {
                Section(header: Text("Treni RFI")) {
                    ForEach(filteredTrains) { train in
                        TrainRowView(train: train)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Haptics.play(.light)
                                selectedTrain = train
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button { manager.toggleFavorite(trainNumber: train.number, description: train.destination) } label: {
                                    let isFav = manager.isFavorite(trainNumber: train.number)
                                    Label(isFav ? "Rimuovi" : "Preferito", systemImage: isFav ? "star.slash.fill" : "star.fill")
                                }
                                .tint(manager.isFavorite(trainNumber: train.number) ? .red : .yellow)
                            }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable {
                Haptics.play(.light)
                await manager.fetchTrains(for: station.rfiID ?? "", isDepartures: showingDepartures)
            }
            
            Text("Dati in tempo reale da tabelloni RFI")
                .font(.caption2).foregroundColor(.secondary).padding(.bottom, 8)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedTrain) { t in TrainStopsView(train: t) }
        .onAppear { manager.startAutoRefresh(for: station.rfiID ?? "", isDepartures: showingDepartures) }
        .onDisappear { manager.stopAutoRefresh() }
        .onReceive(timer) { input in self.currentTime = input }
        .task(id: showingDepartures) { await manager.fetchTrains(for: station.rfiID ?? "", isDepartures: showingDepartures) }
    }
}

struct VTStationBoardView: View {
    let stationName: String
    let vtID: String
    @State private var showingDepartures = true
    @EnvironmentObject var manager: TrainManager
    @State private var selectedTrain: Train?
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text(stationName.capitalized)
                    .font(.title)
                    .bold()
                Spacer()
                HStack(spacing: 8) {
                    Button {
                        if !showingDepartures { showingDepartures = true; Haptics.play(.medium) }
                    } label: {
                        Text("P").font(.system(size: 15, weight: .bold)).frame(width: 36, height: 36)
                            .background(showingDepartures ? Color.orange : Color(.systemGray5))
                            .foregroundColor(showingDepartures ? .white : .primary).clipShape(Circle())
                    }
                    Button {
                        if showingDepartures { showingDepartures = false; Haptics.play(.medium) }
                    } label: {
                        Text("A").font(.system(size: 15, weight: .bold)).frame(width: 36, height: 36)
                            .background(!showingDepartures ? Color.orange : Color(.systemGray5))
                            .foregroundColor(!showingDepartures ? .white : .primary).clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            if manager.isLoading { ProgressView().padding() }
            
            if manager.trains.isEmpty && !manager.isLoading {
                VStack { Spacer(); Text("Nessun treno trovato in questa stazione.").foregroundColor(.secondary); Spacer() }
            } else {
                List(manager.trains) { train in
                    TrainRowView(train: train)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Haptics.play(.light)
                            selectedTrain = train
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button { manager.toggleFavorite(trainNumber: train.number, description: train.destination) } label: {
                                let isFav = manager.isFavorite(trainNumber: train.number)
                                Label(isFav ? "Rimuovi" : "Preferito", systemImage: isFav ? "star.slash.fill" : "star.fill")
                            }
                            .tint(manager.isFavorite(trainNumber: train.number) ? .red : .yellow)
                        }
                }
                .listStyle(.plain)
                .refreshable {
                    Haptics.play(.light)
                    await manager.fetchVTTrains(for: vtID, isDepartures: showingDepartures)
                }
            }
            Text("Dati in tempo reale da ViaggiaTreno").font(.caption2).foregroundColor(.secondary).padding(.bottom, 8)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if manager.isMyStation(vtID: vtID) {
                        manager.removeMyStation(vtID: vtID)
                    } else {
                        manager.addMyStation(name: stationName, vtID: vtID)
                    }
                } label: {
                    Image(systemName: manager.isMyStation(vtID: vtID) ? "star.fill" : "star").foregroundColor(.yellow)
                }
            }
        }
        .sheet(item: $selectedTrain) { t in TrainStopsView(train: t) }
        .onAppear { manager.loadFavorites() }
        .task(id: showingDepartures) { await manager.fetchVTTrains(for: vtID, isDepartures: showingDepartures) }
    }
}

