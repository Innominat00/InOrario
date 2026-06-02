import SwiftUI
import Combine
import Foundation
import CoreLocation
import ActivityKit
import StoreKit


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
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        animationScale = 1.25
                    }
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
    var showPassanteTag: Bool = false
    var stationName: String? = nil
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
                HStack(alignment: .center, spacing: 6) {
                    Text(train.destination)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if showPassanteTag, let branch = manager.getPassanteBranch(for: train) {
                        let bColor: Color = (branch == "Bovisa" || branch == "Rogoredo") ? .red : .orange
                        Text(branch.uppercased())
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(bColor.opacity(0.15))
                            .foregroundColor(bColor)
                            .cornerRadius(4)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(train.time).font(.title3).bold()
                HStack {
                    Text(train.delay)
                        .foregroundColor(train.delay.contains("In orario") ? .green : .red)
                        .scaleEffect(train.delay.contains("In orario") ? pulseScale : 1.0)
                        .opacity(train.delay.contains("In orario") ? pulseOpacity : 1.0)
                        
                    let displayPlatform: String = {
                        if let station = stationName {
                            return manager.resolvedPlatform(for: station, train: train)
                        }
                        return train.platform
                    }()
                    
                    Text("Bin. \(displayPlatform)")
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
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        pulseScale = 1.1
                        pulseOpacity = 0.7
                    }
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


// ReorderSectionsView moved to ProfileView.swift

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

// CustomizeLinesView moved and split into ProfileView.swift
struct PulsingCircle: View {
    let color: Color
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(color, lineWidth: 2)
                    .scaleEffect(scale)
                    .opacity(opacity)
            )
            .onAppear {
                DispatchQueue.main.async {
                    withAnimation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                        scale = 2.2
                        opacity = 0.0
                    }
                }
            }
    }
}

struct LineArrivalInfo: Identifiable {
    let id: String
    let arrivals: [String]
}

struct PassanteTunnelThermometerView: View {
    let statusMessage: String
    let statusColorHex: String
    let avgDelay: Int
    
    @EnvironmentObject var manager: TrainManager
    @AppStorage("showOuterSuburbanStations") var showOuterSuburbanStations = false
    
    var color: Color {
        resolvedTrackColor
    }
    
