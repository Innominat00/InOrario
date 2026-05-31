import SwiftUI
import Combine
import Foundation
import CoreLocation
import ActivityKit


struct PassanteNodeView: View {
    let station: Station
    let isFirst: Bool
    let isLast: Bool
    let isNearby: Bool
    var lineColor: Color = .orange
    
    @State private var animationScale: CGFloat = 1.0
    @State private var animationOpacity: Double = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            Text(station.name.replacingOccurrences(of: "Milano ", with: "").replacingOccurrences(of: " Passante", with: ""))
                .font(.system(size: 13, weight: isNearby ? .bold : .medium))
                .foregroundColor(isNearby ? lineColor : .primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: 65, height: 73, alignment: .bottomLeading)
                .rotationEffect(.degrees(-45), anchor: .bottomLeading)
                .offset(x: 20, y: -5)
            
            HStack(spacing: 2) {
                ForEach(Array(Set(station.metroLines.map { $0.color })), id: \.self) { color in
                    Circle()
                        .fill(color)
                        .frame(width: 7, height: 7)
                }
            }.frame(height: 10).padding(.bottom, 2)
            
            ZStack {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(isFirst ? Color.clear : lineColor.opacity(0.6))
                        .frame(height: 5)
                    Rectangle()
                        .fill(isLast ? Color.clear : lineColor.opacity(0.6))
                        .frame(height: 5)
                }
                
                Circle()
                    .strokeBorder(isNearby ? lineColor : Color.gray.opacity(0.5), lineWidth: isNearby ? 4 : 2)
                    .background(Circle().fill(isNearby ? lineColor : Color(.systemBackground)))
                    .frame(width: 16, height: 16)
                    .scaleEffect(isNearby ? animationScale : 1.0)
                    .shadow(color: isNearby ? lineColor.opacity(0.8) : .clear, radius: isNearby ? (animationScale * 5) : 0)
            }
            .frame(width: 65)
        }
        .contentShape(Rectangle())
        .onAppear {
            if isNearby {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    animationScale = 1.25
                }
            }
        }
    }
}

struct MetroRowView: View {
    let metro: MetroLine
    let currentTime: Date
    @EnvironmentObject var cache: MetroCache
    
    var body: some View {
        let cacheKey = "\(metro.pdfID ?? "")_\(metro.direction)"
        let isOffline = cache.isOfflineMode[cacheKey] ?? false
        
        HStack(spacing: 12) {
            Circle().fill(metro.color).frame(width: 28, height: 28).overlay(Text(String(metro.name.prefix(2))).font(.system(size: 12, weight: .black)).foregroundColor(.white))
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(metro.name).font(.caption).foregroundColor(.secondary).bold()
                    if isOffline {
                        Text("OFFLINE").font(.system(size: 8, weight: .heavy)).padding(.horizontal, 4).background(Color.orange.opacity(0.2)).foregroundColor(.orange).cornerRadius(4)
                    }
                }
                
                let mode = cache.getNextDepartures(metro: metro, now: currentTime)
                switch mode {
                case .closed: Text("Servizio terminato").italic()
                case .frequency(let text):
                    Text(text).font(.system(.caption, design: .rounded)).bold().foregroundColor(.primary)
                case .exact(let deps):
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(deps, id: \.self) { d in
                            HStack {
                                Text(d.timeString).bold()
                                if let dest = d.destinationName { Text(dest).font(.caption2).foregroundColor(.secondary).textCase(.uppercase) }
                            }
                        }
                    }
                }
            }
            Spacer()
            Circle().fill(cache.allSchedules[cacheKey] != nil ? .green : .red).frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
        .task {
            if let pid = metro.pdfID {
                await cache.sync(line: String(metro.name.prefix(2)), pdfID: pid, direction: metro.direction)
            }
        }
    }
}

struct TrainRowView: View {
    let train: Train
    @EnvironmentObject var manager: TrainManager
    
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 1.0
    
