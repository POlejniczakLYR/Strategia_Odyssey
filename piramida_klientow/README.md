# Piramida klientów

Cel: dla każdego piętra piramidy pokazać **ile firm jest na rynku**, **ile
z nich jest naszymi klientami** i **ile osób w nich pracuje**. Dane rynku
potwierdzamy w GUS.

| # | Piętro | Zatrudnienie |
|---|---|---|
| 1 | 0–40 | 0–40 (dodatkowo podwarstwy 0–9 i 10–40) |
| 2 | 41–200 | 41–200 |
| 3 | 201–500 | 201–500 |
| 4 | 501–4000 | 501–4000 |
| 5 | 4001+ | powyżej 4000 |
| 6 | Public | jeden blok, wariant B: instytucje publiczne (niżej) |

Public odejmujemy z pięter 1–5 zarówno na rynku, jak i u nas, żeby nic nie
liczyło się dwa razy.

**Decyzje (2026-11-26):** Public = wariant B (sektor publiczny w działach
PKD 84–88 i 90–93), Public jako jeden blok, „firma u nas” = NIP płatnika
z dodatnią sprzedażą netto w ostatnich 12 zamkniętych miesiącach.

## Źródła danych

| Co | Źródło | Plik w `dane/` | Uwagi |
|---|---|---|---|
| Podmioty wg klas wielkości × dział PKD × sektor | GUS REGON, Tablica 1, 10.2026 | `gus_regon_t01_202610.csv` | Podmioty **zarejestrowane**; klasa wg **przewidywanej** liczby pracujących |
| Pracujący wg sektora własności × sekcja | GUS *Pracujący w gospodarce narodowej*, Tabl. 5, 06.2026 | `gus_pracujacy_sektor_sekcja_202606.csv` | Rejestry ZUS/KRUS/MON/MSWiA; sektor publiczny 3 535 975 |
| Pracujący wg sektora × dział | jw., Tabl. 6 | `gus_pracujacy_sektor_dzial_202606.csv` | Nazwy działów bez kodów; część pól utajniona |
| Pracujący i pracownicy najemni wg sekcji × wielkości podmiotu | jw., Tabl. 7 i 8 | `gus_pracujacy_sekcja_klasa_202606.csv` | Klasy 0–5, 6–9, 10–49, 50–249, 250–999, 1000+; bez podziału na sektor |
| Pracujący ogółem miesięcznie, rolnicy indywidualni, MON/MSWiA | jw., Tabl. 1 | `gus_pracujacy_ogolem_miesiecznie_2026.csv` | Rolników indywidualnych (981 831) odejmujemy, nie są rynkiem |
| **Szkielet rynku**: podmioty i pracujący w klasach GUS, Public wydzielony | wyliczenie | `szkielet_rynku_gus.csv` | Skrypt `gus/szkielet_rynku_gus.py`, 3 warianty Public |
| Przedsiębiorstwa **aktywne** wg klas | GUS, Tablica 2, 2 kw. 2026 | `gus_przedsiebiorstwa_aktywne_2kw2026.csv` (kopia z repo Go2M) | Klasy 0–9 / 10–49 / 50–249 / 250+; bez sekcji O |
| **Dane rynku do HALO** (wariant B) | wyliczenie | `rynek_gus_do_halo.csv` → `sql/01_rynek_gus_dane.sql` | Generuje `gus/szkielet_rynku_gus.py` |
| Nasi klienci, zatrudnienie, flaga Public | HALO: `T_INVOICE_LINE`, `T_PAYER`, `T_SOLDTO`, `DB_BAZA`, `T_CEIDG_GUS`, `T_KATALOG_PODMIOTOW_PUBLICZNYCH` | `sql/02`–`06` | Reguły joinów: repo BAZA_WIEDZY_HALO_RAG |

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

## Jak przypisujemy dane GUS do naszych pięter

