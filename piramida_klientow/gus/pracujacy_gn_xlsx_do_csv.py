"""
Konwersja GUS "Pracujacy w gospodarce narodowej w Polsce w <miesiac> <rok> r. - tablice"
(XLSX) -> CSV do piramidy klientow. Bierzemy tylko wiersze "o" (ogolem), bez "k" (kobiety).

Wyciagamy (uklad PKD 2007):
  Tabl. 1 -> gus_pracujacy_ogolem_miesiecznie_<RRRR>.csv
            pracujacy ogolem miesiecznie + pozycje "w tym" (MON/MSWiA, rolnicy indywidualni, ...)
  Tabl. 5 -> gus_pracujacy_sektor_sekcja_<RRRRMM>.csv
            pracujacy wg sektora wlasnosci (publiczny / prywatny + formy wlasnosci) x sekcja
  Tabl. 6 -> gus_pracujacy_sektor_dzial_<RRRRMM>.csv
            pracujacy wg sektora x sekcja i dzial (GUS podaje nazwy dzialow bez kodow)
  Tabl. 7 + 8 -> gus_pracujacy_sekcja_klasa_<RRRRMM>.csv
            pracujacy (Tabl. 7) i pracownicy najemni (Tabl. 8) wg sekcji x wielkosci podmiotu

Znaki GUS: "-" = zjawisko nie wystapilo (zapisujemy 0), "." = brak / tajemnica (puste pole).

Uzycie:
  python pracujacy_gn_xlsx_do_csv.py <plik.xlsx> --okres 2026-06 [--out-dir ../dane]
Wymaga: openpyxl
"""
import argparse
import csv
import re
import sys
from pathlib import Path

import openpyxl

