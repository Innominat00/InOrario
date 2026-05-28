import SwiftUI
import Combine
import Foundation
import CoreLocation
import ActivityKit


struct SearchView: View {
    @EnvironmentObject var manager: TrainManager
    @State private var query = ""
    @State private var searchType = 0
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Tipo Ricerca", selection: $searchType) {
                    Text("Treni").tag(0)
                    Text("Stazioni").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: searchType) { oldValue, newValue in Haptics.play(.light) }
                
                List {
                    if manager.isSearching {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else if searchType == 0 {
                        if manager.searchResults.isEmpty && !query.isEmpty {
                            Text("Nessun treno trovato.").foregroundColor(.secondary)
                        } else {
                            ForEach(manager.searchResults) { result in
                                let dummy = manager.createDummyTrain(from: result)
                                NavigationLink(destination: TrainStopsView(train: dummy)) {
                                    HStack {
                                        Image(systemName: "train.side.front.car").foregroundColor(.blue)
                                        VStack(alignment: .leading) {
                                            Text("Treno \(result.number)").font(.headline)
                                            Text(result.description).font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        if manager.searchStationResults.isEmpty && !query.isEmpty {
                            Text("Nessuna stazione trovata.").foregroundColor(.secondary)
                        } else {
                            ForEach(manager.searchStationResults) { result in
                                HStack {
                                    Image(systemName: "building.2.crop.circle.fill").foregroundColor(.orange)
                                    
                                    let possibleRFI = manager.rfiStationMap[result.nomeLungo.lowercased()]
                                    let tempStation = Station(name: result.nomeLungo, rfiID: possibleRFI, vtID: result.vtID, lat: nil, lon: nil)
                                    
                                    NavigationLink(destination: SmartBoardView(station: tempStation)) {
                                        Text(result.nomeLungo).font(.headline)
                                    }
                                    Spacer()
                                    
                                    Button {
                                        if manager.isMyStation(vtID: result.vtID) {
                                            manager.removeMyStation(vtID: result.vtID)
                                        } else {
                                            manager.addMyStation(name: result.nomeLungo, vtID: result.vtID)
                                        }
                                    } label: {
                                        Image(systemName: manager.isMyStation(vtID: result.vtID) ? "checkmark.circle.fill" : "plus.circle")
                                            .foregroundColor(.blue)
                                            .font(.title2)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle(searchType == 0 ? "Cerca Treno" : "Cerca Stazione")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }.fontWeight(.bold)
                }
            }
            .searchable(text: $query, prompt: searchType == 0 ? "Es. 2010" : "Es. Bologna Centrale")
            .onChange(of: query) { oldValue, newValue in
                Task {
                    if searchType == 0 { await manager.searchTrains(query: newValue) }
                    else { await manager.searchStations(query: newValue) }
                }
            }
        }
    }
}