    var body: some View {
        let isDelayed = !train.delay.contains("In orario") && !train.delay.contains("0'") && !train.delay.isEmpty
        let isCancelled = train.delay.lowercased().contains("cancellato") || train.delay.lowercased().contains("soppresso")
        
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(train.category)
                        .font(.system(size: 10, weight: .bold))
                        .padding(4)
                        .background(categoryColor(train.category))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    
                    Text(fullCategoryName(train.category, dest: train.destination))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Text(train.number)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(train.destination)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(train.time).font(.title3).bold()
                HStack {
                    Text(train.delay)
                        .foregroundColor(train.delay.contains("In orario") ? .green : .red)
                        .scaleEffect(train.delay.contains("In orario") ? pulseScale : 1.0)
                        .opacity(train.delay.contains("In orario") ? pulseOpacity : 1.0)
                        
                    Text("Bin. \(train.platform)")
                        .padding(.horizontal, 4)
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.yellow)
                        .cornerRadius(4)
                }
                .font(.caption).bold()
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, manager.isHomeFilterActive && (isDelayed || isCancelled) ? 8 : 0)
        .background(manager.isHomeFilterActive && isCancelled ? Color.red.opacity(0.15) : (manager.isHomeFilterActive && isDelayed ? Color.orange.opacity(0.08) : Color.clear))
        .cornerRadius(8)
        .onAppear {
            if train.delay.contains("In orario") {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseScale = 1.1
                    pulseOpacity = 0.7
                }
            }
        }
    }
    
    func fullCategoryName(_ c: String, dest: String) -> String {
        let cat = c.uppercased()
        if cat.contains("FR") { return "Frecciarossa" }
        if cat.contains("RV") { return "Regionale Veloce" }
        if cat.contains("AV") || cat.contains("ALTA VELOCIT") { return "Alta Velocità" }
        if cat.contains("IC") { return "Intercity" }
        if cat.contains("EC") { return "Eurocity" }
        if cat.contains("S6") || (cat == "S" && (dest.lowercased().contains("novara") || dest.lowercased().contains("treviglio"))) { return "Suburbano" }
        if cat.contains("NTV") || cat.contains("ITA") { return "Italo" }
        return "Treno"
    }
    
    func categoryColor(_ cat: String) -> Color {
        let c = cat.uppercased()
        if c.contains("FR") || c.contains("ITA") || c == "AV" { return .red }
        if c == "IC" || c == "EC" { return .gray }
        if c.contains("S") { return Color(red: 0.0, green: 0.6, blue: 0.2) }
        if c.contains("RV") || c.contains("RE") { return .blue }
        return .gray
    }
}


struct ReorderSectionsView: View {
    @EnvironmentObject var manager: TrainManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Bottone per personalizzare linee/stazioni - FUORI dalla lista in editMode per evitare che SwiftUI lo disabiliti!
                NavigationLink(destination: CustomizeLinesView()) {
                    HStack {
                        Image(systemName: "tram.fill")
                        Text("Personalizza Linee e Stazioni")
                            .fontWeight(.bold)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 15)
                    .padding(.bottom, 10)
                }
                .foregroundColor(.orange)
                
                // Lista solo per il riordino con editMode attivo
                List {
                    Section(header: Text("Ordine Sezioni Dashboard")) {
                        ForEach(manager.sectionOrder, id: \.self) { section in
                            Text(section.rawValue).font(.headline)
                        }
                        .onMove { from, to in
                            Haptics.play(.medium)
                            manager.sectionOrder.move(fromOffsets: from, toOffset: to)
                            manager.saveSectionOrder()
                        }
                    }
                }
                .environment(\.editMode, .constant(.active))
            }
            .navigationTitle("Personalizza Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fine") { dismiss() }.fontWeight(.bold)
                }
            }
        }
    }
}


struct NewsCenterView: View {
    let news: [NewsItem]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                if news.isEmpty {
                    VStack(spacing: 15) {
                        Spacer()
                        Image(systemName: "tray.full").font(.system(size: 50)).foregroundColor(.secondary)
                        Text("Nessuna notizia disponibile").font(.headline).foregroundColor(.secondary)
                        Spacer()
                    }.frame(maxWidth: .infinity).listRowBackground(Color.clear)
                } else {
                    ForEach(news) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(item.title).font(.headline)
                                Spacer()
                                if item.isUrgent {
                                    Text("URGENTE").font(.system(size: 10, weight: .bold)).padding(.horizontal, 6).padding(.vertical, 2).background(.red).foregroundColor(.white).cornerRadius(4)
                                }
                            }
                            Text(item.content).font(.subheadline).foregroundColor(.secondary)
                        }.padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Centro News")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Chiudi") { dismiss() }.fontWeight(.bold) }
            }
        }
    }
}

