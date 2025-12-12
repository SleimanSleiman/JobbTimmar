# JobbTimmar

En Flutter-app för att registrera arbetstimmar och skapa månadsrapporter.

## 📱 Funktioner

- **Registrera arbetspass**: Datum, kund/arbetsplats och antal timmar
- **Automatisk veckodag**: Beräknas automatiskt från datumet
- **Kundhistorik**: Sparar tidigare kunder för snabb autocomplete
- **Månadsöversikt**: Se alla arbetspass för vald månad
- **PDF-rapport**: Generera och dela månadsrapport som PDF

## 🛠️ Installation

### Förutsättningar
- Flutter SDK (version 3.0.0 eller högre)
- Android Studio eller VS Code med Flutter-tillägg
- En Android-enhet eller emulator

### Steg för steg

1. **Installera Flutter** (om du inte redan har det):
   ```bash
   # macOS med Homebrew
   brew install flutter
   
   # Eller ladda ner från https://flutter.dev/docs/get-started/install
   ```

2. **Klona eller navigera till projektet**:
   ```bash
   cd /Users/sleimansleiman/Documents/GitHub/JobbTimmar
   ```

3. **Skapa Flutter-projektstruktur** (första gången):
   ```bash
   flutter create . --project-name jobb_timmar --org com.example
   ```

4. **Hämta beroenden**:
   ```bash
   flutter pub get
   ```

5. **Kör appen**:
   ```bash
   # Lista tillgängliga enheter
   flutter devices
   
   # Kör på ansluten Android-enhet
   flutter run
   
   # Eller kör i debug-läge
   flutter run --debug
   ```

## 📦 Paket som används

| Paket | Version | Beskrivning |
|-------|---------|-------------|
| sqflite | ^2.3.0 | SQLite-databas för lokal lagring |
| path | ^1.8.3 | Hantering av filsökvägar |
| intl | ^0.18.1 | Internationalisering och datumformatering |
| pdf | ^3.10.7 | Generering av PDF-dokument |
| printing | ^5.11.1 | Utskrift och delning av PDF |

## 📁 Projektstruktur

```
lib/
├── main.dart                 # App-startpunkt
├── models/
│   ├── work_entry.dart       # Modell för arbetspass
│   └── customer_history.dart # Modell för kundhistorik
├── database/
│   └── db_helper.dart        # SQLite databashantering
├── screens/
│   ├── home_screen.dart      # Startsida med lista
│   └── add_entry_screen.dart # Lägg till/redigera arbetspass
└── utils/
    └── pdf_generator.dart    # PDF-rapportgenerering
```

## 🗄️ Databas

Appen använder SQLite med två tabeller:

### work_entries
| Kolumn | Typ | Beskrivning |
|--------|-----|-------------|
| id | INTEGER | Primärnyckel |
| date | TEXT | ISO-datumformat |
| customer | TEXT | Kund/arbetsplats |
| hours | REAL | Antal timmar |

### customer_history
| Kolumn | Typ | Beskrivning |
|--------|-----|-------------|
| id | INTEGER | Primärnyckel |
| name | TEXT | Kundnamn (UNIQUE) |

## 📱 Användning

### Lägga till arbetspass
1. Tryck på **"+ Nytt pass"**-knappen
2. Välj datum (veckodag visas automatiskt)
3. Skriv in kund/arbetsplats (förslag visas från historik)
4. Ange antal timmar
5. Tryck **"Spara arbetspass"**

### Bläddra mellan månader
- Använd pilarna **◀ ▶** för att navigera mellan månader
- Total tid för månaden visas under månadsnamnet

### Skapa PDF-rapport
1. Navigera till önskad månad
2. Tryck på **"Skapa & dela PDF-rapport"**
3. Välj hur du vill dela (e-post, meddelande, spara, etc.)

### Redigera/Ta bort
- **Redigera**: Tryck på ett arbetspass i listan
- **Ta bort**: Tryck på papperskorgen till höger

## 🎨 Design

Appen är designad för att vara:
- **Enkel** - Tydlig och ren layout
- **Stor text** - Lätt att läsa
- **Stora knappar** - Lätt att trycka
- **Svenska** - Veckodagar och månader på svenska

## 📄 PDF-rapport

Rapporten innehåller:
- Rubrik: "Arbetsrapport"
- Månad och år
- Tabell med: Datum, Veckodag, Kund/Arbetsplats, Timmar
- Total summa timmar
- Antal arbetspass
- Genereringsdatum

Filnamn: `arbetsrapport_YYYY-MM.pdf`

## 🔧 Felsökning

### "flutter: command not found"
Flutter är inte installerat eller inte i PATH. Installera Flutter:
```bash
brew install flutter
# eller
export PATH="$PATH:[PATH_TO_FLUTTER]/flutter/bin"
```

### Appen startar inte
Kontrollera att alla beroenden är installerade:
```bash
flutter pub get
flutter doctor
```

### PDF går inte att dela
Kontrollera att appen har behörigheter för delning i Android-inställningarna