"""
Szkielet rynku z GUS: podmioty i pracujacy w klasach wielkosci GUS, z wydzielonym
pietrem PUBLIC (trzy warianty definicji). To jest strona RYNKU piramidy w klasach GUS;
podzial na progi piramidy (40 / 200 / 500 / 4000) robimy pozniej w HALO wg rozkladu DB_BAZA.

Wejscie (folder ../dane):
  gus_regon_t01_<RRRRMM>.csv               podmioty: dzial PKD x klasa x sektor (REGON)
  gus_pracujacy_sektor_sekcja_<RRRRMM>.csv pracujacy w sektorze publicznym wg sekcji (Tabl. 5)
  gus_pracujacy_sekcja_klasa_<RRRRMM>.csv  pracujacy wg sekcji x wielkosci podmiotu (Tabl. 7)
  gus_pracujacy_ogolem_miesiecznie_<RRRR>.csv  rolnicy indywidualni (Tabl. 1) - odejmujemy

Warianty PUBLIC:
  A_SEKTOR_PUBLICZNY  caly sektor publiczny (wszystkie sekcje, w tym spolki panstwowe i komunalne)
  B_INSTYTUCJE        sektor publiczny w sekcjach O, P, Q, R (administracja, edukacja,
                      zdrowie i pomoc spoleczna, kultura); spolki panstwowe/komunalne
                      z pozostalych sekcji zostaja w pietrach wg wielkosci
  C_ADMINISTRACJA     tylko sekcja O

SZACUNEK: GUS nie publikuje pracujacych w sektorze publicznym wg wielkosci podmiotu.
Dla kazdej sekcji dzielimy pracujacych sektora publicznego (Tabl. 5) na klasy wielkosci
proporcjonalnie do: pracujacy w klasie (Tabl. 7) x udzial podmiotow publicznych w klasie
(REGON), z ograniczeniem do liczby pracujacych w klasie. Suma po klasach = Tabl. 5.
Sekcje A i L maja w Tabl. 7 utajnione klasy 250-999 / 1000+: reszte sekcji dzielimy
wg liczby podmiotow REGON wazonej wielkoscia (500 / 2000).

Uzycie:
  python szkielet_rynku_gus.py [--regon 202610] [--prac 202606]
"""
import argparse
import csv
from collections import defaultdict
from pathlib import Path