    var resolvedTrackColor: Color {
        let activeLinesForTrack = manager.selectedSuburbanLines.filter { ["S1", "S2", "S5", "S6", "S12", "S13"].contains($0) }
        if activeLinesForTrack.count == 1, let singleLine = activeLinesForTrack.first {
            let trainsOfLine = manager.passanteTunnelTrains.filter { train in
                let cat = train.category.uppercased()
                let dest = train.destination.lowercased()
                if cat == singleLine { return true }
                if singleLine == "S1" { return dest.contains("saronno") || dest.contains("lodi") }
                if singleLine == "S2" { return dest.contains("mariano") || dest.contains("seveso") || dest.contains("camnago") }
                if singleLine == "S5" { return dest.contains("varese") || dest.contains("treviglio") || dest.contains("gallarate") }
                if singleLine == "S6" { return dest.contains("novara") || dest.contains("pioltello") }
                if singleLine == "S12" { return dest.contains("melegnano") || dest.contains("cormano") }
                if singleLine == "S13" { return dest.contains("pavia") || dest.contains("bovisa") }
                return false
            }
            
            var cancellations = 0
            var delays: [Int] = []
            for t in trainsOfLine {
                let isCancelled = t.delay.lowercased().contains("soppresso") || t.delay.lowercased().contains("cancellato")
                if isCancelled {
                    cancellations += 1
                } else {
                    let delayStr = t.delay.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: "'", with: "")
                    let delayVal = delayStr.lowercased().contains("orario") ? 0 : (Int(delayStr) ?? 0)
                    delays.append(delayVal)
                }
            }
            
            let avgDelay = delays.isEmpty ? 0 : (delays.reduce(0, +) / delays.count)
            
            if cancellations > 0 || avgDelay >= 8 { return .red }
            else if avgDelay >= 3 { return .orange }
            else { return .green }
        } else {
            return Color(hex: statusColorHex)
        }
    }
    
    func shortDestination(_ dest: String) -> String {
        let d = dest.lowercased()
        if d.contains("novara") { return "NOV" }
        if d.contains("pioltello") { return "PIOLT" }
        if d.contains("treviglio") { return "TREV" }
        if d.contains("varese") { return "VAR" }
        if d.contains("gallarate") { return "GALL" }
        if d.contains("saronno") { return "SAR" }
        if d.contains("lodi") { return "LODI" }
        if d.contains("mariano") { return "MAR" }
        if d.contains("seveso") { return "SEV" }
        if d.contains("camnago") { return "CAMN" }
        if d.contains("pavia") { return "PAV" }
        if d.contains("bovisa") { return "BOV" }
        if d.contains("rogoredo") { return "ROG" }
        if d.contains("melegnano") { return "MEL" }
        if d.contains("cadorna") { return "CAD" }
        if d.contains("garibaldi") { return "GAR" }
        if d.contains("certosa") { return "CRT" }
        if d.contains("rho") { return "RHO" }
        if d.contains("piolt") { return "PIO" }
        if d.contains("novara") { return "NOV" }
        return dest.prefix(5).uppercased()
    }
    
    // Matrice ufficiale di percorrenza in minuti rispetto a Repubblica (Baricentro)
    let minutesFromRepubblica: [String: Int] = [
        // Core Tunnel
        "Milano Rogoredo": 10,
        "Forlanini": 8,
        "Porta Vittoria": 6,
        "Dateo": 4,
        "Porta Venezia": 2,
        "Repubblica": 0,
        "P. Garibaldi Passante": -2,
        "Lancetti": -4,
        "Milano Bovisa": -7,
        "Villapizzone": -6,
        "Certosa": -9,
        "Rho Fiera": -13,
        
        // S6 Ovest (Novara)
        "Novara": -45,
        "Trecate": -37,
        "Magenta": -30,
        "Vittuone-Arluno": -26,
        "Pregnana Milanese": -22,
        "Rho": -17,
        
        // S5 Ovest (Varese)
        "Varese": -56,
        "Gazzada-Schianno-Morazzone": -50,
        "Gazzada-Schianno": -50,
        "Castronno": -47,
        "Albizzate-Solbiate Arno": -44,
        "Albizzate-Solbiate A.": -44,
        "Cavaria-Oggiona-Jerago": -41,
        "Cavaria-Oggiona-J.": -41,
        "Gallarate": -38,
        "Busto Arsizio": -32,
        "Legnano": -27,
        "Canegrate": -24,
        "Parabiago": -21,
        "Vanzago-Pogliano": -17,
        
        // S1 Ovest (Saronno)
        "Saronno": -33,
        "Caronno Pertusella": -29,
        "Cesate": -26,
        "Garbagnate Milanese": -24,
        "Garbagnate Parco delle Groane": -22,
        "Garbagnate Parco Groane": -22,
        "Bollate Nord": -19,
        "Bollate Centro": -17,
        "Novate Milanese": -14,
        "Milano Quarto Oggiaro": -11,
        
        // S2 Ovest (Mariano)
        "Mariano Comense": -41,
        "Cabiate": -37,
        "Meda": -34,
        "Seveso": -31,
        "Cesano Maderno": -28,
        "Bovisio Masciago-Mombello": -25,
        "Varedo": -22,
        "Palazzolo Milanese": -20,
        "Paderno Dugnano": -17,
        "Cormano-Cusano Milanino": -14,
        "Cusano Milanino": -14,
        "Milano Bruzzano": -11,
        
        // S5/S6 Est (Treviglio)
        "Segrate": 11,
        "Pioltello-Limito": 14,
        "Melzo": 20,
        "Pozzuolo Martesana": 24,
        "Trecella": 27,
        "Cassano d'Adda": 31,
        "Treviglio": 38,
        
        // S1/S2/S12 Est (Lodi/Melegnano)
        "San Donato Milanese": 13,
        "Borgolombardo": 15,
        "San Giuliano Milanese": 17,
        "Melegnano": 21,
        "Tavazzano": 27,
        "Lodi": 33,
        
        // S13 Est (Pavia)
        "Locate Triulzi": 17,
        "Pieve Emanuele": 21,
        "Villamaggiore": 25,
        "Certosa di Pavia": 29,
        "Pavia": 35
    ]
    
    // Stazioni ordinate geograficamente da Ovest a Est per calcolo superamento
    let stations = [
        // S5 West (Varese)
        "Varese", "Gazzada-Schianno-Morazzone", "Gazzada-Schianno", "Castronno", 
        "Albizzate-Solbiate Arno", "Albizzate-Solbiate A.", "Cavaria-Oggiona-Jerago", 
        "Cavaria-Oggiona-J.", "Gallarate", "Busto Arsizio", "Legnano", "Canegrate", 
        "Parabiago", "Vanzago-Pogliano",
        
        // S6 West (Novara)
        "Novara", "Trecate", "Magenta", "Vittuone-Arluno", "Pregnana Milanese", "Rho",
        
        // S1 West (Saronno)
        "Saronno", "Caronno Pertusella", "Cesate", "Garbagnate Milanese", 
        "Garbagnate Parco delle Groane", "Garbagnate Parco Groane", "Bollate Nord", 
        "Bollate Centro", "Novate Milanese", "Milano Quarto Oggiaro",
        
        // S2 West (Mariano Comense)
        "Mariano Comense", "Cabiate", "Meda", "Seveso", "Cesano Maderno", 
        "Bovisio Masciago-Mombello", "Varedo", "Palazzolo Milanese", "Paderno Dugnano", 
        "Cormano-Cusano Milanino", "Cusano Milanino", "Milano Bruzzano",
        
        // Core Tunnel
        "Rho Fiera", "Certosa", "Villapizzone", "Milano Bovisa", "Lancetti", 
        "P. Garibaldi Passante", "Repubblica", "Porta Venezia", "Dateo", "Porta Vittoria",
        
        // S5/S6 East (Treviglio)
        "Forlanini", "Segrate", "Pioltello-Limito", "Melzo", "Pozzuolo Martesana", 
        "Trecella", "Cassano d'Adda", "Treviglio",
        
        // S1/S2/S12 East (Lodi/Melegnano)
        "Milano Rogoredo", "San Donato Milanese", "Borgolombardo", "San Giuliano Milanese", 
        "Melegnano", "Tavazzano", "Lodi",
        
        // S13 East (Pavia)
        "Locate Triulzi", "Pieve Emanuele", "Villamaggiore", "Certosa di Pavia", "Pavia"
    ]
    
    // Set di stazioni per smistamento preciso
    let s1Stations: Set<String> = ["Saronno", "Caronno Pertusella", "Cesate", "Garbagnate Milanese", "Garbagnate Parco delle Groane", "Garbagnate Parco Groane", "Bollate Nord", "Bollate Centro", "Novate Milanese", "Milano Quarto Oggiaro", "Milano Bovisa", "Lancetti", "P. Garibaldi Passante", "Repubblica", "Porta Venezia", "Dateo", "Porta Vittoria", "Milano Rogoredo", "San Donato Milanese", "Borgolombardo", "San Giuliano Milanese", "Tavazzano", "Lodi"]
    let s2Stations: Set<String> = ["Mariano Comense", "Cabiate", "Meda", "Seveso", "Cesano Maderno", "Bovisio Masciago-Mombello", "Varedo", "Palazzolo Milanese", "Paderno Dugnano", "Cormano-Cusano Milanino", "Milano Bruzzano", "Milano Bovisa", "Lancetti", "P. Garibaldi Passante", "Repubblica", "Porta Venezia", "Dateo", "Porta Vittoria", "Milano Rogoredo"]
    let s5Stations: Set<String> = ["Varese", "Gazzada-Schianno-Morazzone", "Gazzada-Schianno", "Castronno", "Albizzate-Solbiate Arno", "Albizzate-Solbiate A.", "Cavaria-Oggiona-Jerago", "Cavaria-Oggiona-J.", "Gallarate", "Busto Arsizio", "Legnano", "Canegrate", "Parabiago", "Vanzago-Pogliano", "Rho", "Rho Fiera", "Certosa", "Villapizzone", "Lancetti", "P. Garibaldi Passante", "Repubblica", "Porta Venezia", "Dateo", "Porta Vittoria", "Forlanini", "Segrate", "Pioltello-Limito", "Melzo", "Pozzuolo Martesana", "Trecella", "Cassano d'Adda", "Treviglio"]
    let s6Stations: Set<String> = ["Novara", "Trecate", "Magenta", "Vittuone-Arluno", "Pregnana Milanese", "Rho", "Rho Fiera", "Certosa", "Villapizzone", "Lancetti", "P. Garibaldi Passante", "Repubblica", "Porta Venezia", "Dateo", "Porta Vittoria", "Forlanini", "Segrate", "Pioltello-Limito"]
    let s12Stations: Set<String> = ["Cormano-Cusano Milanino", "Milano Bruzzano", "Milano Bovisa", "Lancetti", "P. Garibaldi Passante", "Repubblica", "Porta Venezia", "Dateo", "Porta Vittoria", "Milano Rogoredo", "San Donato Milanese", "Borgolombardo", "San Giuliano Milanese", "Melegnano"]
    let s13Stations: Set<String> = ["Milano Bovisa", "Lancetti", "P. Garibaldi Passante", "Repubblica", "Porta Venezia", "Dateo", "Porta Vittoria", "Milano Rogoredo", "Locate Triulzi", "Pieve Emanuele", "Villamaggiore", "Certosa di Pavia", "Pavia"]

    // Associa ciascun treno alla fermata in cui è stimato essere, smistandolo sui rami corretti
    func getEstimatedStationName(for train: Train) -> String? {
        guard let status = manager.passanteLiveStatuses[train.number] else {
            return nil
        }
        
        let isCancelled = train.delay.lowercased().contains("soppresso") || train.delay.lowercased().contains("cancellato") || status.cancellationNote != nil
        if isCancelled || status.isArrived { return nil }
        
        let last = status.lastStation.lowercased()
        let category = train.category.uppercased()
        
        // Smistamento per rami corretti:
        // Asse Certosa: S5, S6 (Villapizzone, Certosa, Rho Fiera)
        // Asse Bovisa: S1, S2, S12, S13 (Milano Bovisa)
        let isCertosaAxis = ["S5", "S6"].contains(category)
        let isBovisaAxis = ["S1", "S2", "S12", "S13"].contains(category)
        
        var matchedStation: String? = nil
        for st in stations {
            let stName = st.lowercased()
            if stName.contains("garibaldi") && last.contains("garibaldi") { matchedStation = st; break }
            if stName.contains("venezia") && last.contains("venezia") { matchedStation = st; break }
            if stName.contains("vittoria") && last.contains("vittoria") { matchedStation = st; break }
            if stName.contains("bovisa") && last.contains("bovisa") { matchedStation = st; break }
            if stName.contains("rho") && last.contains("rho") { matchedStation = st; break }
            if last.contains(stName) || stName.contains(last) { matchedStation = st; break }
        }
        
        guard let candidate = matchedStation else { return nil }
        
        // Controllo di smistamento scientifico per ramo e linea
        if candidate == "Milano Bovisa" && isCertosaAxis { return nil }
        if (candidate == "Certosa" || candidate == "Villapizzone") && isBovisaAxis { return nil }
        
        if category == "S1" && !s1Stations.contains(candidate) { return nil }
        if category == "S2" && !s2Stations.contains(candidate) { return nil }
        if category == "S5" && !s5Stations.contains(candidate) { return nil }
        if category == "S6" && !s6Stations.contains(candidate) { return nil }
        if category == "S12" && !s12Stations.contains(candidate) { return nil }
        if category == "S13" && !s13Stations.contains(candidate) { return nil }
        
        return candidate
    }
    
    // Calcolo Conto alla Rovescia live basato sulla matrice scostamenti reali
    func countdownToRefStation(for train: Train, targetStationName: String) -> String? {
        let isCancelled = train.delay.lowercased().contains("soppresso") || train.delay.lowercased().contains("cancellato")
        if isCancelled { return nil }
        
        let direction = manager.getPassanteDirection(for: train) ?? "Est"
        
        // Verifichiamo se il treno ha già superato la stazione target basandoci sulla sua posizione reale live
        if let currentStation = getEstimatedStationName(for: train) {
            if let currIdx = stations.firstIndex(of: currentStation),
               let targetIdx = stations.firstIndex(of: targetStationName) {
                if direction == "Est" {
                    if currIdx > targetIdx {
                        return nil // Il treno ha già superato la stazione in direzione Est
                    }
                } else {
                    if currIdx < targetIdx {
                        return nil // Il treno ha già superato la stazione in direzione Ovest
                    }
                }
            }
        }
        
        let timeString = train.time
        let delayMinutes = Int(train.delay.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "R: ", with: "")) ?? 0
        
        let calendar = Calendar.current
        let now = Date()
        
        let parts = timeString.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }
              
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0
        
        guard let baseDate = calendar.date(from: components) else { return nil }
        guard let repDate = calendar.date(byAdding: .minute, value: delayMinutes, to: baseDate) else { return nil }
        
        let refOffset = minutesFromRepubblica[targetStationName] ?? 0
        let travelDeltaMinutes: Int
        if direction == "Est" {
            travelDeltaMinutes = refOffset
        } else {
            travelDeltaMinutes = -refOffset
        }
        
        guard var targetDate = calendar.date(byAdding: .minute, value: travelDeltaMinutes, to: repDate) else { return nil }
        
        // Gestione scientifica del rollover di mezzanotte:
        let diffWithNow = targetDate.timeIntervalSince(now)
        if diffWithNow < -43200 { // Indietro di oltre 12 ore, sposta a domani
            if let adjustedDate = calendar.date(byAdding: .day, value: 1, to: targetDate) {
                targetDate = adjustedDate
            }
        } else if diffWithNow > 43200 { // Avanti di oltre 12 ore, sposta a ieri
            if let adjustedDate = calendar.date(byAdding: .day, value: -1, to: targetDate) {
                targetDate = adjustedDate
            }
        }
        
        let diffInSeconds = targetDate.timeIntervalSince(now)
        let diffInMinutes = Int(round(diffInSeconds / 60.0))
        
        if diffInMinutes < 0 {
            return nil
        } else if diffInMinutes == 0 {
            return "ora"
        } else {
            return "\(diffInMinutes)m"
        }
    }
    
    // Calcolo diretto basato sui treni della stazione specifica, senza offset
    func directCountdown(for train: Train) -> String? {
        let isCancelled = train.delay.lowercased().contains("soppresso") || train.delay.lowercased().contains("cancellato")
        if isCancelled { return nil }
        
        let timeString = train.time
        let delayMinutes = Int(train.delay.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "R: ", with: "")) ?? 0
        
        let calendar = Calendar.current
        let now = Date()
        
        let parts = timeString.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }
              
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0
        
        guard let baseDate = calendar.date(from: components) else { return nil }
        guard var targetDate = calendar.date(byAdding: .minute, value: delayMinutes, to: baseDate) else { return nil }
        
        let diffWithNow = targetDate.timeIntervalSince(now)
        if diffWithNow < -43200 { 
            if let adjustedDate = calendar.date(byAdding: .day, value: 1, to: targetDate) { targetDate = adjustedDate }
        } else if diffWithNow > 43200 { 
            if let adjustedDate = calendar.date(byAdding: .day, value: -1, to: targetDate) { targetDate = adjustedDate }
        }
        
        let diffInSeconds = targetDate.timeIntervalSince(now)
        let diffInMinutes = Int(round(diffInSeconds / 60.0))
        
        if diffInMinutes < 0 {
            return nil
        } else if diffInMinutes == 0 {
            return "ora"
        } else {
            return "\(diffInMinutes)m"
        }
    }
    
    var body: some View {
        // Stazione di riferimento per il conto alla rovescia (quella attiva nel tabellone inferiore)
        let refStationName = manager.selectedPassanteStation.name
        let cleanRefName: String = {
            let lower = refStationName.lowercased()
            if lower.contains("venezia") { return "Porta Venezia" }
            if lower.contains("garibaldi") { return "P. Garibaldi Passante" }
            if lower.contains("lancetti") { return "Lancetti" }
            if lower.contains("repubblica") { return "Repubblica" }
            if lower.contains("dateo") { return "Dateo" }
            if lower.contains("vittoria") { return "Porta Vittoria" }
            if lower.contains("bovisa") { return "Milano Bovisa" }
            if lower.contains("certosa") { return "Certosa" }
            if lower.contains("villapizzone") { return "Villapizzone" }
            if lower.contains("rho") { return "Rho Fiera" }
            if lower.contains("forlanini") { return "Forlanini" }
            if lower.contains("rogoredo") { return "Milano Rogoredo" }
            return refStationName
        }()
        
        let trackColor = resolvedTrackColor
        
        let isCongested = trackColor == .red
        
        // Filtro dinamico delle stazioni rilevanti per l'utente in base alle linee S preferite nelle impostazioni
        let activeStationsList: [String] = {
            let activeLines = manager.selectedSuburbanLines.filter { ["S1", "S2", "S5", "S6", "S12", "S13"].contains($0) }
            let onlyCertosa = !activeLines.isEmpty && activeLines.allSatisfy { ["S5", "S6"].contains($0) }
            let onlyBovisa = !activeLines.isEmpty && activeLines.allSatisfy { ["S1", "S2", "S12", "S13"].contains($0) }
            
            if showOuterSuburbanStations {
                if onlyCertosa {
                    var certosaStations = Set<String>()
                    if activeLines.contains("S5") { certosaStations.formUnion(s5Stations) }
                    if activeLines.contains("S6") { certosaStations.formUnion(s6Stations) }
                    
                    let filtered = certosaStations.filter { stationName in
                        for lineId in activeLines {
                            let lineStations = lineId == "S5" ? s5Stations : s6Stations
                            if lineStations.contains(stationName) {
                                let hidden = manager.hiddenSuburbanStations[lineId] ?? []
                                if !hidden.contains(stationName) {
                                    return true
                                }
                            }
                        }
                        return false
                    }
                    return stations.filter { filtered.contains($0) }
                } else if onlyBovisa {
                    var bovisaStations = Set<String>()
                    if activeLines.contains("S1") { bovisaStations.formUnion(s1Stations) }
                    if activeLines.contains("S2") { bovisaStations.formUnion(s2Stations) }
                    if activeLines.contains("S12") { bovisaStations.formUnion(s12Stations) }
                    if activeLines.contains("S13") { bovisaStations.formUnion(s13Stations) }
                    
                    let filtered = bovisaStations.filter { stationName in
                        for lineId in activeLines {
                            let lineStations: Set<String>
                            switch lineId {
                            case "S1": lineStations = s1Stations
                            case "S2": lineStations = s2Stations
                            case "S12": lineStations = s12Stations
                            default: lineStations = s13Stations
                            }
                            if lineStations.contains(stationName) {
                                let hidden = manager.hiddenSuburbanStations[lineId] ?? []
                                if !hidden.contains(stationName) {
                                    return true
                                }
                            }
                        }
                        return false
                    }
                    return stations.filter { filtered.contains($0) }
                }
            }
            
            if onlyCertosa {
                return [
                    "Rho Fiera",
                    "Certosa",
                    "Villapizzone",
                    "Lancetti",
                    "P. Garibaldi Passante",
                    "Repubblica",
                    "Porta Venezia",
                    "Dateo",
                    "Porta Vittoria",
                    "Forlanini"
                ]
            } else if onlyBovisa {
                return [
                    "Milano Bovisa",
                    "Lancetti",
                    "P. Garibaldi Passante",
                    "Repubblica",
                    "Porta Venezia",
                    "Dateo",
                    "Porta Vittoria",
                    "Milano Rogoredo"
                ]
            } else {
                // Misto (es. S1 + S6) o Nessun filtro: SOLO il tronco centrale sotterraneo comune!
                return [
                    "Lancetti",
                    "P. Garibaldi Passante",
                    "Repubblica",
                    "Porta Venezia",
                    "Dateo",
                    "Porta Vittoria"
                ]
            }
        }()
        
        // Helper per identificare la lista di linee da mostrare (escludendo non-tunnel come S9/S19)
        let linesToProcess: [String] = {
            let activeLines = manager.selectedSuburbanLines.filter { ["S1", "S2", "S5", "S6", "S12", "S13"].contains($0) }
            if activeLines.isEmpty {
                return ["S5", "S6"]
            }
            return Array(activeLines).sorted()
        }()
        
        
        let lineArrivals: [LineArrivalInfo] = {
            var result: [LineArrivalInfo] = []
            for lineId in linesToProcess {
                let trainsOfLine = manager.passanteTrains.filter { $0.category.uppercased() == lineId.uppercased() }
                
                var destMinMins: [String: Int] = [:]
                for train in trainsOfLine {
                    if let countdownStr = directCountdown(for: train) {
                        let mins: Int
                        if countdownStr == "ora" {
                            mins = 0
                        } else {
                            let numStr = countdownStr.replacingOccurrences(of: "m", with: "")
                            mins = Int(numStr) ?? 999
                        }
                        let shortDest = shortDestination(train.destination)
                        if mins >= 0 {
                            let currentMin = destMinMins[shortDest] ?? Int.max
                            if mins < currentMin {
                                destMinMins[shortDest] = mins
                            }
                        }
                    }
                }
                
                if !destMinMins.isEmpty {
                    let sortedDests = destMinMins.sorted { $0.value < $1.value }
                    let arrivalStrings = sortedDests.map { dest, mins in
                        let timeText = mins == 0 ? "ora" : "\(mins)m"
                        return "\(dest) \(timeText)"
                    }
                    result.append(LineArrivalInfo(id: lineId, arrivals: arrivalStrings))
                }
            }
            return result
        }()
        
        VStack(alignment: .leading, spacing: 16) {
            // Intestazione con info dinamica sul prossimo treno (Dashboard Compatta)
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                    .padding(.top, 4)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(statusMessage)
                        .font(.caption.bold())
                        .foregroundColor(color)
                    
                    if !lineArrivals.isEmpty {
                        ForEach(lineArrivals) { info in
                            HStack(spacing: 8) {
                                SuburbanLineBadge(id: info.id)
                                
                                Text(info.arrivals.joined(separator: "   ·   "))
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                Text("Ritardo medio: \(avgDelay)'")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }
            
            // Allerta Waze del Passante se congestionato
            if isCongested {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text("Possibile accodamento dovuto a forti ritardi. Valuta metropolitane (M3/M4) per attraversare Milano.")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding(8)
                .background(Color.red.opacity(0.08))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
            }
            
            // Termometro verticale dinamico
            VStack(spacing: 0) {
                ForEach(activeStationsList, id: \.self) { stationName in
                    let isSelected = (stationName == cleanRefName)
                    
                    let trainsAtStation = manager.passanteTunnelTrains.filter { train in
                        let line = train.category.uppercased()
                        if !manager.selectedSuburbanLines.isEmpty && !manager.selectedSuburbanLines.contains(line) {
                            return false
                        }
                        return getEstimatedStationName(for: train) == stationName
                    }
                    
                    HStack(alignment: .center, spacing: 12) {
                        // 1. Linea del tracciato + nodo della fermata
                        VStack(spacing: 0) {
                            if stationName != activeStationsList.first {
                                Rectangle()
                                    .fill(trackColor.opacity(0.8))
                                    .frame(width: 4, height: 16)
                            } else {
                                Spacer()
                                    .frame(height: 16)
                            }
                            
                            ZStack {
                                Circle()
                                    .fill(Color(.systemBackground))
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Circle()
                                            .stroke(trainsAtStation.isEmpty ? trackColor.opacity(0.4) : (isSelected ? .orange : trackColor), lineWidth: isSelected ? 4 : 3)
                                    )
                                    .shadow(color: trackColor.opacity(0.2), radius: 2)
                                
                                if isSelected {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.orange)
                                } else if !trainsAtStation.isEmpty {
                                    PulsingCircle(color: trackColor)
                                        .frame(width: 10, height: 10)
                                } else {
                                    Circle()
                                        .fill(trackColor.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                }
                            }
                            
                            if stationName != activeStationsList.last {
                                Rectangle()
                                    .fill(trackColor.opacity(0.8))
                                    .frame(width: 4, height: 16)
                            } else {
                                Spacer()
                                    .frame(height: 16)
                            }
                        }
                        .frame(width: 24)
                        
                        // 2. Nome della stazione
                        HStack(spacing: 6) {
                            if isSelected {
                                Text("📍")
                                    .font(.caption)
                            }
                            Text(stationName.replacingOccurrences(of: "Passante", with: "").replacingOccurrences(of: "Milano ", with: ""))
                                .font(.system(size: 13, weight: isSelected ? .black : .bold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .frame(width: 150, alignment: .leading)
                        
                        Spacer()
                        
                        // 3. Treni in questa stazione
                        if !trainsAtStation.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(trainsAtStation, id: \.id) { train in
                                        let direction = manager.getPassanteDirection(for: train) ?? "Est"
                                        let isWest = direction == "Ovest"
                                        let line = train.category.uppercased()
                                        let lineColorHex = SuburbanData.shared.allLines.first(where: { $0.id == line })?.hexColor ?? "#8e8e93"
                                        let isLight = ["S4", "S5", "S6", "S8"].contains(line)
                                        let textColor: Color = isLight ? .black : .white
                                        
                                        HStack(spacing: 3) {
                                            if isWest {
                                                Text("←")
                                                    .font(.system(size: 8, weight: .bold))
                                            }
                                            Text(line)
                                                .font(.system(size: 8, weight: .black, design: .rounded))
                                            if !isWest {
                                                Text("→")
                                                    .font(.system(size: 8, weight: .bold))
                                            }
                                            

                                        }
                                        .foregroundColor(textColor)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(Color(hex: lineColorHex))
                                        .cornerRadius(6)
                                        .shadow(color: Color(hex: lineColorHex).opacity(0.3), radius: 2)
                                    }
                                }
                            }
                        } else {
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(isSelected ? Color.orange.opacity(0.06) : Color.clear)
                    .cornerRadius(8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !isSelected {
                            let newStation = stationForName(stationName, manager: manager)
                            manager.selectPassanteStation(newStation)
                            Haptics.play(.medium)
                        }
                    }
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

struct SuburbanLineBadge: View {
    let id: String
    
    var color: Color {
        if let line = SuburbanData.shared.allLines.first(where: { $0.id == id }) {
            return line.color
        }
        return .orange
    }
    
    var textColor: Color {
        let line = id.uppercased()
        let isLight = ["S4", "S5", "S6", "S8"].contains(line)
        return isLight ? .black : .white
    }
    
    var body: some View {
        Text(id)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundColor(textColor)
            .frame(width: 28, height: 18)
            .background(color)
            .cornerRadius(4)
    }
}

fileprivate let passanteOuterStationLookup: [String: (rfiID: String?, vtID: String?)] = [
    // S6 (Novara - Pioltello)
    "Novara": ("1917", "S01017"),
    "Trecate": ("2909", "S01019"),
    "Magenta": ("1618", "S01021"),
    "Vittuone-Arluno": ("3119", "S01023"),
    "Pregnana Milanese": ("381", "S01024"),
    "Rho": ("2345", "S01025"),
    "Segrate": ("3012", "S01065"),
    "Pioltello-Limito": ("3011", "S01066"),
    
    // S5 (Varese - Treviglio)
    "Varese": ("2994", "S01205"),
    "Gazzada-Schianno-Morazzone": ("1413", "S01207"),
    "Castronno": ("1029", "S01208"),
    "Albizzate-Solbiate Arno": ("405", "S01209"),
    "Cavaria-Oggiona-Jerago": ("1046", "S01210"),
    "Gallarate": ("1393", "S01030"),
    "Busto Arsizio": ("766", "S01031"),
    "Legnano": ("1701", "S01203"),
    "Canegrate": ("1702", "S01202"),
    "Parabiago": ("1703", "S01201"),
    "Vanzago-Pogliano": ("1704", "S01200"),
    "Melzo": ("3013", "S01067"),
    "Pozzuolo Martesana": ("3014", "S01068"),
    "Trecella": ("3015", "S01069"),
    "Cassano d'Adda": ("3016", "S01070"),
    "Treviglio": ("1732", "S01071"),
    
    // S1 (Saronno - Lodi)
    "Saronno": (nil, "S01150"),
    "Caronno Pertusella": (nil, "S01151"),
    "Cesate": (nil, "S01152"),
    "Garbagnate Milanese": (nil, "S01153"),
    "Garbagnate Parco delle Groane": (nil, "S01154"),
    "Garbagnate Parco Groane": (nil, "S01154"),
    "Bollate Nord": (nil, "S01155"),
    "Bollate Centro": (nil, "S01156"),
    "Novate Milanese": (nil, "S01157"),
    "Milano Quarto Oggiaro": (nil, "S01158"),
    "San Donato Milanese": ("1836", "S01821"),
    "Borgolombardo": ("1835", "S01822"),
    "San Giuliano Milanese": ("1834", "S01823"),
    "Tavazzano": ("1831", "S01825"),
    "Lodi": ("1830", "S01826"),
    
    // S2 (Mariano Comense - Rogoredo)
    "Mariano Comense": (nil, "S01100"),
    "Cabiate": (nil, "S01101"),
    "Meda": (nil, "S01102"),
    "Seveso": (nil, "S01103"),
    "Cesano Maderno": (nil, "S01104"),
    "Bovisio Masciago-Mombello": (nil, "S01105"),
    "Varedo": (nil, "S01106"),
    "Palazzolo Milanese": (nil, "S01107"),
    "Paderno Dugnano": (nil, "S01108"),
    "Cormano-Cusano Milanino": (nil, "S01109"),
    "Milano Bruzzano": (nil, "S01110"),
    
    // S13 (Bovisa - Pavia)
    "Locate Triulzi": ("1837", "S01831"),
    "Pieve Emanuele": ("3381", "S01832"),
    "Villamaggiore": ("1838", "S01833"),
    "Certosa di Pavia": ("1839", "S01834"),
    "Pavia": ("1840", "S01835"),
    
    // S12 (Cormano - Melegnano)
    "Melegnano": ("1833", "S01824")
]

fileprivate func stationForName(_ name: String, manager: TrainManager) -> Station {
    let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    if let ids = passanteOuterStationLookup[cleanName] {
        return Station(name: cleanName, rfiID: ids.rfiID, vtID: ids.vtID, lat: nil, lon: nil)
    }
    // Special names in the Passante core tunnel
    if cleanName.contains("Garibaldi") {
        return Station(name: cleanName, rfiID: "1714", vtID: "S01647", lat: nil, lon: nil)
    }
    if cleanName.contains("Venezia") {
        return Station(name: cleanName, rfiID: "1723", vtID: "S01649", lat: nil, lon: nil)
    }
    if cleanName.contains("Repubblica") {
        return Station(name: cleanName, rfiID: "1719", vtID: "S01648", lat: nil, lon: nil)
    }
    if cleanName.contains("Lancetti") {
        return Station(name: cleanName, rfiID: "1713", vtID: "S01643", lat: nil, lon: nil)
    }
    if cleanName.contains("Dateo") {
        return Station(name: cleanName, rfiID: "3468", vtID: "S01650", lat: nil, lon: nil)
    }
    if cleanName.contains("Vittoria") {
        return Station(name: cleanName, rfiID: "1718", vtID: "S01633", lat: nil, lon: nil)
    }
    if cleanName.contains("Bovisa") {
        return Station(name: cleanName, rfiID: nil, vtID: "S01201", lat: nil, lon: nil)
    }
    if cleanName.contains("Rogoredo") {
        return Station(name: cleanName, rfiID: "1720", vtID: "S01820", lat: nil, lon: nil)
    }

    // Cerca corrispondenza esatta
    if let rfi = manager.allRFIStations.first(where: { $0.name.lowercased() == cleanName.lowercased() }) {
        return Station(name: rfi.name, rfiID: rfi.rfiID, vtID: rfi.vtID, lat: nil, lon: nil)
    }
    // Cerca corrispondenza parziale (es. "Repubblica" -> "Milano Repubblica")
    if let rfi = manager.allRFIStations.first(where: { $0.name.lowercased().contains(cleanName.lowercased()) }) {
        return Station(name: rfi.name, rfiID: rfi.rfiID, vtID: rfi.vtID, lat: nil, lon: nil)
    }
    return Station(name: cleanName, rfiID: nil, vtID: nil, lat: nil, lon: nil)
}

struct PassanteDepartureBoardView: View {
    @EnvironmentObject var manager: TrainManager
    @EnvironmentObject var locationManager: LocationManager
    @AppStorage("showOuterSuburbanStations") var showOuterSuburbanStations = false
    
    // Stazioni del selettore: stazioni filtrate in base all'asse per evitare disordine
    var relevantStations: [Station] {
        let allStations = manager.passanteStationsForUser
        
        let activeLines = manager.selectedSuburbanLines.filter { ["S1", "S2", "S5", "S6", "S12", "S13"].contains($0) }
        let onlyCertosa = !activeLines.isEmpty && activeLines.allSatisfy { ["S5", "S6"].contains($0) }
        let onlyBovisa = !activeLines.isEmpty && activeLines.allSatisfy { ["S1", "S2", "S12", "S13"].contains($0) }
        
        // Costruiamo i set delle stazioni locali per asse/linea per il filtraggio delle esterne
        let stationsGeographicOrder = [
            "Varese", "Gazzada-Schianno-Morazzone", "Gazzada-Schianno", "Castronno", 
            "Albizzate-Solbiate Arno", "Albizzate-Solbiate A.", "Cavaria-Oggiona-Jerago", 
            "Cavaria-Oggiona-J.", "Gallarate", "Busto Arsizio", "Legnano", "Canegrate", 
            "Parabiago", "Vanzago-Pogliano",
            "Novara", "Trecate", "Magenta", "Vittuone-Arluno", "Pregnana Milanese", "Rho",
            "Saronno", "Caronno Pertusella", "Cesate", "Garbagnate Milanese", 
            "Garbagnate Parco delle Groane", "Garbagnate Parco Groane", "Bollate Nord", 
            "Bollate Centro", "Novate Milanese", "Milano Quarto Oggiaro",
            "Mariano Comense", "Cabiate", "Meda", "Seveso", "Cesano Maderno", 
            "Bovisio Masciago-Mombello", "Varedo", "Palazzolo Milanese", "Paderno Dugnano", 
            "Cormano-Cusano Milanino", "Cusano Milanino", "Milano Bruzzano",
            "Rho Fiera", "Certosa", "Villapizzone", "Milano Bovisa", "Lancetti", 
            "P. Garibaldi Passante", "Repubblica", "Porta Venezia", "Dateo", "Porta Vittoria",
            "Forlanini", "Segrate", "Pioltello-Limito", "Melzo", "Pozzuolo Martesana", 
            "Trecella", "Cassano d'Adda", "Treviglio",
            "Milano Rogoredo", "San Donato Milanese", "Borgolombardo", "San Giuliano Milanese", 
            "Melegnano", "Tavazzano", "Lodi",
            "Locate Triulzi", "Pieve Emanuele", "Villamaggiore", "Certosa di Pavia", "Pavia"
        ]
        
        let s1Sts: Set<String> = ["Saronno", "Caronno Pertusella", "Cesate", "Garbagnate Milanese", "Garbagnate Parco delle Groane", "Garbagnate Parco Groane", "Bollate Nord", "Bollate Centro", "Novate Milanese", "Milano Quarto Oggiaro", "Milano Bovisa", "Lancetti", "P. Garibaldi Passante", "Repubblica", "Porta Venezia", "Dateo", "Porta Vittoria", "Milano Rogoredo", "San Donato Milanese", "Borgolombardo", "San Giuliano Milanese", "Tavazzano", "Lodi"]
        let s2Sts: Set<String> = ["Mariano Comense", "Cabiate", "Meda", "Seveso", "Cesano Maderno", "Bovisio Masciago-Mombello", "Varedo", "Palazzolo Milanese", "Paderno Dugnano", "Cormano-Cusano Milanino", "Milano Bruzzano", "Milano Bovisa", "Lancetti", "P. Garibaldi Passante", "Repubblica", "Porta Venezia", "Dateo", "Porta Vittoria", "Milano Rogoredo"]
        let s5Sts: Set<String> = ["Varese", "Gazzada-Schianno-Morazzone", "Gazzada-Schianno", "Castronno", "Albizzate-Solbiate Arno", "Albizzate-Solbiate A.", "Cavaria-Oggiona-Jerago", "Cavaria-Oggiona-J.", "Gallarate", "Busto Arsizio", "Legnano", "Canegrate", "Parabiago", "Vanzago-Pogliano", "Rho", "Rho Fiera", "Certosa", "Villapizzone", "Lancetti", "P. Garibaldi Passante", "Repubblica", "Porta Venezia", "Dateo", "Porta Vittoria", "Forlanini", "Segrate", "Pioltello-Limito", "Melzo", "Pozzuolo Martesana", "Trecella", "Cassano d'Adda", "Treviglio"]
        let s6Sts: Set<String> = ["Novara", "Trecate", "Magenta", "Vittuone-Arluno", "Pregnana Milanese", "Rho", "Rho Fiera", "Certosa", "Villapizzone", "Lancetti", "P. Garibaldi Passante", "Repubblica", "Porta Venezia", "Dateo", "Porta Vittoria", "Forlanini", "Segrate", "Pioltello-Limito"]
        let s12Sts: Set<String> = ["Cormano-Cusano Milanino", "Milano Bruzzano", "Milano Bovisa", "Lancetti", "P. Garibaldi Passante", "Repubblica", "Porta Venezia", "Dateo", "Porta Vittoria", "Milano Rogoredo", "San Donato Milanese", "Borgolombardo", "San Giuliano Milanese", "Melegnano"]
        let s13Sts: Set<String> = ["Milano Bovisa", "Lancetti", "P. Garibaldi Passante", "Repubblica", "Porta Venezia", "Dateo", "Porta Vittoria", "Milano Rogoredo", "Locate Triulzi", "Pieve Emanuele", "Villamaggiore", "Certosa di Pavia", "Pavia"]
        
        let filteredNames: [String]
        if showOuterSuburbanStations {
            if onlyCertosa {
                var certosaStations = Set<String>()
                if activeLines.contains("S5") { certosaStations.formUnion(s5Sts) }
                if activeLines.contains("S6") { certosaStations.formUnion(s6Sts) }
                
                let filtered = certosaStations.filter { stationName in
                    for lineId in activeLines {
                        let lineStations = lineId == "S5" ? s5Sts : s6Sts
                        if lineStations.contains(stationName) {
                            let hidden = manager.hiddenSuburbanStations[lineId] ?? []
                            if !hidden.contains(stationName) {
                                return true
                            }
                        }
                    }
                    return false
                }
                filteredNames = stationsGeographicOrder.filter { filtered.contains($0) }
            } else if onlyBovisa {
                var bovisaStations = Set<String>()
                if activeLines.contains("S1") { bovisaStations.formUnion(s1Sts) }
                if activeLines.contains("S2") { bovisaStations.formUnion(s2Sts) }
                if activeLines.contains("S12") { bovisaStations.formUnion(s12Sts) }
                if activeLines.contains("S13") { bovisaStations.formUnion(s13Sts) }
                
                let filtered = bovisaStations.filter { stationName in
                    for lineId in activeLines {
                        let lineStations: Set<String>
                        switch lineId {
                        case "S1": lineStations = s1Sts
                        case "S2": lineStations = s2Sts
                        case "S12": lineStations = s12Sts
                        default: lineStations = s13Sts
                        }
                        if lineStations.contains(stationName) {
                            let hidden = manager.hiddenSuburbanStations[lineId] ?? []
                            if !hidden.contains(stationName) {
                                return true
                            }
                        }
                    }
                    return false
                }
                filteredNames = stationsGeographicOrder.filter { filtered.contains($0) }
            } else {
                filteredNames = ["Lancetti", "P. Garibaldi Passante", "Repubblica", "Porta Venezia", "Dateo", "Porta Vittoria"]
            }
        } else {
            if onlyCertosa {
                filteredNames = ["Rho Fiera", "Certosa", "Villapizzone", "Lancetti", "P. Garibaldi Passante", "Repubblica", "Porta Venezia", "Dateo", "Porta Vittoria", "Forlanini"]
            } else if onlyBovisa {
                filteredNames = ["Milano Bovisa", "Lancetti", "P. Garibaldi Passante", "Repubblica", "Porta Venezia", "Dateo", "Porta Vittoria", "Milano Rogoredo"]
            } else {
                filteredNames = ["Lancetti", "P. Garibaldi Passante", "Repubblica", "Porta Venezia", "Dateo", "Porta Vittoria"]
            }
        }
        
        let filteredStations = filteredNames.map { name -> Station in
            if let existing = allStations.first(where: { $0.name == name }) {
                return existing
            }
            return stationForName(name, manager: manager)
        }
        
        return filteredStations
    }
    
    var body: some View {
        VStack(spacing: 12) {
            
            // --- Selettore stazione (solo stazioni delle linee dell'utente) ---
            VStack(alignment: .leading, spacing: 8) {
                Text("Tabellone — seleziona stazione")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    ScrollViewReader { proxy in
                        HStack(spacing: 8) {
                            ForEach(relevantStations) { station in
                                let isSelected = manager.selectedPassanteStation.name == station.name
                                Button {
                                    Haptics.play(.medium)
                                    manager.selectPassanteStation(station)
                                } label: {
                                    HStack(spacing: 4) {
                                        if isSelected {
                                            Image(systemName: "mappin.circle.fill")
                                                .font(.caption)
                                        }
                                        Text(station.name)
                                            .fontWeight(isSelected ? .bold : .medium)
                                    }
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(isSelected ? Color.orange : Color(.secondarySystemBackground))
                                    .foregroundColor(isSelected ? .white : .primary)
                                    .cornerRadius(16)
                                 }
                                .buttonStyle(PlainButtonStyle())
                                .id(station.name)
                            }
                        }
                        .padding(.vertical, 2)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                proxy.scrollTo(manager.selectedPassanteStation.name)
                            }
                        }
                        .onChange(of: manager.selectedPassanteStation.name) { _, newName in
                            withAnimation { proxy.scrollTo(newName) }
                        }
                    }
                }
            }
            
            Divider()
            
            // --- Partenze: lista pulita per destinazione ---
            let allTrains = manager.passanteTrains
            if manager.isLoadingPassanteBoard && allTrains.isEmpty {
                HStack {
                    Spacer()
                    ProgressView("Caricamento treni...")
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if allTrains.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "tram.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Nessun treno in partenza")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                let activeLines = manager.selectedSuburbanLines
                let onlyCertosa = !activeLines.isEmpty && activeLines.allSatisfy { ["S5", "S6"].contains($0) }
                let onlyBovisa = !activeLines.isEmpty && activeLines.allSatisfy { ["S1", "S2", "S12", "S13"].contains($0) }
                
                if onlyCertosa {
                    VStack(spacing: 12) {
                        // Box 1: Ovest (Rho)
                        PassanteBranchView(
                            label: "← Direzione Ovest (Rho / Varese)",
                            color: .orange,
                            trains: manager.passanteTrainsViaRho.filter { t in
                                let cat = t.category.uppercased()
                                return activeLines.contains(cat) || cat == "S" || cat == "REG" || cat == "RV"
                            },
                            isLarge: true
                        )
                        // Box 2: Est (Forlanini)
                        PassanteBranchView(
                            label: "Direzione Est (Forlanini / Treviglio) →",
                            color: .orange,
                            trains: manager.passanteTrainsViaForlanini.filter { t in
                                let cat = t.category.uppercased()
                                return activeLines.contains(cat) || cat == "S" || cat == "REG" || cat == "RV"
                            },
                            isLarge: true
                        )
                    }
                } else if onlyBovisa {
                    VStack(spacing: 12) {
                        // Box 1: Ovest (Bovisa)
                        PassanteBranchView(
                            label: "← Direzione Ovest (Bovisa / Saronno)",
                            color: .red,
                            trains: manager.passanteTrainsViaBovisa.filter { t in
                                let cat = t.category.uppercased()
                                return activeLines.contains(cat) || cat == "S" || cat == "REG" || cat == "RV"
                            },
                            isLarge: true
                        )
                        // Box 2: Est (Rogoredo)
                        PassanteBranchView(
                            label: "Direzione Est (Rogoredo / Pavia / Lodi) →",
                            color: .red,
                            trains: manager.passanteTrainsViaRogoredo.filter { t in
                                let cat = t.category.uppercased()
                                return activeLines.contains(cat) || cat == "S" || cat == "REG" || cat == "RV"
                            },
                            isLarge: true
                        )
                    }
                } else {
                    // Griglia 2x2 originale
                    VStack(spacing: 10) {
                        HStack(alignment: .top, spacing: 10) {
                            // ← BOVISA
                            PassanteBranchView(
                                label: "← Bovisa",
                                color: .red,
                                trains: manager.passanteTrainsViaBovisa.filter { t in
                                    let cat = t.category.uppercased()
                                    return manager.selectedSuburbanLines.isEmpty || manager.selectedSuburbanLines.contains(cat) || cat == "S" || cat == "REG" || cat == "RV"
                                }
                            )
                            // → FORLANINI
                            PassanteBranchView(
                                label: "Forlanini →",
                                color: .orange,
                                trains: manager.passanteTrainsViaForlanini.filter { t in
                                    let cat = t.category.uppercased()
                                    return manager.selectedSuburbanLines.isEmpty || manager.selectedSuburbanLines.contains(cat) || cat == "S" || cat == "REG" || cat == "RV"
                                }
                            )
                        }
                        HStack(alignment: .top, spacing: 10) {
                            // ← RHO
                            PassanteBranchView(
                                label: "← Rho",
                                color: .orange,
                                trains: manager.passanteTrainsViaRho.filter { t in
                                    let cat = t.category.uppercased()
                                    return manager.selectedSuburbanLines.isEmpty || manager.selectedSuburbanLines.contains(cat) || cat == "S" || cat == "REG" || cat == "RV"
                                }
                            )
                            // → ROGOREDO
                            PassanteBranchView(
                                label: "Rogoredo →",
                                color: .red,
                                trains: manager.passanteTrainsViaRogoredo.filter { t in
                                    let cat = t.category.uppercased()
                                    return manager.selectedSuburbanLines.isEmpty || manager.selectedSuburbanLines.contains(cat) || cat == "S" || cat == "REG" || cat == "RV"
                                }
                            )
                        }
                        
                        // Treni non classificati (se presenti)
                        let filteredBovisa = manager.passanteTrainsViaBovisa.filter { t in manager.selectedSuburbanLines.isEmpty || manager.selectedSuburbanLines.contains(t.category.uppercased()) }
                        let filteredRho = manager.passanteTrainsViaRho.filter { t in manager.selectedSuburbanLines.isEmpty || manager.selectedSuburbanLines.contains(t.category.uppercased()) }
                        let filteredForlanini = manager.passanteTrainsViaForlanini.filter { t in manager.selectedSuburbanLines.isEmpty || manager.selectedSuburbanLines.contains(t.category.uppercased()) }
                        let filteredRogoredo = manager.passanteTrainsViaRogoredo.filter { t in manager.selectedSuburbanLines.isEmpty || manager.selectedSuburbanLines.contains(t.category.uppercased()) }
                        
                        let classified = filteredBovisa + filteredRho + filteredForlanini + filteredRogoredo
                        let unclassified = allTrains.filter { t in
                            let isPreferred = manager.selectedSuburbanLines.isEmpty || manager.selectedSuburbanLines.contains(t.category.uppercased())
                            return isPreferred && !classified.contains(where: { $0.id == t.id })
                        }
                        if !unclassified.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Altre partenze")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                ForEach(Array(unclassified.prefix(3).enumerated()), id: \.element.id) { _, train in
                                    PassanteTrainRowView(train: train)
                                }
                            }
                        }
                    }
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
    
    var delayMinutes: Int {
        let s = train.delay.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: "'", with: "")
        if s.lowercased().contains("orario") { return 0 }
        return Int(s) ?? 0
    }
    
    var isCancelled: Bool {
        train.delay.lowercased().contains("soppresso") || train.delay.lowercased().contains("cancellato")
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // Badge linea
            SuburbanLineBadge(id: train.category.isEmpty ? "S" : train.category)
            
            // Destinazione + orario partenza
            VStack(alignment: .leading, spacing: 2) {
                Text(SharedFormatters.formatDestination(train.destination))
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                
                Text("Part. \(train.time)")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Stato ritardo
            if isCancelled {
                Text("Soppresso")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .cornerRadius(6)
            } else if delayMinutes > 0 {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("+\(delayMinutes)'")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(.red)
                    Text("ritardo")
                        .font(.system(size: 8))
                        .foregroundColor(.red.opacity(0.8))
                }
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 8)
        .opacity(isCancelled ? 0.5 : 1.0)
    }
}

/// Card compatta per un singolo ramo del passante (es. "← Bovisa", "Rogoredo →")
struct PassanteBranchView: View {
    let label: String
    let color: Color
    let trains: [Train]
    var isLarge: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: isLarge ? 10 : 6) {
            // Etichetta ramo
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 3, height: isLarge ? 16 : 12)
                Text(label)
                    .font(.system(size: isLarge ? 12 : 9, weight: .bold))
                    .foregroundColor(color)
                    .textCase(.uppercase)
            }
            
            if trains.isEmpty {
                Text("—")
                    .font(.system(size: isLarge ? 12 : 9))
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.top, 2)
            } else {
                ForEach(Array(trains.prefix(3).enumerated()), id: \.element.id) { idx, train in
                    PassanteBranchTrainRow(train: train, isLarge: isLarge)
                    if idx < min(trains.count, 3) - 1 {
                        Divider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(isLarge ? 16 : 8)
        .background(color.opacity(isLarge ? 0.1 : 0.07))
        .cornerRadius(isLarge ? 14 : 10)
    }
}

/// Riga treno ultra-compatta per i box del ramo
struct PassanteBranchTrainRow: View {
    let train: Train
    var isLarge: Bool = false
    
    var delayMinutes: Int {
        let s = train.delay.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: "'", with: "")
        if s.lowercased().contains("orario") { return 0 }
        return Int(s) ?? 0
    }
    var isCancelled: Bool {
        train.delay.lowercased().contains("soppresso") || train.delay.lowercased().contains("cancellato")
    }
    
    var body: some View {
        HStack(spacing: isLarge ? 8 : 5) {
            SuburbanLineBadge(id: train.category.isEmpty ? "S" : train.category)
                .scaleEffect(isLarge ? 1.2 : 1.0)
                .frame(width: isLarge ? 34 : 28, height: isLarge ? 22 : 18)
            
            VStack(alignment: .leading, spacing: isLarge ? 3 : 1) {
                Text(SharedFormatters.formatDestination(train.destination))
                    .font(.system(size: isLarge ? 14 : 11, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text("Part. \(train.time)")
                    .font(.system(size: isLarge ? 11 : 9, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isCancelled {
                Text("CANCELLATO")
                    .font(.system(size: isLarge ? 12 : 9, weight: .bold))
                    .foregroundColor(.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.red.opacity(0.12))
                    .cornerRadius(4)
            } else if delayMinutes > 0 {
                HStack(spacing: 3) {
                    Text("+\(delayMinutes)'")
                        .font(.system(size: isLarge ? 15 : 11, weight: .black, design: .rounded))
                        .foregroundColor(.red)
                    if isLarge {
                        Text("rit.")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.red.opacity(0.8))
                    }
                }
            } else {
                HStack(spacing: 4) {
                    if isLarge {
                        Text("IN ORARIO")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green)
                    }
                    Image(systemName: "checkmark.circle.fill")
                        .font(isLarge ? .body : .caption2)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, isLarge ? 6 : 2)
        .opacity(isCancelled ? 0.5 : 1.0)
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
            
            let details = manager.loadedSmartRouteDetails[route.id]
            if manager.isLoadingSmartRoutes && details == nil {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 15)
            } else if let details = details {
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
                                    Text(SharedFormatters.formatDestination(train.destination))
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
                                Text("Cambio a \(SharedFormatters.formatDestination(exchange.name).replacingOccurrences(of: " Passante", with: ""))")
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
                                
                                Text(SharedFormatters.formatDestination(details.originStation.name))
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
                                
                                Text(SharedFormatters.formatDestination(details.destinationStation.name))
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
    
    @State private var originName = ""
    @State private var originID = ""
    @State private var destName = ""
    @State private var destID = ""
    
    @State private var showOriginSearch = false
    @State private var showDestSearch = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Tratta")) {
                    Button(action: { showOriginSearch = true }) {
                        HStack {
                            Image(systemName: "circle.fill")
                                .foregroundColor(.orange)
                                .font(.caption2)
                            Text(originName.isEmpty ? "Seleziona Stazione di Partenza" : originName)
                                .fontWeight(originName.isEmpty ? .regular : .semibold)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: { showDestSearch = true }) {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.red)
                                .font(.subheadline)
                            Text(destName.isEmpty ? "Seleziona Stazione di Arrivo" : destName)
                                .fontWeight(destName.isEmpty ? .regular : .semibold)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        if !originID.isEmpty && !destID.isEmpty && originID != destID {
                            Haptics.play(.medium)
                            manager.toggleFavoriteRoute(originName: originName, originID: originID, destName: destName, destID: destID)
                            dismiss()
                        }
                    }) {
                        Text("Salva Tratta nei Preferiti")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(originID.isEmpty || destID.isEmpty || originID == destID ? Color.gray : Color.orange)
                    .disabled(originID.isEmpty || destID.isEmpty || originID == destID)
                }
            }
            .navigationTitle("Aggiungi Tratta Preferita")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
            }
            .sheet(isPresented: $showOriginSearch) {
                StationSelectionSheet(selectedName: $originName, selectedID: $originID, title: "Partenza")
            }
            .sheet(isPresented: $showDestSearch) {
                StationSelectionSheet(selectedName: $destName, selectedID: $destID, title: "Arrivo")
            }
        }
    }
}

struct PassanteTunnelStatusButton: View {
    @EnvironmentObject var manager: TrainManager
    @EnvironmentObject var locationManager: LocationManager
    @Binding var showThermometerSheet: Bool
    
    var body: some View {
        Button {
            Haptics.play(.light)
            if let nearby = locationManager.nearbyStation,
               manager.passanteStationsForUser.contains(where: { $0.name == nearby.name }),
               let st = manager.passanteStationsForUser.first(where: { $0.name == nearby.name }) {
                manager.selectedPassanteStation = st
            }
            showThermometerSheet = true
            Task { await manager.fetchPassanteLive() }
        } label: {
            Image(systemName: "info.circle.fill")
                .foregroundColor(Color(hex: manager.passanteTunnelHealthColor).opacity(0.8))
                .font(.body)
                .padding(.vertical, 8)
                .padding(.leading, 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PassanteTunnelStatusHeaderView: View {
    @EnvironmentObject var manager: TrainManager
    @State private var showThermometerSheet = false
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: manager.passanteTunnelHealthColor))
                .frame(width: 8, height: 8)
            
            Text("\(manager.passanteTunnelHealthMessage)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: manager.passanteTunnelHealthColor))
                .lineLimit(1)
            
            Spacer()
            
            PassanteTunnelStatusButton(showThermometerSheet: $showThermometerSheet)
        }
        .padding(.leading, 12)
        .padding(.trailing, 12)
        .padding(.vertical, 0)
        .background(Color(hex: manager.passanteTunnelHealthColor).opacity(0.12))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .sheet(isPresented: $showThermometerSheet) {
            PassanteTunnelDetailView()
                .environmentObject(manager)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

struct PassanteTunnelDetailView: View {
    @EnvironmentObject var manager: TrainManager
    @Environment(\.dismiss) var dismiss
    @AppStorage("showOuterSuburbanStations") var showOuterSuburbanStations = false
    
    @State private var currentTab = 0
    
    // Timer di aggiornamento automatico ogni 15 secondi (attivo solo quando la vista è aperta)
    let timer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Segmented Picker nativo
                Picker("Sezione", selection: $currentTab) {
                    Text("Mappa Linea").tag(0)
                    Text("Treni in Arrivo").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 14)
                
                // Mostra stazioni esterne toggle (only shown if Certosa or Bovisa axes are selected, not mixed)
                let activeLines = manager.selectedSuburbanLines.filter { ["S1", "S2", "S5", "S6", "S12", "S13"].contains($0) }
                let isMixed = !activeLines.isEmpty && 
                              !(activeLines.allSatisfy { ["S5", "S6"].contains($0) } || 
                                activeLines.allSatisfy { ["S1", "S2", "S12", "S13"].contains($0) })
                
                if !isMixed {
                    Toggle(isOn: $showOuterSuburbanStations) {
                        HStack(spacing: 8) {
                            Image(systemName: "map.fill")
                                .foregroundColor(.orange)
                            Text("Mostra stazioni esterne")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground).opacity(0.4))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                if currentTab == 0 {
                    ScrollView {
                        VStack(spacing: 16) {
                            PassanteTunnelThermometerView(
                                statusMessage: manager.passanteTunnelHealthMessage,
                                statusColorHex: manager.passanteTunnelHealthColor,
                                avgDelay: manager.passanteTunnelAverageDelay
                            )
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            if manager.useSpecialPassanteView {
                                PassanteDepartureBoardView()
                            } else {
                                StationBoardView(station: manager.selectedPassanteStation)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Dettagli Tunnel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
            .onReceive(timer) { _ in
                // Esegue il refresh in background dei treni nel tunnel e dei loro stati live
                Task {
                    await manager.fetchPassanteLive()
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
            
            let details = manager.loadedSmartRouteDetails[route.id]
            if manager.isLoadingSmartRoutes && details == nil {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 10)
            } else if let details = details {
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
                                Text(SharedFormatters.formatDestination(train.destination))
                                    .font(.system(size: 11, weight: .bold))
                                    .lineLimit(1)
                                
                                // Testo descrittivo del ritardo
                                if delayMin > 0 {
                                    Text("Ritardo di \(delayMin)' (previsto \(train.time) da \(SharedFormatters.formatDestination(route.originName)))")
                                        .font(.system(size: 9))
                                        .foregroundColor(.red)
                                } else {
                                    Text("In orario da \(SharedFormatters.formatDestination(route.originName))")
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
                    .autocorrectionDisabled(true)
                    .onChange(of: text) { oldValue, newValue in
                        isDropdownOpen = true
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

struct ProfileView: View {
    @EnvironmentObject var manager: TrainManager
    @Environment(\.dismiss) var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @StateObject private var tipManager = TipManager()
    @State private var showFeedbackSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Personalizzazione")) {
                    NavigationLink(destination: CustomizeDashboardView()) {
                        Label("Personalizza Dashboard", systemImage: "slider.horizontal.3")
                            .font(.headline)
                    }
                    NavigationLink(destination: CustomizePassanteView()) {
                        Label("Personalizza Passante", systemImage: "tram.fill")
                            .font(.headline)
                    }
                }
                
                Section(header: Text("Sincronizzazione")) {
                    Toggle(isOn: Binding(
                        get: { manager.iCloudSyncEnabled },
                        set: { newValue in
                            manager.iCloudSyncEnabled = newValue
                            manager.saveFavorites()
                            Haptics.play(.medium)
                        }
                    )) {
                        Label("Salva preferenze su iCloud Drive", systemImage: "icloud.fill")
                            .foregroundColor(.blue)
                            .font(.headline)
                    }
                }
                
                Section(header: Text("Il Progetto In Orario")) {
                    Text("Ho creato In Orario per rendere un po’ più semplice la vita di chi prende il treno ogni giorno. L’app mostra le stesse informazioni presenti sui tabelloni in stazione, aggiornate in tempo reale.\n\nLa sviluppo e la mantengo da solo, nel mio tempo libero. Ho scelto di offrirla gratuitamente e senza pubblicità, ma mantenerla attiva comporta alcuni costi.\n\nSe In Orario ti aiuta a partire più sereno, a evitare attese inutili o semplicemente a viaggiare con maggiore tranquillità, una piccola donazione è un aiuto concreto per continuare a farla crescere.\n\nGrazie davvero ❤️")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(4)
                        .padding(.vertical, 4)
                }
                
                Section(header: Text("Offrimi un Caffè")) {
                    if tipManager.products.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView("Caricamento offerte...")
                                .padding()
                            Spacer()
                        }
                    } else {
                        ForEach(tipManager.products, id: \.id) { product in
                            Button(action: {
                                Task {
                                    await tipManager.purchase(product)
                                }
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(defaultName(for: product.id))
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text(defaultDescription(for: product.id))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if tipManager.purchaseState == .purchasing {
                                        ProgressView()
                                    } else {
                                        Text(product.displayPrice)
                                            .font(.subheadline.bold())
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.orange)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .disabled(tipManager.purchaseState == .purchasing)
                        }
                    }
                }
                
                Section(header: Text("Supporto e Info")) {
                    Button(action: {
                        Haptics.play(.medium)
                        showFeedbackSheet = true
                    }) {
                        Label("Segnala Bug o Feedback", systemImage: "ladybug.fill")
                            .foregroundColor(.red)
                            .font(.headline)
                    }
                    
                    Button(action: {
                        Haptics.play(.medium)
                        hasCompletedOnboarding = false
                        dismiss()
                    }) {
                        Label("Riproduci Tutorial Iniziale", systemImage: "graduationcap.fill")
                            .foregroundColor(.blue)
                            .font(.headline)
                    }
                }
            }
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") {
                        dismiss()
                    }.fontWeight(.bold)
                }
            }
            .task {
                await tipManager.fetchProducts()
            }
            .alert("Grazie di cuore! ❤️", isPresented: Binding(
                get: { tipManager.purchaseState == .success },
                set: { if !$0 { tipManager.resetState() } }
            )) {
                Button("Prego!", role: .cancel) {}
            } message: {
                Text("Il tuo supporto è fondamentale per coprire i costi di gestione e sostenere il futuro di In Orario. Buon viaggio!")
            }
            .alert("Errore", isPresented: Binding(
                get: {
                    if case .error = tipManager.purchaseState { return true }
                    return false
                },
                set: { if !$0 { tipManager.resetState() } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                if case .error(let msg) = tipManager.purchaseState {
                    Text(msg)
                }
            }
            .sheet(isPresented: $showFeedbackSheet) {
                FeedbackFormView()
            }
        }
    }
    
    private func defaultName(for id: String) -> String {
        switch id {
        case "tip.cappuccino": return "Cappuccino 🥛"
        case "tip.colazione": return "Colazione Pendolare 🥐"
        default: return "Mancia generica"
        }
    }
    
    private func defaultDescription(for id: String) -> String {
        switch id {
        case "tip.cappuccino": return "Un aiuto per coprire i costi dei server."
        case "tip.colazione": return "Caffè e brioche per dare il massimo dell'energia."
        default: return "Sostieni lo sviluppo dell'app."
        }
    }
}

struct FeedbackFormView: View {
    @Environment(\.dismiss) var dismiss
    @State private var category = "Bug"
    @State private var message = ""
    @State private var contact = ""
    @State private var isSending = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Tipo di Segnalazione")) {
                    Picker("Categoria", selection: $category) {
                        Text("Bug 🐛").tag("Bug")
                        Text("Suggerimento 💡").tag("Suggestion")
                        Text("Altro 💬").tag("Other")
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Dettagli")) {
                    TextEditor(text: $message)
                        .frame(height: 150)
                        .overlay(
                            Group {
                                if message.isEmpty {
                                    Text("Descrivi qui cosa è successo o il tuo suggerimento...")
                                        .foregroundColor(.gray.opacity(0.5))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 8)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )
                }
                
                Section(header: Text("Contatto (Opzionale)"), footer: Text("Inserisci un'email se desideri essere ricontattato.")) {
                    TextField("Tua email", text: $contact)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                Section {
                    Button(action: sendFeedback) {
                        if isSending {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            Text("Invia Segnalazione")
                                .bold()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                }
            }
            .navigationTitle("Segnala Bug o Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
            }
            .alert("Grazie mille! ❤️", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("La tua segnalazione è stata inviata con successo direttamente agli sviluppatori.")
            }
            .alert("Errore di Invio", isPresented: $showErrorAlert) {
                Button("Riprova", role: .cancel) {}
            } message: {
                Text("Non è stato possibile inviare il feedback. Verifica la tua connessione internet o riprova più tardi.")
            }
        }
    }
    
    private func sendFeedback() {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSending = true
        Haptics.play(.medium)
        
        let payload: [String: String] = [
            "category": category,
            "message": message,
            "contact": contact
        ]
        
        guard let url = URL(string: "https://inorario.toreroclub.com/feedback") else {
            isSending = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            isSending = false
            showErrorAlert = true
            return
        }
        
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    isSending = false
                    showSuccessAlert = true
                    Haptics.notify(.success)
                } else {
                    isSending = false
                    showErrorAlert = true
                    Haptics.notify(.error)
                }
            } catch {
                isSending = false
                showErrorAlert = true
                Haptics.notify(.error)
            }
        }
    }
}

struct CustomizeDashboardView: View {
    @EnvironmentObject var manager: TrainManager
    @State private var showNewSmartRouteSheet = false
    @State private var homeDestInput = ""
    
    var body: some View {
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
                if manager.favoriteRoutes.isEmpty {
                    Text("Nessuna tratta preferita configurata.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(manager.favoriteRoutes) { route in
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill").foregroundColor(.yellow)
                                Text("\(route.originName) ➔ \(route.destinationName)")
                                    .font(.subheadline.bold())
                            }
                            Spacer()
                            Button(role: .destructive) {
                                Haptics.play(.medium)
                                manager.toggleFavoriteRoute(originName: route.originName, originID: route.originID, destName: route.destinationName, destID: route.destinationID)
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
        }
        .navigationTitle("Dashboard")
        .environment(\.editMode, .constant(.active))
        .sheet(isPresented: $showNewSmartRouteSheet) {
            PassanteQuickSetupView()
                .environmentObject(manager)
        }
        .onAppear {
            homeDestInput = manager.homeDestinationStationName
        }
    }
}

struct CustomizePassanteView: View {
    @EnvironmentObject var manager: TrainManager
    
    var body: some View {
        List {
            Section(header: Text("Vista Speciale Stazioni"), footer: Text("Quando attivo, il passante raggruppa le partenze in Ovest ed Est. Se disattivato, vedrai la lista classica Arrivi/Partenze.")) {
                Toggle(isOn: Binding(
                    get: { manager.useSpecialPassanteView },
                    set: { newValue in
                        manager.useSpecialPassanteView = newValue
                        manager.saveFavorites()
                        Haptics.play(.medium)
                    }
                )) {
                    Label("Mostra Vista Speciale Passante", systemImage: "eye.fill")
                        .foregroundColor(.orange)
                }
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
        .navigationTitle("Personalizza Passante")
    }
}
