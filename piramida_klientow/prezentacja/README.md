# Prezentacja

| Plik | Co to jest |
|---|---|
| `slajd_gus_x_biznes_linie/` | Slajd „Piramida GUS × biznes linie” (źródła: `deck.json`, `deck.css`, `slides/macierz.html`), opublikowany jako prywatny deck w Claude |
| `slajd_gus_x_biznes_linie_podglad.png` | Podgląd slajdu |

Dane na slajdzie (stan z diagnostyki 2026-11-26, przed budową tabel `00`–`06`):

- **Rynek (lewa strona):** GUS (wariant B) × proporcje `DB_BAZA` z D09: przedsiębiorstwa aktywne 2 kw. 2026 i pracujący 06.2026.
- **Macierz:** D25 (samodzielni + w grupach), czyli klienci ze znanym zatrudnieniem według segmentu głównego SOLDTO. Sumy pięter zgadzają się z D13.
- **Wiersz Public:** D14. Przy segmencie IS bez terytorium klienci są liczeni razem z „inne SMB”.

Po zbudowaniu tabel liczby odświeżamy z `T_ODY_PIRAMIDA` i `T_ODY_FIRMA_PROFIL`
(kolumna `SEGMENT_OBECNY`).
