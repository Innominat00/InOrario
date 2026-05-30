import SwiftUI

struct SavedTripsView: View {
    @EnvironmentObject var manager: TrainManager
    
    var body: some View {
        List {
            if manager.savedTrips.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "bookmark.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("Nessun viaggio salvato")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Cerca un viaggio e tocca l'icona del segnalibro per salvarlo qui.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 50)
                .listRowBackground(Color.clear)
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(manager.savedTrips) { trip in
                    let sol = trip.asTravelSolution
                    NavigationLink(destination: TravelSolutionDetailsView(solution: sol)) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(trip.origin) - \(trip.destination)").font(.headline)
                            HStack {
                                Text(trip.departureTime).fontWeight(.bold).foregroundColor(.blue)
                                Image(systemName: "arrow.right").foregroundColor(.secondary).font(.caption)
                                Text(trip.arrivalTime).fontWeight(.bold).foregroundColor(.blue)
                                Spacer()
                                Text(trip.duration).font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            manager.toggleSavedTrip(solution: sol)
                        } label: {
                            Label("Rimuovi", systemImage: "trash.fill")
                        }
                    }
                }
            }
        }
        .navigationTitle("Viaggi Salvati")
        .navigationBarTitleDisplayMode(.large)
    }
}
