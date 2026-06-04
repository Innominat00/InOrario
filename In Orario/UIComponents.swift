import SwiftUI
import Combine
import Foundation
import CoreLocation
import ActivityKit
import StoreKit

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