struct CustomizeLinesView: View {
    @EnvironmentObject var manager: TrainManager
    @State private var showNewSmartRouteSheet = false
    @State private var homeDestInput = ""
    
    var body: some View {
        List {
            Section(header: Text("Filtro Rapido Destinazione (Casa)")) {
                let allStations = SuburbanData.shared.allLines.flatMap { $0.stations.map { $0.name } } + manager.allRFIStations.map { $0.name }
                AutocompleteField(
                    label: "Stazione Destinazione Casa / Lavoro",
                    placeholder: "Es. Magenta",
                    text: $homeDestInput,
                    suggestions: Array(Set(allStations)).sorted()
                )
                
                HStack {
                    Button(action: {
                        Haptics.play(.medium)
                        manager.homeDestinationStationName = homeDestInput
                        manager.saveFavorites()
                    }) {
                        Text("Salva Destinazione")
                            .bold()
                            .foregroundColor(.white)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity)
                            .background(homeDestInput.isEmpty ? Color.gray : Color.orange)
                            .cornerRadius(8)
                    }
                    .disabled(homeDestInput.isEmpty)
                    .buttonStyle(BorderlessButtonStyle())
                    
                    if !manager.homeDestinationStationName.isEmpty {
                        Button(action: {
                            Haptics.play(.medium)
                            homeDestInput = ""
                            manager.homeDestinationStationName = ""
                            manager.saveFavorites()
                        }) {
                            Text("Rimuovi")
                                .bold()
                                .foregroundColor(.red)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                .padding(.top, 4)
            }
            
            Section(header: Text("Le Mie Tratte Preferite")) {
                if manager.smartRoutes.isEmpty {
                    Text("Nessuna tratta preferita configurata.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(manager.smartRoutes) { route in
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill").foregroundColor(.yellow)
                                Text("\(route.originName) ➔ \(route.destinationName)")
                                    .font(.subheadline.bold())
                            }
                            Spacer()
                            Button(role: .destructive) {
                                Haptics.play(.medium)
                                manager.removeSmartRoute(id: route.id)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                }
                
                Button(action: {
                    Haptics.play(.light)
                    showNewSmartRouteSheet = true
                }) {
                    Label("Aggiungi Tratta Preferita", systemImage: "plus.circle")
                        .foregroundColor(.orange)
                        .font(.headline)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            
            ForEach(SuburbanData.shared.allLines) { line in
                if line.stations.isEmpty {
                    Toggle(isOn: Binding(
                        get: { manager.selectedSuburbanLines.contains(line.id) },
                        set: { _ in manager.toggleSuburbanLine(line.id) }
                    )) {
                        Text(line.name).font(.headline).foregroundColor(line.color)
                    }
                } else {
                    Section {
                        if manager.selectedSuburbanLines.contains(line.id) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 15) {
                                    let hiddenForLine = manager.hiddenSuburbanStations[line.id] ?? []
                                    ForEach(line.stations) { station in
                                        let isHidden = hiddenForLine.contains(station.name)
                                        
                                        VStack {
                                            PassanteNodeView(station: station, isFirst: false, isLast: false, isNearby: false, lineColor: isHidden ? .gray.opacity(0.3) : line.color)
                                                .opacity(isHidden ? 0.4 : 1.0)
                                        }
                                        .overlay(
                                            Button(action: {
                                                Haptics.play(.light)
                                                manager.toggleHiddenStation(lineId: line.id, stationName: station.name)
                                            }) {
                                                Image(systemName: isHidden ? "plus.circle.fill" : "minus.circle.fill")
                                                    .foregroundColor(isHidden ? .green : .red)
                                                    .background(Circle().fill(Color.white))
                                                    .font(.title2)
                                            }
                                            .offset(x: 15, y: -25)
                                            , alignment: .topTrailing
                                        )
                                        .padding(.top, 20)
                                    }
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 5)
                             }
                             .listRowInsets(EdgeInsets())
                        }
                    } header: {
                        HStack {
                            Text(line.name).font(.headline).foregroundColor(line.color)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { manager.selectedSuburbanLines.contains(line.id) },
                                set: { _ in
                                    Haptics.play(.medium)
                                    manager.toggleSuburbanLine(line.id)
                                }
                            ))
                            .labelsHidden()
                        }
                    } footer: {
                        if manager.selectedSuburbanLines.contains(line.id) {
                            Text("Tocca il tasto - per nascondere le stazioni che non ti interessano, o + per ripristinarle.")
                        }
                    }
                }
            }
        }
        .navigationTitle("Linee Suburbane")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showNewSmartRouteSheet) {
            PassanteQuickSetupView()
                .environmentObject(manager)
        }
        .onAppear {
            homeDestInput = manager.homeDestinationStationName
        }
    }
}