GUS podaje firmy i pracujących w swoich klasach wielkości. Nasze progi
(40 / 200 / 500 / 4000) przecinają te klasy, więc każdą klasę GUS dzielimy
na co najwyżej dwa piętra (klasa 250+ z tablicy przedsiębiorstw aktywnych
na trzy):

| Klasa GUS | Trafia do pięter |
|---|---|
| 0–9 | 0–40 (w całości) |
| 10–49 | 0–40 (10–40) + 41–200 (41–49) |
| 50–249 | 41–200 (50–200) + 201–500 (201–249) |
| 250–999 | 201–500 (250–500) + 501–4000 (501–999) |
| 1000+ | 501–4000 (1000–4000) + 4001+ |
| 250+ | 201–500 + 501–4000 + 4001+ |

**Proporcje podziału bierzemy z `DB_BAZA`** (cały rynek, nie tylko nasi
klienci). W każdej klasie GUS liczymy, jaki odsetek firm i jaki odsetek
pracujących wypada w danym piętrze. Przykład (liczby umowne): jeśli w
`DB_BAZA` 88% firm z klasy 10–49 ma do 40 osób, to 88% firm GUS z tej klasy
trafia do piętra 0–40, a 12% do 41–200. Firmy GUS mnożymy przez odsetek
firm, a pracujących GUS przez odsetek pracujących. Liczby pochodzą z GUS, z `DB_BAZA`
tylko proporcje, więc suma pięter = suma GUS (sprawdza to kontrola w `sql/06`).

- **Piętro 4001+** powstaje w całości z podziału klasy 1000+, bo GUS nie ma
  progu 4000. Dlatego przed liczeniem proporcji przeglądamy listę dużych firm
  (`sql/04`) i poprawiamy błędy `DB_BAZA` (zatrudnienie całej grupy przy
  każdej spółce, stare dane) w tabeli korekt.
- **Nasi klienci** nie wymagają podziału: każdy NIP trafia do piętra
  bezpośrednio według swojego zatrudnienia.
- **Public** to jeden blok, więc też bez podziału: liczby wprost z GUS.

## Wstępny wynik: rynek w piętrach (diagnostyka D08–D11, 2026-11-26)

Dane GUS (wariant B) × proporcje z `DB_BAZA` z D09 (zaokrąglone do 0,1 pp.,
więc końcowe liczby z `sql/06` będą się nieznacznie różnić):

| Piętro | Firmy na rynku (przedsiębiorstwa aktywne) | Firmy (REGON, kontrola) | Pracujący | Średnio na firmę |
|---|---:|---:|---:|---:|
| 0–40 | 2 872 767 | 5 427 262 | 5 674 623 | 2 |
| 41–200 | 18 699 | 18 331 | 1 807 227 | 97 |
| 201–500 | 3 390 | 2 678 | 1 171 946 | 346 |
| 501–4000 | 1 533 | 1 128 | 1 740 517 | 1 135 |
| 4001+ | 92 | 68 | 932 929 | 10 179 |
| Public | 62 256 | 62 256 | 2 805 762 | – |
| **Razem** | **2 958 737** | **5 511 723** | **14 133 004** | |

Wnioski z diagnostyki:

- **`DB_BAZA` obejmuje praktycznie cały rynek firm 10+** (D08): liczba firm
  101–143% GUS, pracujący w klasach 50+ 94–109% GUS. W klasie 0–9 tylko 4%,
  ale ta klasa w całości trafia do piętra 0–40, więc nie wymaga proporcji.
- **Liczba firm na rynku: przedsiębiorstwa aktywne, nie REGON.** W klasach
  250+ `DB_BAZA` ma 140% firm REGON, ale 104% przedsiębiorstw aktywnych. REGON
  przypisuje klasę według deklarowanej, rzadko aktualizowanej liczby pracujących.
- **Duże firmy bez duplikatów w grupach** (D10: 0): 732 firmy 1000+, w tym
  95 powyżej 4000 (1,02 mln pracujących). Zatrudnienie pochodzi głównie ze zrzutu
  z 01.01.2022 (D17). Do sprawdzenia w `04`: m.in. Lasy Państwowe (zatrudnienie
  całego PGL przy Dyrekcji Generalnej), dwie spółki Seris Konsalnet o podobnym
  zatrudnieniu, ITM Polska (sieć franczyzowa).
