"""
Konwersja GUS REGON, Tablica 1 (XML) -> CSV do piramidy klientow.

Tablica 1: Podmioty gospodarki narodowej (bez osob fizycznych prowadzacych
wylacznie indywidualne gospodarstwa rolne) wedlug przewidywanej liczby
pracujacych oraz sekcji i dzialow PKD 2007. GUS publikuje ja co miesiac
jako plik XML <RRRRMM>_t01_dane_pkd_prac.xml.

Wynik: jeden wiersz na dzial PKD x klase wielkosci, kolumny sektorow obok
siebie (kazda kolumne mozna bezpiecznie sumowac osobno):
  OGOLEM                = wszystkie podmioty (GUS)
  SEKTOR_PUBLICZNY      = GUS
  SEKTOR_PRYWATNY       = GUS
  W_TYM_OSOBY_FIZYCZNE  = GUS, CZESC sektora prywatnego (nie dodawac do sumy!)
  BEZ_SEKTORA           = WYLICZONE: OGOLEM - PUBLICZNY - PRYWATNY
                          (podmioty bez przypisanego sektora wlasnosci)

Uzycie:
  python regon_t01_xml_do_csv.py <plik.xml> [--okres 2026-10] [--out plik.csv]

Domyslnie okres bierzemy z nazwy pliku (RRRRMM_...), a CSV zapisujemy do
../dane/gus_regon_t01_<RRRRMM>.csv (wzgledem folderu skryptu).
"""
import argparse
import csv
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

KLASY = [("0-9", "0-9"), ("10-49", "10-49"), ("50-249", "50-249"),
         ("250-999", "250-999"), ("POW1000", "1000+")]
PREFIKSY = {
    "OGOLEM": "OGOLEM",
    "SEKTOR_PUBLICZNY": "SEKTOR_PUBLICZNY",
    "SEKTOR_PRYWATNY": "SEKTOR_PRYWATNY",
    "W_TYM_OSOBY_FIZYCZNE": "SEKTOR_PRYWATNY_W_TYM_OSOBY_FIZYCZNE",
}
ZRODLO = ("GUS REGON, Tablica 1: podmioty gospodarki narodowej wg przewidywanej "
          "liczby pracujacych oraz sekcji i dzialow PKD 2007")


def okres_z_nazwy(nazwa: str) -> str:
    m = re.match(r"(\d{4})(\d{2})", nazwa)
    if not m:
        sys.exit("Nie umiem odczytac okresu z nazwy pliku - podaj --okres RRRR-MM")
    return f"{m.group(1)}-{m.group(2)}"


def wczytaj(plik: Path):
    root = ET.parse(plik).getroot()
    wiersze, bledy = [], []
    for el in root.iter("dane_tablica_T1"):
        d = {c.tag: (c.text or "").strip() for c in el}
        for kol_xml, klasa in KLASY:
            w = {"SEKCJA_PKD": d["PKD_SEKCJA"], "DZIAL_PKD": d["PKD_DZIAL"],
                 "PKD_OPIS": d["PKD_OPIS"], "KLASA_GUS": klasa}
            for kol, pref in PREFIKSY.items():
                w[kol] = int(d[f"{pref}_LICZBA_PRACUJACYCH_{kol_xml}"])
            w["BEZ_SEKTORA"] = w["OGOLEM"] - w["SEKTOR_PUBLICZNY"] - w["SEKTOR_PRYWATNY"]
            if w["BEZ_SEKTORA"] < 0:
                bledy.append(f"dzial {w['DZIAL_PKD']} klasa {klasa}: publ+pryw > ogolem")
            wiersze.append(w)
        # kontrola: suma klas = RAZEM (GUS)
        for kol, pref in PREFIKSY.items():
            klucz = f"{pref}_RAZEM" if kol != "W_TYM_OSOBY_FIZYCZNE" else f"{pref}_LICZBA_PRACUJACYCH_RAZEM"
            suma = sum(int(d[f"{pref}_LICZBA_PRACUJACYCH_{k}"]) for k, _ in KLASY)
            if suma != int(d[klucz]):
                bledy.append(f"dzial {d['PKD_DZIAL']} {kol}: suma klas {suma} != RAZEM {d[klucz]}")
    return wiersze, bledy


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("xml", type=Path)
    ap.add_argument("--okres", help="RRRR-MM (domyslnie z nazwy pliku)")
    ap.add_argument("--out", type=Path)
    a = ap.parse_args()

    okres = a.okres or okres_z_nazwy(a.xml.name)
    out = a.out or Path(__file__).resolve().parent.parent / "dane" / f"gus_regon_t01_{okres.replace('-', '')}.csv"

    wiersze, bledy = wczytaj(a.xml)
    if bledy:
        print("UWAGA - niespojnosci w pliku GUS:", *bledy, sep="\n  ")

    kolumny = ["OKRES", "ZRODLO", "SEKCJA_PKD", "DZIAL_PKD", "PKD_OPIS", "KLASA_GUS",
               "OGOLEM", "SEKTOR_PUBLICZNY", "SEKTOR_PRYWATNY", "W_TYM_OSOBY_FIZYCZNE", "BEZ_SEKTORA"]
    out.parent.mkdir(parents=True, exist_ok=True)
    with open(out, "w", encoding="utf-8", newline="") as f:
        wr = csv.DictWriter(f, fieldnames=kolumny, delimiter=";")
        wr.writeheader()
        for w in wiersze:
            wr.writerow({"OKRES": okres, "ZRODLO": ZRODLO, **w})

    print(f"Zapisano {len(wiersze)} wierszy ({len(wiersze) // len(KLASY)} dzialow PKD) -> {out}")
    print(f"{'KLASA':>8} {'OGOLEM':>11} {'PUBLICZNY':>10} {'PRYWATNY':>11} {'BEZ_SEKT.':>10}")
    for _, k in KLASY:
        s = lambda kol: sum(w[kol] for w in wiersze if w["KLASA_GUS"] == k)
        print(f"{k:>8} {s('OGOLEM'):>11,} {s('SEKTOR_PUBLICZNY'):>10,} {s('SEKTOR_PRYWATNY'):>11,} {s('BEZ_SEKTORA'):>10,}")


if __name__ == "__main__":
    main()
