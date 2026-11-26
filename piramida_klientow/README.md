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

## SQL w HALO: kolejność uruchamiania

**Najpierw diagnostyka:** `sql/diagnostyka_przed_startem.sql` (same SELECT-y,
nic nie tworzy). Sprawdza słowniki (Katalog Podmiotów Publicznych, `T_CEIDG_GUS`,
`DB_BAZA`), pokrycie rynku przez `DB_BAZA` w porównaniu z GUS, proporcje podziału klas
GUS na piętra, duże firmy (4001+) i wstępną piramidę naszych klientów.
Uruchamiamy całość przez F5 w SQL Developerze (wynik w CSV). Sprzedaż
jest tylko jako udział %. Dopiero gdy wyniki mają sens, budujemy tabele `00`–`06`.

| Plik | Co robi | Tabela |
|---|---|---|
| `sql/00_setup.sql` | Progi pięter, tabela korekt, tabela na dane GUS (jednorazowo) | `T_ODY_PIRAMIDA_PROGI`, `T_ODY_KOREKTA_FIRMY`, `T_ODY_RYNEK_GUS` |
| `sql/01_rynek_gus_dane.sql` | INSERT-y danych GUS (plik generowany, wariant B) | `T_ODY_RYNEK_GUS` |
| `sql/02_klienci_ltm.sql` | Nasi klienci: NIP z dodatnią sprzedażą w ostatnich 12 zamkniętych miesiącach, główny SOLDTO i jego region sprzedaży | `T_ODY_KLIENT_LTM` |
| `sql/03_profil_firm.sql` | Profil każdej firmy (rynek z `DB_BAZA` + nasi klienci): zatrudnienie, PKD, sektor, flaga Public, piętro. Kontrole flagi Public | `T_ODY_FIRMA_PROFIL` |
| `sql/04_lista_4001.sql` | Lista firm ≥ 3000 do ręcznej weryfikacji + porównanie z GUS 1000+. Poprawki → `T_ODY_KOREKTA_FIRMY` → ponownie `03` | – |
| `sql/05_proporcje.sql` | Proporcje podziału klas GUS na piętra (z `DB_BAZA`) | `T_ODY_PROPORCJE` |
| `sql/06_piramida.sql` | Piramida: rynek, nasi klienci, penetracja, pokrycie pracujących, sprzedaż; kontrole; podwarstwy 0–9 / 10–40 | `T_ODY_PIRAMIDA` |

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
2. ~~**SQL**: progi, klienci, profil firm, lista 4001+, proporcje, piramida.~~ Gotowe.
3. **Uruchomienie w HALO** `00` → `06`, z kontrolami po każdym kroku.
4. **Weryfikacja 4001+ i flagi Public**, korekty, ponowne `03` → `05` → `06`.
5. **Prezentacja:** piramida + tabela, z przypisem, co jest szacunkiem
   (podział klas GUS na progi, pracujący Public według wielkości).

## Ograniczenia, o których mówimy przy prezentacji

- Piętra 1–5 na rynku to szacunek: liczby GUS, podział na progi według
  `DB_BAZA`. Piętro 4001+ zależy od jakości zatrudnienia dużych firm w `DB_BAZA`.
- Penetracja Public w liczbie firm jest zaniżona: GUS liczy podmioty (każdą
  szkołę), my liczymy NIP-y, a wiele szkół płaci przez NIP gminy lub CUW.
  Lepsza miara dla Public: pokrycie pracujących.
- Klienci bez zatrudnienia w `DB_BAZA` są w wierszu NIEPRZYPISANE. Jego
  udział w sprzedaży pokazujemy na slajdzie.
