import SwiftUI

struct OnboardingPage: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let iconName: String
    let iconColor: Color
}

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @State private var currentPage = 0
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var manager: TrainManager
    
    let pages = [
        OnboardingPage(
            title: "Benvenuto su In Orario",
            description: "Il tuo compagno ideale per viaggiare in treno. Nessuna stima statistica: orari in Real-Time assoluto e calcolo dei ritardi minuto per minuto.",
            iconName: "train.side.front.car",
            iconColor: .blue
        ),
        OnboardingPage(
            title: "Treni Suburbani di Milano",
            description: "Personalizza le linee suburbane. Se le disabiliti tutte, la sezione Passante scomparirà per mantenere la tua Home sempre pulitissima.",
            iconName: "slider.horizontal.3",
            iconColor: .green
        ),
        OnboardingPage(
            title: "Stazione di Casa / Lavoro",
            description: "Cerca e salva la tua stazione preferita. Quando attivi il filtro Casa 🏠, l'app mostrerà solo i treni diretti qui.",
            iconName: "house.fill",
            iconColor: .orange
        ),
        OnboardingPage(
            title: "Le Tue Tratte Preferite",
            description: "Salva le tratte generiche (es. Magenta ➔ Milano Porta Garibaldi) slegate dagli orari per cercarle all'istante in tempo reale.",
            iconName: "star.fill",
            iconColor: .yellow
        ),
        OnboardingPage(
            title: "Live Activities & Tunnel",
            description: "Segui lo stato del tuo treno in tempo reale sulla Schermata di Blocco e sulla Dynamic Island con le Live Activities. Esplora lo stato del Passante con la mappa termometrica live!",
            iconName: "iphone.circle.fill",
            iconColor: .purple
        ),
        OnboardingPage(
            title: "Metro & Smart Routes",
            description: "La prima app che integra tutti gli orari della metropolitana di Milano. Inoltre, il motore di ricerca troverà i percorsi più intelligenti combinando treni e mezzi urbani!",
            iconName: "tram.fill",
            iconColor: .teal
        ),
        OnboardingPage(
            title: "Scioperi e GPS",
            description: "Resta aggiornato su scioperi o disservizi con notizie ed elaborazioni intelligenti.\n\nConsenti l'accesso alla posizione per rilevare automaticamente le stazioni del Passante a te più vicine per una navigazione immediata!",
            iconName: "location.circle.fill",
            iconColor: .blue
        )
    ]
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Spacer()
                    Button("Salta") {
                        Haptics.play(.light)
                        withAnimation {
                            showOnboarding = false
                        }
                    }
                    .foregroundColor(.secondary)
                    .padding()
                    .opacity(currentPage == pages.count - 1 ? 0 : 1)
                }
                
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        VStack {
                            if index == 0 {
                                OnboardingCardView(page: pages[index], isLastPage: false) {}
                            } else if index == 1 {
                                OnboardingSuburbanCustomizerView()
                            } else if index == 2 {
                                OnboardingHomeStationPickerView()
                            } else if index == 3 {
                                OnboardingFavoriteRoutesView()
                            } else if index == 4 {
                                OnboardingCardView(page: pages[index], isLastPage: false) {}
                            } else if index == 5 {
                                OnboardingCardView(page: pages[index], isLastPage: false) {}
                            } else if index == 6 {
                                OnboardingCardView(page: pages[index], isLastPage: true) {
                                    Haptics.play(.medium)
                                    locationManager.requestAuthorization()
                                }
                            }
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                Spacer()
                
                // Bottom Button
                Button(action: {
                    Haptics.play(.medium)
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        withAnimation {
                            showOnboarding = false
                        }
                    }
                }) {
                    Text(currentPage == pages.count - 1 ? "Inizia ora" : "Avanti")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .padding(.horizontal, 30)
                }
                .padding(.bottom, 30)
            }
        }
    }
}

struct OnboardingCardView: View {
    let page: OnboardingPage
    let isLastPage: Bool
    var requestLocationAction: () -> Void
    
    @State private var animateIcon = false
    
    var body: some View {
        VStack(spacing: 25) {
            Spacer()
            
            // Icon with soft glowing background
            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.12))
                    .frame(width: 160, height: 160)
                    .scaleEffect(animateIcon ? 1.05 : 0.95)
                
                Image(systemName: page.iconName)
                    .font(.system(size: 80))
                    .foregroundColor(page.iconColor)
                    .scaleEffect(animateIcon ? 1.1 : 0.9)
                    .shadow(color: page.iconColor.opacity(0.3), radius: animateIcon ? 12 : 6)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    animateIcon = true
                }
            }
            
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(.title, design: .rounded))
                    .bold()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(page.description.contains("•") ? .leading : .center)
                    .padding(.horizontal, 35)
                    .lineSpacing(4)
            }
            
            // Special action for location page
            if page.iconName == "location.circle.fill" {
                Button(action: {
                    requestLocationAction()
                }) {
                    HStack {
                        Image(systemName: "location.fill")
                        Text("Consenti Posizione GPS")
                    }
                    .font(.subheadline.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(20)
                }
                .padding(.top, 10)
            }
            
            Spacer()
        }
    }
}

