import SwiftUI
import Combine

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
            SuburbanLineBadge(id: train.category.isEmpty ? "S" : train.category)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(SharedFormatters.formatDestination(train.destination))
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                
                Text("Part. \(train.time)")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
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
