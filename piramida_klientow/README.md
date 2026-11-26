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
| 6 | Public | wydzielony z pięter 1–5 (wariant definicji do decyzji, niżej) |

Public odejmujemy z pięter 1–5 zarówno na rynku, jak i u nas, żeby nic nie
liczyło się dwa razy.

## Źródła danych

| Co | Źródło | Plik w `dane/` | Uwagi |
|---|---|---|---|
| Podmioty wg klas wielkości × dział PKD × sektor | GUS REGON, Tablica 1, 10.2026 | `gus_regon_t01_202610.csv` | Podmioty **zarejestrowane**; klasa wg **przewidywanej** liczby pracujących |
| Pracujący wg sektora własności × sekcja | GUS *Pracujący w gospodarce narodowej*, Tabl. 5, 06.2026 | `gus_pracujacy_sektor_sekcja_202606.csv` | Rejestry ZUS/KRUS/MON/MSWiA; sektor publiczny 3 535 975 |
| Pracujący wg sektora × dział | jw., Tabl. 6 | `gus_pracujacy_sektor_dzial_202606.csv` | Nazwy działów bez kodów; część pól utajniona |
| Pracujący i pracownicy najemni wg sekcji × wielkości podmiotu | jw., Tabl. 7 i 8 | `gus_pracujacy_sekcja_klasa_202606.csv` | Klasy 0–5, 6–9, 10–49, 50–249, 250–999, 1000+; bez podziału na sektor |
| Pracujący ogółem miesięcznie, rolnicy indywidualni, MON/MSWiA | jw., Tabl. 1 | `gus_pracujacy_ogolem_miesiecznie_2026.csv` | Rolników indywidualnych (981 831) odejmujemy, nie są rynkiem |
| **Szkielet rynku**: podmioty i pracujący w klasach GUS, Public wydzielony | wyliczenie | `szkielet_rynku_gus.csv` | Skrypt `gus/szkielet_rynku_gus.py`, 3 warianty Public |
| Przedsiębiorstwa **aktywne** wg klas | GUS, Tablica 2, 2 kw. 2026 | repo Go2M: `gus_firmy_sekcje_pkd_2kw2026.csv` | Klasy 0–9 / 10–49 / 50–249 / 250+; bez sekcji O |
| Nasi klienci, zatrudnienie | HALO: `T_INVOICE_LINE`, `T_PAYER`, `DB_BAZA`, `T_CEIDG_GUS` | `sql/` (do przygotowania) | Reguły joinów: repo BAZA_WIEDZY_HALO_RAG |

Pliki źródłowe GUS leżą w `dane/zrodla/`. Odświeżenie po nowej publikacji:

```bash
python gus/regon_t01_xml_do_csv.py dane/zrodla/<RRRRMM>_t01_dane_pkd_prac.xml
```

```bash
python gus/pracujacy_gn_xlsx_do_csv.py dane/zrodla/<plik>.xlsx --okres RRRR-MM
```

```bash
python gus/szkielet_rynku_gus.py --regon RRRRMM --prac RRRRMM
```

## Public: trzy warianty definicji

| Wariant | Co obejmuje | Podmioty (REGON 10.2026) | Pracujący (06.2026) |
|---|---|---:|---:|
| **A. Cały sektor publiczny** | wszystkie podmioty publiczne, w tym spółki państwowe i komunalne | 112 148 | 3 535 975 |
| **B. Instytucje publiczne** (propozycja) | sektor publiczny w sekcjach O, P, Q, R: administracja, edukacja, zdrowie i pomoc społeczna, kultura | 62 256 | 2 805 762 |
| **C. Administracja** | tylko sekcja O (jak w Go2M) | 10 472 | 1 080 664 |

Różnica A − B (730 tys. pracujących, 50 tys. podmiotów) to głównie spółki
państwowe i komunalne: transport (202 tys.), wodociągi i odpady (106 tys.),
instytuty badawcze (87 tys.), górnictwo (64 tys.), energetyka (53 tys.),
przemysł (50 tys.), finanse (46 tys.). Zawiera też 40,5 tys. małych podmiotów
publicznych z obsługi nieruchomości (dział 68). Za wariantem B przemawia to,
że spółki państwowe działają jak korporacje i obsługujemy je w piętrach
według wielkości, a problem działu 68 znika. Przypadek graniczny to wodociągi
i odpady (E).

