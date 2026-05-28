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
    
    @State private var animationScale: CGFloat = 1.0
    @State private var animationOpacity: Double = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            Text(station.name.replacingOccurrences(of: "Milano ", with: "").replacingOccurrences(of: " Passante", with: ""))
                .font(.system(size: 13, weight: isNearby ? .bold : .medium))
                .foregroundColor(isNearby ? .orange : .primary)
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
                        .fill(isFirst ? Color.clear : Color.orange.opacity(0.6))
                        .frame(height: 5)
                    Rectangle()
                        .fill(isLast ? Color.clear : Color.orange.opacity(0.6))
                        .frame(height: 5)
                }
                
                Circle()
                    .strokeBorder(isNearby ? Color.orange : Color.gray.opacity(0.5), lineWidth: isNearby ? 4 : 2)
                    .background(Circle().fill(isNearby ? Color.orange : Color(.systemBackground)))
                    .frame(width: 16, height: 16)
                    .scaleEffect(isNearby ? animationScale : 1.0)
                    .shadow(color: isNearby ? .orange.opacity(0.8) : .clear, radius: isNearby ? (animationScale * 5) : 0)
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
            List {
                ForEach(manager.sectionOrder, id: \.self) { section in
                    Text(section.rawValue).font(.headline)
                }
                .onMove { from, to in
                    Haptics.play(.medium)
                    manager.sectionOrder.move(fromOffsets: from, toOffset: to)
                    manager.saveSectionOrder()
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Ordina Dashboard")
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

