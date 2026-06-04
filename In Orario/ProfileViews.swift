import SwiftUI
import StoreKit

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
        
        guard let url = URL(string: "https://gestioneinorario.toreroclub.com/feedback") else {
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
                let allStations = SuburbanData.shared.allLines.flatMap { $0.stations.map { $0.name.capitalized } } + manager.allRFIStations.map { $0.name.capitalized }
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