DANE = Path(__file__).resolve().parent.parent / "dane"
KLASY = ["0-9", "10-49", "50-249", "250-999", "1000+"]
SEKCJE_T7 = ["A", "BE", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S"]
WARIANTY = {
    "A_SEKTOR_PUBLICZNY": set(SEKCJE_T7),
    "B_INSTYTUCJE": {"O", "P", "Q", "R"},
    "C_ADMINISTRACJA": {"O"},
}


def sekcja_t7(s):
    return "BE" if s in ("B", "C", "D", "E") else ("S" if s in ("S", "T", "U") else s)


def czytaj(plik):
    with open(plik, encoding="utf-8") as f:
        return list(csv.DictReader(f, delimiter=";"))


def n(v):
    return int(v) if v not in (None, "") else None


def podziel_z_limitem(suma, wagi, limity):
    """Dzieli `suma` proporcjonalnie do `wagi`, nie przekraczajac `limity` (iteracyjnie)."""
    wynik = {k: 0.0 for k in wagi}
    wolne = {k for k in wagi if wagi[k] > 0 and limity[k] > 0}
    reszta = suma
    while reszta > 0.5 and wolne:
        sw = sum(wagi[k] for k in wolne)
        if sw == 0:
            break
        przekroczone = set()
        for k in wolne:
            wynik[k] += reszta * wagi[k] / sw
            if wynik[k] > limity[k]:
                przekroczone.add(k)
        reszta = sum(max(0.0, wynik[k] - limity[k]) for k in przekroczone)
        for k in przekroczone:
            wynik[k] = limity[k]
        wolne -= przekroczone
    return wynik, reszta


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--regon", default="202610")
    ap.add_argument("--prac", default="202606")
    a = ap.parse_args()
    okres_prac = f"{a.prac[:4]}-{a.prac[4:]}"

    # REGON: podmioty ogolem i publiczne per sekcja (uklad Tabl. 7) x klasa
    pod, pod_pub = defaultdict(int), defaultdict(int)
    for r in czytaj(DANE / f"gus_regon_t01_{a.regon}.csv"):
        key = (sekcja_t7(r["SEKCJA_PKD"]), r["KLASA_GUS"])
        pod[key] += int(r["OGOLEM"])
        pod_pub[key] += int(r["SEKTOR_PUBLICZNY"])

    # Tabl. 5: pracujacy w sektorze publicznym per sekcja
    publ = defaultdict(int)
    for r in czytaj(DANE / f"gus_pracujacy_sektor_sekcja_{a.prac}.csv"):
        if r["SEKCJA_PKD"] != "OGOLEM":
            publ[sekcja_t7(r["SEKCJA_PKD"])] += int(r["SEKTOR_PUBLICZNY"])

    # Tabl. 1: rolnicy indywidualni (odejmujemy od A 0-9)
    rolnicy = next(int(r["PRACUJACY"]) for r in czytaj(DANE / f"gus_pracujacy_ogolem_miesiecznie_{a.prac[:4]}.csv")
                   if r["OKRES"] == okres_prac and r["POZYCJA"] == "ROLNICY_INDYWIDUALNI")

    # Tabl. 7: pracujacy per sekcja x klasa (0-5 + 6-9 -> 0-9)
    t7 = defaultdict(lambda: None)
    ogolem_sek = {}
    for r in czytaj(DANE / f"gus_pracujacy_sekcja_klasa_{a.prac}.csv"):
        s, k, v = r["SEKCJA_PKD"], r["KLASA"], n(r["PRACUJACY"])
        if s not in SEKCJE_T7:
            continue
        if k == "OGOLEM":
            ogolem_sek[s] = v
            continue
        k = "0-9" if k in ("0-5", "6-9") else k
        t7[(s, k)] = (t7[(s, k)] or 0) + v if v is not None else t7[(s, k)]
    for s in SEKCJE_T7:                       # utajnione 250-999 / 1000+ (A, L)
        if t7[(s, "250-999")] is None or t7[(s, "1000+")] is None:
            znane = sum(t7[(s, k)] or 0 for k in KLASY)
            w1, w2 = pod[(s, "250-999")] * 500, pod[(s, "1000+")] * 2000
            reszta = ogolem_sek[s] - znane
            t7[(s, "250-999")] = round(reszta * w1 / (w1 + w2)) if w1 + w2 else reszta
            t7[(s, "1000+")] = reszta - t7[(s, "250-999")]
    t7[("A", "0-9")] -= rolnicy

    # szacunek pracujacych sektora publicznego per sekcja x klasa
    pub_prac = {}
    for s in SEKCJE_T7:
        wagi = {k: t7[(s, k)] * (pod_pub[(s, k)] / pod[(s, k)] if pod[(s, k)] else 0) for k in KLASY}
        limity = {k: t7[(s, k)] for k in KLASY}
        podzial, brak = podziel_z_limitem(publ[s], wagi, limity)
        if brak > 0.5:
            print(f"UWAGA: sekcja {s}: {brak:,.0f} pracujacych publicznych nie zmiescilo sie w klasach")
        for k in KLASY:
            pub_prac[(s, k)] = podzial[k]

    wynik = []
    for war, sekcje in WARIANTY.items():
        for k in KLASY:
            prac = sum(t7[(s, k)] for s in SEKCJE_T7)
            p_pub = sum(pub_prac[(s, k)] for s in sekcje)
            d = sum(pod[(s, k)] for s in SEKCJE_T7)
            d_pub = sum(pod_pub[(s, k)] for s in sekcje)
            wynik += [
                {"WARIANT_PUBLIC": war, "KLASA_GUS": k, "GRUPA": "PUBLIC",
                 "PODMIOTY_REGON": d_pub, "PRACUJACY": round(p_pub)},
                {"WARIANT_PUBLIC": war, "KLASA_GUS": k, "GRUPA": "POZA_PUBLIC",
                 "PODMIOTY_REGON": d - d_pub, "PRACUJACY": round(prac - p_pub)},
            ]

    out = DANE / "szkielet_rynku_gus.csv"
    with open(out, "w", encoding="utf-8", newline="") as f:
        wr = csv.DictWriter(f, fieldnames=["OKRES_REGON", "OKRES_PRACUJACY", "WARIANT_PUBLIC",
                                           "KLASA_GUS", "GRUPA", "PODMIOTY_REGON", "PRACUJACY"], delimiter=";")
        wr.writeheader()
        for w in wynik:
            wr.writerow({"OKRES_REGON": f"{a.regon[:4]}-{a.regon[4:]}", "OKRES_PRACUJACY": okres_prac, **w})
    print(f"Zapisano {out} (pracujacy bez {rolnicy:,} rolnikow indywidualnych)\n")

    for war in WARIANTY:
        print(f"== {war}")
        print(f"{'KLASA':>8} {'POZA_PUB podm.':>15} {'POZA_PUB prac.':>15} {'PUBLIC podm.':>13} {'PUBLIC prac.':>13}")
        rows = [w for w in wynik if w["WARIANT_PUBLIC"] == war]
        for k in KLASY + ["RAZEM"]:
            g = lambda grp, kol: sum(w[kol] for w in rows if w["GRUPA"] == grp and (k == "RAZEM" or w["KLASA_GUS"] == k))
            print(f"{k:>8} {g('POZA_PUBLIC', 'PODMIOTY_REGON'):>15,} {g('POZA_PUBLIC', 'PRACUJACY'):>15,} "
                  f"{g('PUBLIC', 'PODMIOTY_REGON'):>13,} {g('PUBLIC', 'PRACUJACY'):>13,}")
        print()


if __name__ == "__main__":
    main()
