# Piramida klientów

Cel: dla każdego piętra piramidy pokazać **ile firm jest na rynku**, **ile
z nich jest naszymi klientami** i **ile osób w nich pracuje**. Dane rynku
potwierdzamy w GUS.

| # | Piętro | Zatrudnienie |
|---|---|---|
| 1 | 0–40 | 0–40 (mikrofirmy 0–9 pokazywane jako podwarstwa, do decyzji) |
| 2 | 41–200 | 41–200 |
| 3 | 201–500 | 201–500 |
| 4 | 501–4000 | 501–4000 |
| 5 | 4001+ | powyżej 4000 |
| 6 | Public | sektor publiczny, wydzielony z pięter 1–5 (definicja do decyzji) |

Public odejmujemy z pięter 1–5 zarówno na rynku, jak i u nas, żeby nic nie
liczyło się dwa razy.

## Źródła danych

| Co | Źródło | Plik | Uwagi |
|---|---|---|---|
| Podmioty wg klas wielkości × dział PKD × sektor publiczny/prywatny | GUS REGON, Tablica 1, 10.2026 | `dane/gus_regon_t01_202610.csv` (z `dane/zrodla/202610_t01_dane_pkd_prac.xml`) | Podmioty **zarejestrowane**; klasa wg **przewidywanej** liczby pracujących (deklarowanej przy rejestracji) |
| Przedsiębiorstwa **aktywne** wg klas | GUS, Tablica 2, 2 kw. 2026 | repo Go2M: `dane/gus_firmy_sekcje_pkd_2kw2026.csv` | Klasy 0–9 / 10–49 / 50–249 / 250+; bez sekcji O |
| Pracujący wg klas wielkości × sekcja | GUS Tabl. 7, 30.04.2026 | repo Go2M: `dane/gus_pracujacy_gn_sekcje_klasy_04_2026.csv` | Bez podziału na sektor publiczny/prywatny |
| Pracujący w sektorze publicznym | GUS BAEL 2 kw. 2026 | repo Go2M: `dane/gus_bael_pracujacy_2kw2026.csv` | 4 203 tys.; badanie ankietowe, bez klas wielkości |
| Nasi klienci, zatrudnienie | HALO: `T_INVOICE_LINE`, `T_PAYER`, `DB_BAZA`, `T_CEIDG_GUS` | `sql/` (do przygotowania) | Reguły joinów: repo BAZA_WIEDZY_HALO_RAG |

Odświeżenie REGON (GUS publikuje co miesiąc):

```bash
python gus/regon_t01_xml_do_csv.py dane/zrodla/<RRRRMM>_t01_dane_pkd_prac.xml
```

### GUS REGON 10.2026 w skrócie (liczba podmiotów)

| Klasa GUS | Ogółem | Sektor publiczny | Niepubliczne (ogółem − publ.) | Dla porównania: przedsiębiorstwa aktywne, 2 kw. 2026 |
|---|---:|---:|---:|---:|
| 0–9 | 5 355 518 | 74 079 | 5 281 439 | 2 779 281 |
| 10–49 | 125 735 | 25 307 | 100 428 | 95 785 |
| 50–249 | 26 333 | 11 314 | 15 019 | 17 245 |
| 250–999 | 3 399 | 1 155 | 2 244 | 4 170 (250+ łącznie) |
| 1000+ | 738 | 293 | 445 | |
| **Razem** | **5 511 723** | **112 148** | **5 399 575** | |

Wnioski dla piramidy:

- **REGON zawyża małe firmy:** w klasie 0–9 jest prawie 2× więcej podmiotów
  niż przedsiębiorstw aktywnych (firmy zarejestrowane, ale niedziałające). Dla
  pięter 1–2 liczbę firm na rynku bierzemy z przedsiębiorstw aktywnych, a REGON
  służy do kontroli.
- **Dla dużych firm oba źródła są zgodne:** 250+ to 4 137 podmiotów w REGON
  i 4 170 przedsiębiorstw aktywnych. REGON daje dodatkowo podział 250–999
  / 1000+, którego nie ma w Tablicy 2.
- **REGON daje sektor publiczny w klasach wielkości,** więc piętro Public
  można policzyć wprost z GUS, a nie tylko z sekcji O.
- **Skład sektora publicznego:** obsługa nieruchomości (dział 68) 40,5 tys.
  (prawie wszystkie 0–9), edukacja 37,1 tys., administracja (O) 10,5 tys.,
  opieka zdrowotna i pomoc społeczna 8,9 tys., kultura 5,8 tys. Dział 68 do
  sprawdzenia: co to za podmioty i czy są klientem Public.
- **Progów 40 / 200 / 500 / 4000 GUS nie publikuje.** Klasy GUS dzielimy
  proporcjonalnie według rozkładu firm z `DB_BAZA` (metoda jak w Go2M,
  `sql/00b_rynek_gus.sql`). Piętro 4001+ liczymy od dołu: lista NIP-ów
  z `DB_BAZA` z ręczną weryfikacją, kontrola z REGON 1000+ (445 podmiotów
  niepublicznych).
- **Tablica 1 nie zawiera liczby pracujących** (tylko liczbę podmiotów).
  Pracujących bierzemy z Tabl. 7; dla Public brakuje pracujących według sektora
  i wielkości (BAEL daje tylko sumę).

## Kolejność pracy

1. **Progi:** `T_ODY_PIRAMIDA_PROGI` (własna tabela; `MATRYCA_ZATRUDNIENIA` bez zmian).
2. **Strona Lyreco:** aktywne NIP-y (sprzedaż > 0 w ostatnich 12 zamkniętych
   miesiącach), zatrudnienie z `DB_BAZA`, piętro, flaga Public, sprzedaż LTM.
   Klienci bez zatrudnienia trafiają do osobnego wiersza „nieprzypisane”.
3. **Lista 4001+:** NIP-y z `DB_BAZA` powyżej 4000 do ręcznej weryfikacji.
4. **Strona rynku:** GUS (aktywne + REGON + Tabl. 7) w piętrach piramidy,
   Public wydzielony.
5. **Piramida + kontrole:** suma pięter = suma GUS; nasi klienci ≤ rynek
   w każdym piętrze; % klientów z zatrudnieniem.
6. **Prezentacja:** piramida + tabela, z przypisem, co jest szacunkiem.

## Decyzje otwarte

1. **Definicja Public:** sektor publiczny wg REGON (propozycja), sama sekcja
   O, czy region CA PUBLIC? Czy dział 68 (40 tys. małych podmiotów) zostaje?
2. **Public:** jeden blok czy z podziałem na wielkości?
3. **Piętro 0–40:** mikrofirmy 0–9 jako osobna podwarstwa?
4. **„Firma u nas”:** aktywny NIP w ostatnich 12 miesiącach, czy inny okres
   albo poziom grupy (TOP_LEVEL)?
5. **Pracujący w Public:** czy jest tablica GUS z pracującymi wg sektora
   własności × wielkości? Jeśli nie, bierzemy BAEL (suma) albo szacunek
   z REGON × średnia w klasie.
