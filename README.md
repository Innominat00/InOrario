In Orario? 🚆

_In Orario?_ è una dashboard personale nata per semplificare la vita dei pendolari (soprattutto sulla tratta Magenta - Milano). L'app aggrega dati in tempo reale dai tabelloni RFI e dalle API di ViaggiaTreno per offrirti una visione chiara e immediata dello stato dei tuoi treni. Il progetto è scaturito dall'assenza di alternative valide sul mercato: app diffuse come Orario Treni si affidano esclusivamente ai dati di ViaggiaTreno, che in molte occasioni risultano non aggiornati o inaccessibili. _In Orario?_ supera questo limite integrando direttamente i tabelloni ufficiali RFI (iechub), che altrimenti richiederebbero una ricerca manuale e scomoda via web. Data la complessità tecnica dell'integrazione, questa funzionalità è al momento ottimizzata solo per le stazioni selezionate per uso personale.

[!CAUTION]
Disclaimer: Questa è un'app sviluppata per uso strettamente personale. Al momento si trova in uno stato sperimentale e molte configurazioni (come le stazioni predefinite e alcuni filtri) sono hardcoded per le mie necessità specifiche. Non è ancora garantito un funzionamento corretto o universale per altri utenti o altre tratte ferroviarie.

✨ Caratteristiche principali

Dashboard Personalizzabile: Riordina le sezioni (Preferiti, Stazioni, Passante) come preferisci.

Dati in Tempo Reale: Accesso diretto ai tabelloni ufficiali RFI e dettagliati di ViaggiaTreno.

Gestione Preferiti: Salva i tuoi treni e le tue stazioni più frequentate per trovarli in un tap.

Stazione Vicina: Grazie alla geolocalizzazione, l'app ti suggerisce la stazione ferroviaria più vicina a te.

🛠️ Tecnologie utilizzate

Linguaggio: Swift / SwiftUI

Concorrenza: Swift Concurrency (async/await) per fetch fluidi dei dati.

API: Integrazione con RFI (scraped data) e ViaggiaTreno REST API.

Posizione: CoreLocation per la funzione "Stazione Vicina".