struct OnboardingSuburbanCustomizerView: View {
    @EnvironmentObject var manager: TrainManager
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Treni Suburbani di Milano")
                .font(.system(.title, design: .rounded))
                .bold()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.top, 10)
            
            Text("Abilita solo le linee suburbane che usi e rimuovi con il tasto - le fermate che non ti interessano.\nSe disabiliti tutte le linee, la sezione Passante scomparirà dalla Home!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(SuburbanData.shared.allLines) { line in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(line.name)
                                    .font(.headline)
                                    .foregroundColor(line.color)
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
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            
                            if manager.selectedSuburbanLines.contains(line.id) && !line.stations.isEmpty {
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
                                                        .background(Circle().fill(Color(.systemBackground)))
                                                        .font(.title3)
                                                }
                                                .offset(x: 10, y: -20)
                                                , alignment: .topTrailing
                                            )
                                            .padding(.top, 15)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 10)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct OnboardingHomeStationPickerView: View {
    @EnvironmentObject var manager: TrainManager
    @State private var homeDestInput = ""
    @State private var hasSaved = false
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Stazione di Casa / Lavoro")
                .font(.system(.title, design: .rounded))
                .bold()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.top, 10)
            
            Text("Salva la tua stazione preferita. Quando attivi il filtro Casa 🏠 sulla toolbar della Home, l'app mostrerà solo i treni diretti qui con calcolo orario in tempo reale.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            
            Spacer()
            
            VStack(spacing: 20) {
                let allStations = SuburbanData.shared.allLines.flatMap { $0.stations.map { $0.name.capitalized } } + manager.allRFIStations.map { $0.name.capitalized }
                AutocompleteField(
                    label: "Cerca e seleziona Stazione",
                    placeholder: "Es. Magenta, Rho, Milano Centrale...",
                    text: $homeDestInput,
                    suggestions: Array(Set(allStations)).sorted()
                )
                .padding(.horizontal, 30)
                
                if !manager.homeDestinationStationName.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Stazione salvata: **\(manager.homeDestinationStationName)**")
                            .font(.body)
                    }
                    .padding(.top, 5)
                }
                
                Button(action: {
                    Haptics.play(.medium)
                    manager.homeDestinationStationName = homeDestInput
                    manager.saveFavorites()
                    hasSaved = true
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }) {
                    Text(manager.homeDestinationStationName.isEmpty ? "Salva Stazione" : "Aggiorna Stazione")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(homeDestInput.isEmpty ? Color.gray : Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(homeDestInput.isEmpty)
                .padding(.horizontal, 30)
                
                if !manager.homeDestinationStationName.isEmpty {
                    Button(action: {
                        Haptics.play(.medium)
                        homeDestInput = ""
                        manager.homeDestinationStationName = ""
                        manager.saveFavorites()
                        hasSaved = false
                    }) {
                        Text("Rimuovi stazione salvata")
                            .foregroundColor(.red)
                            .font(.subheadline)
                    }
                }
            }
            
            Spacer()
        }
        .onAppear {
            homeDestInput = manager.homeDestinationStationName
        }
    }
}

struct OnboardingFavoriteRoutesView: View {
    @EnvironmentObject var manager: TrainManager
    
    @State private var originName = ""
    @State private var originID = ""
    @State private var destName = ""
    @State private var destID = ""
    
    @State private var showOriginSearch = false
    @State private var showDestSearch = false
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Le Tue Tratte Preferite")
                .font(.system(.title, design: .rounded))
                .bold()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.top, 10)
            
            Text("Salva le tratte generiche (es. Magenta ➔ Milano Porta Garibaldi). Non contengono orari fissi e mostreranno tutti i treni regionali e suburbani in tempo reale.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            
            VStack(spacing: 12) {
                Button(action: { showOriginSearch = true }) {
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundColor(.orange)
                            .font(.caption2)
                        Text(originName.isEmpty ? "Seleziona Stazione di Partenza" : originName)
                            .fontWeight(originName.isEmpty ? .regular : .semibold)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 30)
                
                Button(action: { showDestSearch = true }) {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.red)
                            .font(.subheadline)
                        Text(destName.isEmpty ? "Seleziona Stazione di Arrivo" : destName)
                            .fontWeight(destName.isEmpty ? .regular : .semibold)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 30)
                
                Button(action: {
                    if !originID.isEmpty && !destID.isEmpty && originID != destID {
                        Haptics.play(.medium)
                        manager.toggleFavoriteRoute(originName: originName, originID: originID, destName: destName, destID: destID)
                        originName = ""
                        originID = ""
                        destName = ""
                        destID = ""
                    }
                }) {
                    Text("Aggiungi ai Preferiti")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(originID.isEmpty || destID.isEmpty || originID == destID ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(originID.isEmpty || destID.isEmpty || originID == destID)
                .padding(.horizontal, 30)
            }
            
            Divider()
                .padding(.horizontal, 30)
                .padding(.vertical, 5)
            
            ScrollView {
                VStack(spacing: 8) {
                    if manager.favoriteRoutes.isEmpty {
                        Text("Nessuna tratta preferita ancora aggiunta.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                            .padding(.top, 10)
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
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground).opacity(0.6))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 30)
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