- **Kontrola proporcji rozkładem Pareto** (interpolacja między granicami klas
  GUS): próg 200 → 6,0% (`DB_BAZA` 4,9%), próg 500 → 70,9% (73,4%), próg
  4000 → 17% (13%), czyli zgodnie. **Próg 40 odstaje:** według Pareto firmy
  41–49 to 5,2% klasy 10–49, w `DB_BAZA` 2,4%. Przy Pareto piętro 41–200 miałoby
  około 21,4 tys. firm zamiast 18,7 tys. (+14%). Zostajemy przy `DB_BAZA`, bo
  naszych klientów przypisujemy do pięter tym samym zatrudnieniem z `DB_BAZA`,
  więc penetracja jest liczona spójnie. Różnicę podajemy jako zakres niepewności
  piętra 41–200.

## Wstępny wynik: nasi klienci i penetracja (diagnostyka D12–D18, 2026-11-26)

Klienci = NIP-y z dodatnią sprzedażą w ostatnich 12 miesiącach: 29 976 NIP-ów,
99,8% sprzedaży. Sprzedaż bez NIP-u albo z NIP-em innym niż 10 cyfr to 0,2%.
`T_CEIDG_GUS` obejmuje 98,7% klientów, `DB_BAZA` 49% klientów, ale 80% sprzedaży.

| Piętro | Rynek: firmy | U nas: firmy | Penetracja | Rynek: pracujący | U nas: pracujący | Pokrycie pracujących | % sprzedaży |
|---|---:|---:|---:|---:|---:|---:|---:|
| 0–40 | 2 872 767 | 6 292 | 0,22% | 5 674 623 | 108 778 | 1,9% | 7,3 |
| 41–200 | 18 699 | 5 271 | 28,2% | 1 807 227 | 488 974 | 27,1% | 14,6 |
| 201–500 | 3 390 | 1 442 | 42,5% | 1 171 946 | 443 900 | 37,9% | 12,4 |
| 501–4000 | 1 533 | 769 | 50,2% | 1 740 517 | 911 094 | 52,3% | 26,6 |
| 4001+ | 92 | 70 | 76,1% | 932 929 | 667 504 | 71,5% | 15,8 |
| Public | 62 256 | 2 143 | 3,4%* | 2 805 762 | 271 614** | 9,7%** | 5,9 |
| Nieprzypisane | – | 14 005 | – | – | – | – | 17,5 |

\* GUS liczy podmioty (każdą szkołę), my liczymy NIP-y (szkoły płacą zwykle
przez NIP gminy): 1 681 z 2 143 klientów Public to dział 84 (gminy, urzędy,
związki gmin), 5,1% sprzedaży.
\*\* Zatrudnienie znamy tylko dla 937 z 2 143 klientów Public.

Wnioski:

