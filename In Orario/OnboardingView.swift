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
    
    let pages = [
        OnboardingPage(
            title: "Benvenuto su InOrario",
            description: "Il tuo compagno ideale per viaggiare in treno. Tieni d'occhio stazioni, treni e passante in un'unica schermata premium, pensata in particolare per i pendolari.",
            iconName: "train.side.front.car",
            iconColor: .blue
        ),
        OnboardingPage(
            title: "Dashboard su Misura",
            description: "Una vista pulita e ordinata suddivisa in tre sezioni principali:\n\n• Le Mie Stazioni: Le partenze e arrivi in tempo reale dei tuoi scali preferiti.\n\n• I miei Treni: Per monitorare all'istante lo stato dei singoli treni che usi di più.\n\n• Passante Ferroviario: La mappa orizzontale dinamica delle stazioni del passante di Milano.\n\nPersonalizza e riordina le sezioni come preferisci premendo il pulsante in fondo alla schermata!",
            iconName: "slider.horizontal.3",
            iconColor: .blue
        ),
        OnboardingPage(
            title: "Salva i tuoi Viaggi",
            description: "Pianifichi spesso la stessa combinazione di treni per i tuoi spostamenti?\n\n• Salva le Soluzioni: Cerca una soluzione di viaggio e premi l'icona del segnalibro 🔖 per memorizzarla.\n\n• Accesso Rapido: Accedi all'elenco completo dei tuoi viaggi salvati toccando l'icona verde del segnalibro in alto a destra nella schermata principale.",
            iconName: "bookmark.fill",
            iconColor: .green
        ),
        OnboardingPage(
            title: "Trasporto Urbano Integrato",
            description: "Spostarsi a Milano è semplice e immediato.\n\nQuando pianifichi un viaggio con cambi tra stazioni milanesi (es. da Centrale a Porta Garibaldi), l'app suggerisce automaticamente il Trasporto Urbano (Metro / Mezzi) con tempi stimati di percorrenza, evitandoti la ricerca di scomodi treni regionali cittadini.",
            iconName: "tram.fill",
            iconColor: .purple
        ),
        OnboardingPage(
            title: "Notizie & Scioperi",
            description: "L'app ti avvisa subito in caso di scioperi o disservizi con notizie chiare ed elaborate tramite intelligenza artificiale per essere precise e tempestive.",
            iconName: "newspaper.fill",
            iconColor: .red
        ),
        OnboardingPage(
            title: "Stazioni Vicine",
            description: "Permetti l'accesso alla tua posizione per scoprire automaticamente le stazioni del Passante e di Trenord più vicine a te.",
            iconName: "location.circle.fill",
            iconColor: .orange
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
                        OnboardingCardView(page: pages[index], isLastPage: index == pages.count - 1) {
                            Haptics.play(.medium)
                            locationManager.requestAuthorization()
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