struct PassanteTunnelThermometerView: View {
    let statusMessage: String
    let statusColorHex: String
    let avgDelay: Int
    
    var color: Color {
        Color(hex: statusColorHex)
    }
    
    let stations = ["Lancetti", "P. Garibaldi", "Repubblica", "P. Venezia", "Dateo", "P. Vittoria"]
    let shortStations = ["LAN", "GAR", "REP", "VEN", "DAT", "VIT"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                
                Text(statusMessage)
                    .font(.subheadline.bold())
                    .foregroundColor(color)
                
                Spacer()
                
                Text("Ritardo medio: \(avgDelay)'")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }
            
            // La linea sotterranea del tunnel
            ZStack {
                // Tubo sotterraneo
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(gradient: Gradient(colors: [color.opacity(0.8), color.opacity(0.3), color.opacity(0.8)]), startPoint: .leading, endPoint: .trailing))
                    .frame(height: 6)
                    .shadow(color: color.opacity(0.4), radius: 4, x: 0, y: 2)
                
                HStack(spacing: 0) {
                    ForEach(0..<shortStations.count, id: \.self) { idx in
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(Color(.systemBackground))
                                    .frame(width: 14, height: 14)
                                    .overlay(
                                        Circle()
                                            .stroke(color, lineWidth: 3)
                                    )
                                    .shadow(color: color.opacity(0.5), radius: 3)
                                
                                // Piccolo pallino pulsante interno
                                Circle()
                                    .fill(color)
                                    .frame(width: 6, height: 6)
                            }
                            
                            Text(shortStations[idx])
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        if idx < shortStations.count - 1 {
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 10)
            }
            .padding(.top, 5)
            .padding(.bottom, 2)
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

struct SuburbanLineBadge: View {
    let id: String
    
    var color: Color {
        if let line = SuburbanData.shared.allLines.first(where: { $0.id == id }) {
            return line.color
        }
        return .orange
    }
    
    var body: some View {
        Text(id)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundColor(.white)
            .frame(width: 28, height: 18)
            .background(color)
            .cornerRadius(4)
    }
}

struct PassanteDepartureBoardView: View {
    @EnvironmentObject var manager: TrainManager
    
    let passanteStations = [
        Station(name: "Certosa", rfiID: "1708", vtID: "S01027", lat: 45.5085, lon: 9.1272),
        Station(name: "Villapizzone", rfiID: "3099", vtID: "S01057", lat: 45.4998, lon: 9.1465),
        Station(name: "Lancetti", rfiID: "1713", vtID: "S01059", lat: 45.4925, lon: 9.1751),
        Station(name: "P. Garibaldi Passante", rfiID: "1714", vtID: "S01058", lat: 45.4844, lon: 9.1887),
        Station(name: "Repubblica", rfiID: "1719", vtID: "S01060", lat: 45.4795, lon: 9.1963),
        Station(name: "Porta Venezia", rfiID: "1723", vtID: "S01061", lat: 45.4746, lon: 9.2052),
        Station(name: "Dateo", rfiID: "3468", vtID: "S01062", lat: 45.4682, lon: 9.2158),
        Station(name: "Porta Vittoria", rfiID: "1718", vtID: "S01063", lat: 45.4613, lon: 9.2227),
        Station(name: "Forlanini", rfiID: "3169", vtID: "S01064", lat: 45.4625, lon: 9.2368)
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tabellone in Tempo Reale")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.orange)
                        Text(manager.selectedPassanteStation.name)
                            .font(.headline)
                            .bold()
                    }
                }
                