- **Nieprzypisani (17,5% sprzedaży)**: hipoteza „same mikrofirmy” potwierdziła
  się tylko częściowo (D19–D20):
  - osoby fizyczne: 5 097 NIP-ów, 2,0% sprzedaży → piętro 0–40 (podwarstwa 0–9, szacunek);
  - spółki i inne osoby prawne: 8 509 NIP-ów, **13,8% sprzedaży**. Są wśród nich
    duże firmy, których nie ma w `DB_BAZA`: m.in. nowe spółki z lat 2022–2025
    (VeloBank, Orlen Paczka, Electrolux Production) oraz starsze (LPP Retail,
    Animex Foods, Stryker, Monnari, Duży Ben). Trzeba im uzupełnić zatrudnienie
    (`T_ODY_KOREKTA_FIRMY`): najwięksi według sprzedaży ręcznie (eKRS: przeciętne
    zatrudnienie), resztę według decyzji (D21 pokazuje, ilu to wymaga);
  - brak w `T_CEIDG_GUS`: 396 NIP-ów, 1,7% sprzedaży: według D22 to grupy VAT
    (NIP grupy zamiast NIP-u spółki) i NIP-y zagraniczne;
  - D21: 200 największych spółek to 6,9% sprzedaży (połowa sprzedaży spółek
    nieprzypisanych), 1000 największych to 10,4%; reszta (ok. 7 tys. firm)
    ma średnio mniejszą sprzedaż na NIP niż klienci 0–40;
  - BvD (Orbis) w `T_PAYER` / `T_COMPANY` **nie używamy**: słabe źródło
    (decyzja 2026-11-26);
  - **jak przypisujemy klientów bez zatrudnienia** (`sql/03`, kolumna `PIETRO_ZRODLO`):
    osoby fizyczne → 0–40 (szacunek); spółki spoza 200 największych według
    sprzedaży → 0–40 (szacunek, sprzedaż na NIP niższa niż średnio w 0–40);
    200 największych → `DO_UZUPELNIENIA` (lista B w `sql/04`, zatrudnienie z eKRS);
    grupy VAT → mapowanie na NIP spółki (lista C, `T_ODY_MAPA_NIP`); NIP-y
    zagraniczne → osobny wiersz „poza rynkiem PL” (piętro 98);
  - 30 największych nieprzypisanych to 27% ich sprzedaży.
  - Do wyjaśnienia: czy wśród klientów są odsprzedawcy (np. hurtownie z działu
    46), których nie powinno być w piramidzie.
- **Public a organizacja sprzedaży:** region sprzedaży „Public” (351 NIP-ów,
  4,8% sprzedaży) to nie to samo co Public w wariancie B. Region obsługuje też
  spółki państwowe (energetyka, banki, transport, porty). Klienci sektora
  publicznego spoza wariantu B to 884 NIP-y i 5,8% sprzedaży. W wariancie B są
  w piętrach według wielkości. Z kolei 1 811 klientów Public (3% sprzedaży)
  obsługuje SMB.
- **Centra usług wspólnych (dział 69)**: wśród naszych klientów brak albo
  < 0,01% sprzedaży, więc nie zmieniamy definicji Public.

## SQL w HALO: kolejność uruchamiania

**Najpierw diagnostyka:** `sql/diagnostyka_przed_startem.sql` (same SELECT-y,
nic nie tworzy). Sprawdza słowniki (Katalog Podmiotów Publicznych, `T_CEIDG_GUS`,
`DB_BAZA`), pokrycie rynku przez `DB_BAZA` w porównaniu z GUS, proporcje podziału klas
GUS na piętra, duże firmy (4001+) i wstępną piramidę naszych klientów.
Uruchamiamy całość przez F5 w SQL Developerze (wynik w CSV). Sprzedaż
jest tylko jako udział %. Dopiero gdy wyniki mają sens, budujemy tabele `00`–`06`.

| Plik | Co robi | Tabela |
|---|---|---|
| `sql/00_setup.sql` | Progi pięter (1–6, 98 poza rynkiem PL, 99 do uzupełnienia), tabela korekt, mapowanie NIP-ów, tabela na dane GUS (jednorazowo) | `T_ODY_PIRAMIDA_PROGI`, `T_ODY_KOREKTA_FIRMY`, `T_ODY_MAPA_NIP`, `T_ODY_RYNEK_GUS` |
| `sql/01_rynek_gus_dane.sql` | INSERT-y danych GUS (plik generowany, wariant B) | `T_ODY_RYNEK_GUS` |
| `sql/02_klienci_ltm.sql` | Nasi klienci: NIP z dodatnią sprzedażą w ostatnich 12 zamkniętych miesiącach (po mapowaniu grup VAT), typ NIP-u, główny płatnik i SOLDTO, region sprzedaży, flaga „region Public” | `T_ODY_KLIENT_LTM` |
| `sql/03_profil_firm.sql` | Profil każdej firmy (rynek z `DB_BAZA` + nasi klienci): zatrudnienie, PKD, sektor, flaga Public, piętro i źródło piętra (`PIETRO_ZRODLO`). Kontrole flagi Public i udziału szacunków | `T_ODY_FIRMA_PROFIL` |
| `sql/04_listy_do_weryfikacji.sql` | Lista A: firmy ≥ 3000 (weryfikacja 4001+). Lista B: 200 największych klientów bez zatrudnienia (eKRS). Lista C: grupy VAT i NIP-y zagraniczne (mapowanie). Poprawki → `T_ODY_KOREKTA_FIRMY` / `T_ODY_MAPA_NIP` → ponownie `02`/`03` | – |
| `sql/05_proporcje.sql` | Proporcje podziału klas GUS na piętra (z `DB_BAZA`) | `T_ODY_PROPORCJE` |
| `sql/06_piramida.sql` | Piramida: rynek, nasi klienci (w tym szacunki), penetracja, pokrycie pracujących, sprzedaż, w tym obsługa przez region Public; kontrole; podwarstwy 0–9 / 10–40 / szacunek | `T_ODY_PIRAMIDA` |