KLASY_T7 = {  # etykieta wiersza GUS -> klasa
    "5 i mniej pracujących": "0-5",
    "6-9": "6-9",
    "10-49": "10-49",
    "50-249": "50-249",
    "250-999": "250-999",
    "1000 i więcej pracujących": "1000+",
    "O G Ó Ł E M": "OGOLEM",
}
# kolumny Tabl. 7/8 od kolumny "Ogolem" (indeks 2): OGOLEM, A, B-E, w tym C, F..S
SEKCJE_T7 = ["OGOLEM", "A", "BE", "C", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S"]


def liczba(v):
    if v is None:
        return None
    s = str(v).strip()
    if s in ("", "."):
        return None
    if s == "-":
        return 0
    return int(float(s.replace(" ", "")))


def wiersze_o(ws):
    """Zwraca (etykieta, wartosci) dla wierszy 'o' (ogolem); etykieta z pierwszej niepustej
    komorki tekstowej w wierszu 'o' lub, gdy jej brak, z wiersza wyzej."""
    for row in ws.iter_rows(values_only=True):
        cells = ["" if v is None else str(v).strip() for v in row]
        try:
            i = cells.index("o")
        except ValueError:
            continue
        etykieta = next((c for c in cells[:i] if c), "")
        yield etykieta, list(row[i + 1:])


def sekcja_z_etykiety(et):
    m = re.search(r"\(([A-Z])\)\s*[a-z]?\s*$", et)
    return m.group(1) if m else None


POZYCJE_T1 = {
    "O G Ó Ł E M": "OGOLEM",
    "w jednostkach budżetowych": "MON_MSWIA",           # obrona narodowa i bezpieczenstwo publiczne
    "poza pracującymi": "POZA_MON_MSWIA",
    "pracujący w gospodarstwach indywidualnych": "ROLNICY_INDYWIDUALNI",
    "duchowni": "DUCHOWNI",
    "pracujący mieszkający za granicą": "MIESZKAJACY_ZA_GRANICA",
}


def tabl1(ws, rok):
    out = []
    for et, v in wiersze_o(ws):
        poz = next((kod for pref, kod in POZYCJE_T1.items() if et.startswith(pref)), None)
        if not poz:
            continue
        for mies, val in enumerate(v[:12], start=1):
            if liczba(val) is not None:
                out.append({"OKRES": f"{rok}-{mies:02d}", "POZYCJA": poz, "PRACUJACY": liczba(val)})
    return out


def tabl5(ws):
    out = []
    for et, v in wiersze_o(ws):
        sek = "OGOLEM" if et.replace(" ", "") == "OGÓŁEM" else sekcja_z_etykiety(et)
        if not sek:
            continue
        out.append({"SEKCJA_PKD": sek, "OPIS": et, "OGOLEM": liczba(v[0]),
                    "SEKTOR_PUBLICZNY": liczba(v[1]), "PUBL_SKARB_PANSTWA": liczba(v[2]),
                    "PUBL_PANSTWOWE_OSOBY_PRAWNE": liczba(v[3]), "PUBL_JST": liczba(v[4]),
                    "SEKTOR_PRYWATNY": liczba(v[5]), "PRYW_KRAJOWA": liczba(v[6]),
                    "PRYW_ZAGRANICZNA": liczba(v[7])})
    return out


def tabl6(ws):
    out, sek = [], None
    for et, v in wiersze_o(ws):
        if et.replace(" ", "") == "OGÓŁEM":
            poziom, sek = "OGOLEM", "OGOLEM"
        elif sekcja_z_etykiety(et):
            poziom, sek = "SEKCJA", sekcja_z_etykiety(et)
        else:
            poziom = "DZIAL"
        out.append({"POZIOM": poziom, "SEKCJA_PKD": sek, "OPIS": et.replace("∆", "").strip(),
                    "OGOLEM": liczba(v[0]), "SEKTOR_PUBLICZNY": liczba(v[1]),
                    "SEKTOR_PRYWATNY": liczba(v[2]), "PRYW_NAJEMNI": liczba(v[3]),
                    "PRYW_WLASNY_RACHUNEK": liczba(v[4])})
    return out


def tabl78(ws, miara):
    out = {}
    for et, v in wiersze_o(ws):
        klasa = KLASY_T7.get(et)
        if not klasa:
            continue
        for sek, val in zip(SEKCJE_T7, v):
            out[(sek, klasa)] = {miara: liczba(val)}
    return out


def zapisz(rows, plik, kolumny):
    with open(plik, "w", encoding="utf-8", newline="") as f:
        wr = csv.DictWriter(f, fieldnames=kolumny, delimiter=";")
        wr.writeheader()
        wr.writerows(rows)
    print(f"  {plik.name}: {len(rows)} wierszy")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("xlsx", type=Path)
    ap.add_argument("--okres", required=True, help="RRRR-MM, np. 2026-06")
    ap.add_argument("--out-dir", type=Path, default=Path(__file__).resolve().parent.parent / "dane")
    a = ap.parse_args()

    wb = openpyxl.load_workbook(a.xlsx, data_only=True)
    for nazwa in ("Tabl. 5", "Tabl. 6", "Tabl. 7", "Tabl. 8"):
        if nazwa not in wb.sheetnames:
            sys.exit(f"Brak arkusza '{nazwa}' - inny uklad pliku GUS?")
    rrrrmm = a.okres.replace("-", "")
    a.out_dir.mkdir(parents=True, exist_ok=True)
    print(f"Okres {a.okres} -> {a.out_dir}")

    t1 = tabl1(wb["Tabl. 1"], a.okres[:4])
    zapisz(t1, a.out_dir / f"gus_pracujacy_ogolem_miesiecznie_{a.okres[:4]}.csv",
           ["OKRES", "POZYCJA", "PRACUJACY"])

    t5 = tabl5(wb["Tabl. 5"])
    for r in t5:
        r["OKRES"] = a.okres
    zapisz(t5, a.out_dir / f"gus_pracujacy_sektor_sekcja_{rrrrmm}.csv",
           ["OKRES", "SEKCJA_PKD", "OPIS", "OGOLEM", "SEKTOR_PUBLICZNY", "PUBL_SKARB_PANSTWA",
            "PUBL_PANSTWOWE_OSOBY_PRAWNE", "PUBL_JST", "SEKTOR_PRYWATNY", "PRYW_KRAJOWA", "PRYW_ZAGRANICZNA"])

    t6 = tabl6(wb["Tabl. 6"])
    for r in t6:
        r["OKRES"] = a.okres
    zapisz(t6, a.out_dir / f"gus_pracujacy_sektor_dzial_{rrrrmm}.csv",
           ["OKRES", "POZIOM", "SEKCJA_PKD", "OPIS", "OGOLEM", "SEKTOR_PUBLICZNY", "SEKTOR_PRYWATNY",
            "PRYW_NAJEMNI", "PRYW_WLASNY_RACHUNEK"])

    t7, t8 = tabl78(wb["Tabl. 7"], "PRACUJACY"), tabl78(wb["Tabl. 8"], "PRACOWNICY_NAJEMNI")
    rows = [{"OKRES": a.okres, "SEKCJA_PKD": s, "KLASA": k, **t7[(s, k)], **t8.get((s, k), {})}
            for (s, k) in t7]
    zapisz(rows, a.out_dir / f"gus_pracujacy_sekcja_klasa_{rrrrmm}.csv",
           ["OKRES", "SEKCJA_PKD", "KLASA", "PRACUJACY", "PRACOWNICY_NAJEMNI"])

    # kontrole: suma sekcji = OGOLEM (Tabl. 5), suma klas = OGOLEM (Tabl. 7)
    og5 = next(r for r in t5 if r["SEKCJA_PKD"] == "OGOLEM")
    for kol in ("OGOLEM", "SEKTOR_PUBLICZNY", "SEKTOR_PRYWATNY"):
        s = sum(r[kol] or 0 for r in t5 if r["SEKCJA_PKD"] != "OGOLEM")
        print(f"  kontrola Tabl. 5 {kol}: suma sekcji {s:,} vs ogolem {og5[kol]:,}")
    s7 = sum(t7[("OGOLEM", k)]["PRACUJACY"] for k in KLASY_T7.values() if k != "OGOLEM")
    print(f"  kontrola Tabl. 7: suma klas {s7:,} vs ogolem {t7[('OGOLEM', 'OGOLEM')]['PRACUJACY']:,}")


if __name__ == "__main__":
    main()