                Spacer()
                
                Menu {
                    ForEach(passanteStations) { station in
                        Button {
                            Haptics.play(.medium)
                            manager.selectPassanteStation(station)
                        } label: {
                            HStack {
                                Text(station.name)
                                if manager.selectedPassanteStation.name == station.name {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Stazione")
                        Image(systemName: "chevron.up.chevron.down")
                    }
                    .font(.subheadline.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
                }
            }
            .padding(.bottom, 4)
            
            if manager.isLoading {
                HStack {
                    Spacer()
                    ProgressView("Caricamento treni...")
                    Spacer()
                }
                .padding(.vertical, 30)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    // Direzione Ovest
                    VStack(alignment: .leading, spacing: 8) {
                        Text("← OVEST / Nord")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.12))
                            .cornerRadius(4)
                        
                        let westTrains = manager.passanteTrainsWestbound
                        if westTrains.isEmpty {
                            Text("Nessun treno in partenza")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                                .padding(.vertical, 10)
                        } else {
                            ForEach(Array(westTrains.prefix(3).enumerated()), id: \.offset) { _, train in
                                PassanteTrainRowView(train: train)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                        .frame(height: 100)
                    
                    // Direzione Est
                    VStack(alignment: .leading, spacing: 8) {
                        Text("EST / Sud →")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.12))
                            .cornerRadius(4)
                        
                        let eastTrains = manager.passanteTrainsEastbound
                        if eastTrains.isEmpty {
                            Text("Nessun treno in partenza")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                                .padding(.vertical, 10)
                        } else {
                            ForEach(Array(eastTrains.prefix(3).enumerated()), id: \.offset) { _, train in
                                PassanteTrainRowView(train: train)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

struct PassanteTrainRowView: View {
    let train: Train
    
    var body: some View {
        HStack(spacing: 6) {
            SuburbanLineBadge(id: train.category.isEmpty ? "S" : train.category)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(train.destination.replacingOccurrences(of: "Milano ", with: ""))
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(train.time)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.primary)
                    
                    let isDelay = !train.delay.contains("In orario")
                    Text(train.delay)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(isDelay ? .red : .green)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct SmartConnectorRouteView: View {
    let route: SuburbanRoute
    @EnvironmentObject var manager: TrainManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                        .foregroundColor(.orange)
                    Text("\(route.originName) ➔ \(route.destinationName)")
                        .font(.subheadline)
                        .bold()
                }
                
                Spacer()
                
                Button {
                    Haptics.play(.medium)
                    manager.removeSmartRoute(id: route.id)
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.subheadline)
                }
            }
            
            if manager.isLoadingSmartRoutes {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 15)
            } else if let details = manager.loadedSmartRouteDetails[route.id] {
                if details.isDirect {
                    // Tratta Diretta
                    VStack(alignment: .leading, spacing: 8) {
                        Text("COLLEGAMENTO DIRETTO")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.12))
                            .cornerRadius(4)
                        
                        if details.originTrains.isEmpty {
                            Text("Nessun treno diretto in tempo reale.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            ForEach(details.originTrains.prefix(2)) { train in
                                HStack {
                                    SuburbanLineBadge(id: train.category)
                                    Text(train.destination.replacingOccurrences(of: "Milano ", with: ""))
                                        .font(.system(size: 11, weight: .bold))
                                    Spacer()
                                    Text(train.time)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                    let isDelay = !train.delay.contains("In orario")
                                    Text(train.delay)
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundColor(isDelay ? .red : .green)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                } else {
                    // Tratta con Cambio
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("CONNESSO CON CAMBIO")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.12))
                                .cornerRadius(4)
                            
                            if let exchange = details.exchangeStation {
                                Text("Cambio a \(exchange.name.replacingOccurrences(of: "Milano ", with: "").replacingOccurrences(of: " Passante", with: ""))")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.bottom, 2)
                        
                        // Primo Step: Origine ➔ Cambio
                        if let firstTrain = details.originTrains.first {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 6, height: 6)
                                    .background(Circle().stroke(Color.orange.opacity(0.2), lineWidth: 3))
                                
                                SuburbanLineBadge(id: firstTrain.category)
                                
                                Text(details.originStation.name.replacingOccurrences(of: "Milano ", with: ""))
                                    .font(.system(size: 11, weight: .bold))
                                
                                Spacer()
                                
                                Text(firstTrain.time)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                
                                let isDelay = !firstTrain.delay.contains("In orario")
                                Text(firstTrain.delay)
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundColor(isDelay ? .red : .green)
                            }
                        } else {
                            Text("Nessun treno da \(route.originName) in tempo reale.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                        
                        // Linea verticale per il cambio
                        HStack(spacing: 12) {
                            Rectangle()
                                .fill(Color.orange.opacity(0.4))
                                .frame(width: 2, height: 18)
                                .padding(.leading, 2)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 9))
                                    .foregroundColor(.orange)
                                Text("Cambio comodo sullo stesso marciapiede (~4 min)")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 8)
                            
                            Spacer()
                        }
                        
                        // Secondo Step: Cambio ➔ Destinazione
                        if let secondTrain = details.exchangeTrains.first {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                    .background(Circle().stroke(Color.green.opacity(0.2), lineWidth: 3))
                                
                                SuburbanLineBadge(id: secondTrain.category)
                                
                                Text(details.destinationStation.name.replacingOccurrences(of: "Milano ", with: ""))
                                    .font(.system(size: 11, weight: .bold))
                                
                                Spacer()
                                
                                Text(secondTrain.time)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                
                                let isDelay = !secondTrain.delay.contains("In orario")
                                Text(secondTrain.delay)
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundColor(isDelay ? .red : .green)
                            }
                        } else {
                            Text("Nessun treno in coincidenza trovato.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                }
            } else {
                Text("Trascina la home verso il basso per caricare l'itinerario live.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

struct PassanteQuickSetupView: View {
    @EnvironmentObject var manager: TrainManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedOrigin = ""
    @State private var selectedDestination = ""
    
    var allSuburbanStations: [String] {
        let list = SuburbanData.shared.allLines.flatMap { $0.stations.map { $0.name } }
        let rfiList = manager.allRFIStations.map { $0.name }
        return Array(Set(list + rfiList)).sorted()
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Seleziona stazioni")) {
                    AutocompleteField(
                        label: "Origine",
                        placeholder: "Digita stazione d'origine...",
                        text: $selectedOrigin,
                        suggestions: allSuburbanStations
                    )
                    
                    AutocompleteField(
                        label: "Destinazione",
                        placeholder: "Digita stazione di destinazione...",
                        text: $selectedDestination,
                        suggestions: allSuburbanStations
                    )
                }
                
                Section {
                    Button(action: {
                        if !selectedOrigin.isEmpty && !selectedDestination.isEmpty && selectedOrigin != selectedDestination {
                            Haptics.play(.medium)
                            manager.addSmartRoute(origin: selectedOrigin, destination: selectedDestination)
                            dismiss()
                        }
                    }) {
                        Text("Salva Tratta nei Preferiti")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(selectedOrigin.isEmpty || selectedDestination.isEmpty || selectedOrigin == selectedDestination ? Color.gray : Color.orange)
                    .disabled(selectedOrigin.isEmpty || selectedDestination.isEmpty || selectedOrigin == selectedDestination)
                }
            }
            .navigationTitle("Nuova Tratta Suburbana")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
            }
        }
    }
}

struct PassanteTunnelStatusHeaderView: View {
    @EnvironmentObject var manager: TrainManager
    @State private var showThermometerSheet = false
    
    var body: some View {
        Button {
            Haptics.play(.light)
            showThermometerSheet = true
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: manager.passanteTunnelHealthColor))
                    .frame(width: 8, height: 8)
                
                Text("\(manager.passanteTunnelHealthMessage)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: manager.passanteTunnelHealthColor))
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "info.circle.fill")
                    .foregroundColor(Color(hex: manager.passanteTunnelHealthColor).opacity(0.8))
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: manager.passanteTunnelHealthColor).opacity(0.12))
            .cornerRadius(8)
        }
        .sheet(isPresented: $showThermometerSheet) {
            NavigationStack {
                VStack(spacing: 20) {
                    Text("Stato del Tunnel sotterraneo")
                        .font(.headline)
                        .padding(.top, 25)
                    
                    PassanteTunnelThermometerView(
                        statusMessage: manager.passanteTunnelHealthMessage,
                        statusColorHex: manager.passanteTunnelHealthColor,
                        avgDelay: manager.passanteTunnelAverageDelay
                    )
                    .padding(.horizontal)
                    
                    Text("Il termometro mostra il livello di congestione delle 6 stazioni centrali sotterranee calcolato sui ritardi in tempo reale dei treni in transito.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 25)
                    
                    Spacer()
                }
                .navigationTitle("Dettagli Tunnel")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Chiudi") { showThermometerSheet = false }
                    }
                }
            }
        }
    }
}