**Flaga Public (wariant B)** w `03`: NIP jest w Katalogu Podmiotów
Publicznych (`PUBLIC`, `ACTIVE`) albo ma w `T_CEIDG_GUS` publiczną formę
własności (Skarb Państwa, państwowe osoby prawne, JST, mieszaną z przewagą
sektora publicznego) **i** działa w działach PKD 84–88 / 90–93. Forma własności
w `T_CEIDG_GUS` jest tekstem bez kodu, więc reguła rozpoznaje ją po treści
(sprawdzone na wszystkich 22 wartościach, diagnostyka D03). Działy liczymy
po dwóch pierwszych cyfrach PKD, bo w PKD 2007 i PKD 2025 są takie same
(litery sekcji się różnią). Kontrole 2–5 w `03` porównują flagę z formą
własności i z regionem sprzedaży (np. region PUBLIC bez flagi). Błędy
poprawiamy regułą albo korektą `FLAGA_PUBLIC` w `T_ODY_KOREKTA_FIRMY`.

SQL był sprawdzony parserem składni Oracle, ale nie był uruchamiany na HALO.
Przy pierwszym uruchomieniu warto przejść kontrole po każdym kroku.

## Kolejność pracy

1. ~~**Dane GUS**: REGON, pracujący, szkielet rynku w klasach GUS.~~ Gotowe.
2. ~~**Diagnostyka** D01–D22 i poprawki reguł.~~ Gotowe.
3. **Pierwsze uruchomienie w HALO:** `00` → `01` → `02` → `03`, z kontrolami.
4. **Lista C** (`04`): grupy VAT i NIP-y zagraniczne → `T_ODY_MAPA_NIP` →
   ponownie `02` i `03`.
5. **Listy B i A** (`04`): zatrudnienie 200 największych klientów bez danych
   (eKRS) i weryfikacja firm ≥ 3000 → `T_ODY_KOREKTA_FIRMY` → ponownie `03`.
6. **Wynik:** `05` → `06`, z kontrolami.
7. **Prezentacja:** piramida + tabela, z przypisem, co jest szacunkiem
   (podział klas GUS na progi, pracujący Public według wielkości, klienci
   bez zatrudnienia przypisani do 0–40).

## Ograniczenia, o których mówimy przy prezentacji

- Piętra 1–5 na rynku to szacunek: liczby GUS, podział na progi według
  `DB_BAZA`. Piętro 4001+ zależy od jakości zatrudnienia dużych firm w `DB_BAZA`.
- Penetracja Public w liczbie firm jest zaniżona: GUS liczy podmioty (każdą
  szkołę), my liczymy NIP-y, a wiele szkół płaci przez NIP gminy lub CUW.
  Lepsza miara dla Public: pokrycie pracujących.
- Klienci bez zatrudnienia w `DB_BAZA` są w wierszu NIEPRZYPISANE. Jego
  udział w sprzedaży pokazujemy na slajdzie.