W sekcji O są też jednostki MON/MSWiA (wojsko, policja): 391 706 pracujących
(GUS podaje tę liczbę jako stałą w roku).

## Szkielet rynku w klasach GUS (wariant B)

Podmioty: REGON 10.2026. Pracujący: 06.2026, bez rolników indywidualnych.

| Klasa GUS | Poza Public: podmioty | Poza Public: pracujący | Public: podmioty | Public: pracujący* |
|---|---:|---:|---:|---:|
| 0–9 | 5 326 492 | 3 709 518 | 29 026 | 16 838 |
| 10–49 | 103 248 | 2 115 291 | 22 487 | 463 867 |
| 50–249 | 16 670 | 1 878 732 | 9 663 | 1 010 290 |
| 250–999 | 2 536 | 1 655 497 | 863 | 426 549 |
| 1000+ | 521 | 1 968 204 | 217 | 888 218 |
| **Razem** | **5 449 467** | **11 327 242** | **62 256** | **2 805 762** |

\* **Szacunek.** GUS nie publikuje pracujących w sektorze publicznym według
wielkości podmiotu. W każdej sekcji dzielimy pracujących sektora publicznego
(Tabl. 5) na klasy proporcjonalnie do: pracujący w klasie (Tabl. 7) × udział
podmiotów publicznych w klasie (REGON). Suma po klasach zgadza się z Tabl. 5.
Warianty A i C: `dane/szkielet_rynku_gus.csv`.

Ograniczenia:

- **REGON zawyża małe podmioty:** w klasie 0–9 jest prawie 2× więcej podmiotów
  niż przedsiębiorstw aktywnych (5,36 mln wobec 2,78 mln). Dla pięter 1–2
  liczbę firm bierzemy z przedsiębiorstw aktywnych, REGON służy do kontroli.
  Dla dużych firm oba źródła są zgodne: 250+ to 4 137 w REGON i 4 170 aktywnych.
- **Klasy podmiotów i pracujących pochodzą z różnych źródeł:** REGON liczy
  według deklarowanej liczby pracujących, Tabl. 7 według faktycznej. Średnia
  „pracujący na podmiot” w klasie jest więc orientacyjna.
- **Progów 40 / 200 / 500 / 4000 GUS nie publikuje.** Klasy GUS dzielimy
  proporcjonalnie według rozkładu firm z `DB_BAZA` (metoda z Go2M,
  `sql/00b_rynek_gus.sql`). Piętro 4001+ liczymy od dołu: lista NIP-ów
  z `DB_BAZA` z ręczną weryfikacją, kontrola z klasą 1000+ (521 podmiotów
  i 1,97 mln pracujących poza Public w wariancie B).

## Kolejność pracy

1. ~~**Dane GUS**: REGON, pracujący, szkielet rynku w klasach GUS.~~ Gotowe.
2. **Progi:** `T_ODY_PIRAMIDA_PROGI` (własna tabela; `MATRYCA_ZATRUDNIENIA` bez zmian).
3. **Strona Lyreco:** aktywne NIP-y (sprzedaż > 0 w ostatnich 12 zamkniętych
   miesiącach), zatrudnienie z `DB_BAZA`, piętro, flaga Public, sprzedaż LTM.
   Klienci bez zatrudnienia trafiają do osobnego wiersza „nieprzypisane”.
4. **Lista 4001+:** NIP-y z `DB_BAZA` powyżej 4000 do ręcznej weryfikacji.
5. **Rynek w piętrach piramidy:** szkielet GUS (+ przedsiębiorstwa aktywne)
   podzielony na progi według rozkładu `DB_BAZA`.
6. **Piramida + kontrole:** suma pięter = suma GUS; nasi klienci ≤ rynek
   w każdym piętrze; % klientów z zatrudnieniem.
7. **Prezentacja:** piramida + tabela, z przypisem, co jest szacunkiem.

## Decyzje otwarte

1. **Definicja Public:** wariant A, B (propozycja) czy C? Czy wodociągi
   i odpady (E) dołączamy do Public?
2. **Public:** jeden blok czy z podziałem na wielkości?
3. **Piętro 0–40:** mikrofirmy 0–9 jako osobna podwarstwa?
4. **„Firma u nas”:** aktywny NIP w ostatnich 12 miesiącach, czy inny okres
   albo poziom grupy (TOP_LEVEL)?