struct SuburbanFavoriteRouteCardView: View {
    let route: SuburbanRoute
    @EnvironmentObject var manager: TrainManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text("\(route.originName) ➔ \(route.destinationName)")
                        .font(.system(size: 11, weight: .bold))
                }
                
                Spacer()
                
                Button {
                    Haptics.play(.medium)
                    manager.removeSmartRoute(id: route.id)
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            if manager.isLoadingSmartRoutes {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 10)
            } else if let details = manager.loadedSmartRouteDetails[route.id] {
                let trainsToShow = details.originTrains
                
                if trainsToShow.isEmpty {
                    Text("Nessun treno suburbano in tempo reale.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(.vertical, 4)
                } else {
                    ForEach(trainsToShow.prefix(2)) { train in
                        let delayMin = Int(train.delay.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: "'", with: "")) ?? 0
                        
                        HStack(spacing: 8) {
                            SuburbanLineBadge(id: train.category.isEmpty ? "S" : train.category)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(train.destination.replacingOccurrences(of: "Milano ", with: ""))
                                    .font(.system(size: 11, weight: .bold))
                                    .lineLimit(1)
                                
                                // Testo descrittivo del ritardo
                                if delayMin > 0 {
                                    Text("Ritardo di \(delayMin)' (previsto \(train.time) da \(route.originName.replacingOccurrences(of: "Milano ", with: "")))")
                                        .font(.system(size: 9))
                                        .foregroundColor(.red)
                                } else {
                                    Text("In orario da \(route.originName.replacingOccurrences(of: "Milano ", with: ""))")
                                        .font(.system(size: 9))
                                        .foregroundColor(.green)
                                }
                            }
                            
                            Spacer()
                            
                            // Orario effettivo calcolato in grande
                            Text(train.estimatedArrivalTime)
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundColor(delayMin > 0 ? .red : .primary)
                        }
                        .padding(.vertical, 4)
                        
                        if train.id != trainsToShow.prefix(2).last?.id {
                            Divider()
                        }
                    }
                }
            } else {
                Text("Trascina la home verso il basso per caricare i dati.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.4))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        )
    }
}

