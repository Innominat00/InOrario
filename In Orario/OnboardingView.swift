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
            description: "Il tuo compagno ideale per viaggiare in tutta Italia, pensato in particolare per Milano. Tieni d'occhio metro, passante e treni preferiti in un'unica schermata.",
            iconName: "train.side.front.car",
            iconColor: .blue
        ),
        OnboardingPage(
            title: "Salva i tuoi Preferiti",
            description: "Personalizza la tua dashboard in due modi semplici:\n\n• Cerca in alto: Digita il nome di una stazione e premi il tasto \"+\" per salvarla. Cerca un treno per numero per inserirlo direttamente nei preferiti.\n\n• Swipe rapido: Nel tabellone di qualsiasi stazione, trascina un treno verso sinistra per salvarlo all'istante con la stellina ⭐",
            iconName: "star.fill",
            iconColor: .yellow
        ),
        OnboardingPage(
            title: "Notizie & Scioperi in Tempo Reale",
            description: "L'app ti avvisa subito in caso di scioperi o disservizi con notizie elaborate tramite intelligenza artificiale per essere chiare e precise.",
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