struct AutocompleteField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let suggestions: [String]
    
    @State private var isDropdownOpen = false
    @State private var filteredSuggestions: [String] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            ZStack(alignment: .trailing) {
                TextField(placeholder, text: $text)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .onChange(of: text) { oldValue, newValue in
                        updateSuggestions(newValue)
                    }
                    .onTapGesture {
                        isDropdownOpen = true
                        updateSuggestions(text)
                    }
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                        filteredSuggestions = []
                        isDropdownOpen = false
                        Haptics.play(.light)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .padding(.trailing, 10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            if isDropdownOpen && !filteredSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredSuggestions.prefix(5), id: \.self) { suggestion in
                        Button(action: {
                            text = suggestion
                            isDropdownOpen = false
                            Haptics.play(.medium)
                        }) {
                            HStack {
                                Image(systemName: "building.2.crop.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.subheadline)
                                Text(suggestion)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if suggestion != filteredSuggestions.prefix(5).last {
                            Divider()
                        }
                    }
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .transition(.opacity)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func updateSuggestions(_ query: String) {
        if query.isEmpty {
            filteredSuggestions = []
        } else {
            filteredSuggestions = suggestions.filter { s in
                s.lowercased().folding(options: .diacriticInsensitive, locale: .current)
                    .contains(query.lowercased().folding(options: .diacriticInsensitive, locale: .current))
            }
        }
    }
}
