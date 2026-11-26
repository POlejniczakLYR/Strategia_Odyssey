-- =====================================================================
-- diagnostyka_przed_startem.sql
-- Piramida klientow / Strategia Odyssey
--
-- TYLKO ODCZYT (same SELECT-y, nic nie tworzy ani nie zmienia).
-- Cel: sprawdzic dane w HALO, zanim zbudujemy tabele (00-06):
--   A. slowniki: Katalog Podmiotow Publicznych, T_CEIDG_GUS, DB_BAZA
--   B. rynek: DB_BAZA vs GUS, proporcje podzialu klas GUS na pietra, 4001+
--   C. nasi klienci (LTM 12 mies.): pokrycie danymi, wstepna piramida,
--      flaga Public vs przypisanie w sprzedazy
-- Sprzedaz pokazujemy tylko jako UDZIAL % (bez kwot).
--
-- JAK URUCHOMIC (DBeaver): zaznaczyc zapytania i Alt+X (Execute script) -
-- kazdy wynik w osobnej zakladce "Results N", w kolejnosci zapytan.
-- Wklejamy zrzut ekranu albo tekst (w siatce wynikow: Ctrl+A, potem
-- prawy klik -> Advanced Copy -> Copy with headers), z numerem Dxx.
-- Czas: kilka minut (DB_BAZA i faktury LTM sa czytane kilka razy).
--
-- 2026-11-26: po wynikach D01-D04 poprawiona regula sektora publicznego
-- (forma wlasnosci w T_CEIDG_GUS jest tekstem bez kodu 1xx) i dodane D16.
-- =====================================================================


-- =====================================================================
-- A. SLOWNIKI
-- =====================================================================

-- === D01 Katalog Podmiotow Publicznych: kategorie i statusy
SELECT KATEGORIA_PODMIOTU, STATUS,
       COUNT(*)            AS PODMIOTY,
       COUNT(NIP)          AS Z_NIP,
       COUNT(DISTINCT NIP) AS NIP_UNIKALNE
FROM   WORK_POLAND.T_KATALOG_PODMIOTOW_PUBLICZNYCH
GROUP  BY KATEGORIA_PODMIOTU, STATUS
ORDER  BY PODMIOTY DESC;


-- === D02 Katalog Podmiotow Publicznych: dzialy PKD (top 30)
SELECT NVL(REGEXP_SUBSTR(KOD_PKD, '^[0-9]{2}'), '??')                  AS DZIAL,
       COUNT(*)                                                         AS PODMIOTY,
       COUNT(NIP)                                                       AS Z_NIP,
       MAX(SUBSTR(KOD_PKD, 1, 60))                                      AS PRZYKLAD_PKD,
       MAX(SUBSTR(TYP_PODMIOTU, 1, 40))                                 AS PRZYKLAD_TYPU
FROM   WORK_POLAND.T_KATALOG_PODMIOTOW_PUBLICZNYCH
GROUP  BY NVL(REGEXP_SUBSTR(KOD_PKD, '^[0-9]{2}'), '??')
ORDER  BY PODMIOTY DESC
FETCH FIRST 30 ROWS ONLY;


-- === D03 T_CEIDG_GUS: forma wlasnosci x typ podmiotu (top 30)
SELECT SUBSTR(NVL(FORMA_WLASNOSCI, '(brak)'), 1, 90)                    AS FORMA_WLASNOSCI,
       TYP_PODMIOTU,
       COUNT(*)                                                         AS PODMIOTY
FROM   WORK_POLAND.T_CEIDG_GUS
GROUP  BY SUBSTR(NVL(FORMA_WLASNOSCI, '(brak)'), 1, 90), TYP_PODMIOTU
ORDER  BY PODMIOTY DESC
FETCH FIRST 30 ROWS ONLY;


-- === D04 T_CEIDG_GUS: przeglad (1 wiersz)
SELECT COUNT(*)                                                         AS PODMIOTY,
       COUNT(DISTINCT NIP)                                              AS NIP_UNIKALNE,
       SUM(CASE WHEN NVL(DELETION_FLAG, 'N') = 'Y' OR DATA_SKRESLENIA IS NOT NULL
                  OR DATA_ZAKONCZENIA IS NOT NULL THEN 1 ELSE 0 END)    AS ZAKONCZONE,
       SUM(CASE WHEN DATA_ZAWIESZENIA IS NOT NULL
                 AND (DATA_WZNAWIENIA IS NULL OR DATA_WZNAWIENIA < DATA_ZAWIESZENIA)
                THEN 1 ELSE 0 END)                                      AS ZAWIESZONE,
       SUM(CASE WHEN FORMA_WLASNOSCI IS NULL THEN 1 ELSE 0 END)         AS BEZ_FORMY_WLASNOSCI,
       SUM(CASE WHEN PKD_KOD IS NULL THEN 1 ELSE 0 END)                 AS BEZ_PKD,
       MIN(PKD_KOD)                                                     AS PKD_MIN,
       MAX(PKD_KOD)                                                     AS PKD_MAX,
       MAX(DATA_WPROWADZENIA)                                           AS OSTATNIA_AKTUALIZACJA
FROM   WORK_POLAND.T_CEIDG_GUS;


-- === D05 DB_BAZA: przeglad (1 wiersz)
SELECT COUNT(*)                                                         AS WIERSZE,
       COUNT(DISTINCT REGEXP_REPLACE(NIP, '[^0-9]', ''))                AS NIP_UNIKALNE,
       COUNT(DISTINCT CASE WHEN LENGTH(REGEXP_REPLACE(NIP, '[^0-9]', '')) = 10
                           THEN REGEXP_REPLACE(NIP, '[^0-9]', '') END)  AS NIP_10_CYFR,
       SUM(CASE WHEN ZATRUDNIENIE IS NULL THEN 1 ELSE 0 END)            AS ZATR_NULL,
       SUM(CASE WHEN ZATRUDNIENIE = 0 THEN 1 ELSE 0 END)                AS ZATR_ZERO,
       MAX(ZATRUDNIENIE)                                                AS ZATR_MAX,
       COUNT(DISTINCT DB_BAZA)                                          AS LICZBA_ZRZUTOW,
       MIN(DB_BAZA)                                                     AS ZRZUT_MIN,
       MAX(DB_BAZA)                                                     AS ZRZUT_MAX,
       MIN(ROK_ZATRUDNIENIA)                                            AS ROK_MIN,
       MAX(ROK_ZATRUDNIENIA)                                            AS ROK_MAX
FROM   WORK_POLAND.DB_BAZA;


-- === D06 DB_BAZA: z ktorego roku jest zatrudnienie (ostatni rok na NIP)
WITH db AS (
    SELECT REGEXP_REPLACE(d.NIP, '[^0-9]', '')                              AS NIP,
           MAX(d.ZATRUDNIENIE) KEEP (DENSE_RANK LAST ORDER BY
               CASE WHEN d.ZATRUDNIENIE IS NOT NULL THEN 1 ELSE 0 END,
               d.ROK_ZATRUDNIENIA NULLS FIRST)                              AS ZATR,
           MAX(SUBSTR(d.ROK_ZATRUDNIENIA, 1, 10)) KEEP (DENSE_RANK LAST ORDER BY
               CASE WHEN d.ZATRUDNIENIE IS NOT NULL THEN 1 ELSE 0 END,
               d.ROK_ZATRUDNIENIA NULLS FIRST)                              AS ROK
    FROM   WORK_POLAND.DB_BAZA d
    WHERE  LENGTH(REGEXP_REPLACE(d.NIP, '[^0-9]', '')) = 10
    GROUP  BY REGEXP_REPLACE(d.NIP, '[^0-9]', '')
)
SELECT NVL(ROK, '(brak)')                                               AS ROK_ZATRUDNIENIA,
       COUNT(*)                                                         AS FIRMY,
       SUM(CASE WHEN ZATR >= 50   THEN 1 ELSE 0 END)                    AS FIRMY_50_PLUS,
       SUM(CASE WHEN ZATR >= 1000 THEN 1 ELSE 0 END)                    AS FIRMY_1000_PLUS
FROM   db
GROUP  BY NVL(ROK, '(brak)')
ORDER  BY ROK_ZATRUDNIENIA DESC;


-- === D07 T_REGON_PKD_WIELKOSC (REGON w HALO): sumy wg daty stanu
SELECT DATA_STANU,
       COUNT(*)            AS KODY_PKD,
       SUM(OGOLEM)         AS OGOLEM,
       SUM(PRAC_0_9)       AS PRAC_0_9,
       SUM(PRAC_10_49)     AS PRAC_10_49,
       SUM(PRAC_50_249)    AS PRAC_50_249,
       SUM(PRAC_250_PLUS)  AS PRAC_250_PLUS
FROM   WORK_POLAND.T_REGON_PKD_WIELKOSC
GROUP  BY DATA_STANU
ORDER  BY DATA_STANU DESC;


-- =====================================================================
-- B. RYNEK: DB_BAZA vs GUS (poza Public, bez firm zakonczonych / zawieszonych)
-- Liczby GUS wpisane na stale (wariant B, dane/rynek_gus_do_halo.csv).
-- =====================================================================

-- === D08 DB_BAZA vs GUS w klasach GUS (pokrycie rynku przez DB_BAZA)
WITH db AS (
    SELECT REGEXP_REPLACE(d.NIP, '[^0-9]', '')                              AS NIP,
           MAX(d.ZATRUDNIENIE) KEEP (DENSE_RANK LAST ORDER BY
               CASE WHEN d.ZATRUDNIENIE IS NOT NULL THEN 1 ELSE 0 END,
               d.ROK_ZATRUDNIENIA NULLS FIRST)                              AS ZATR,
           MAX(COALESCE(REGEXP_SUBSTR(d.DZIALPKD, '^[0-9]{2}'),
                        REGEXP_SUBSTR(d.PKD, '^[0-9]{2}')))                 AS DZIAL_DB
    FROM   WORK_POLAND.DB_BAZA d
    WHERE  LENGTH(REGEXP_REPLACE(d.NIP, '[^0-9]', '')) = 10
    GROUP  BY REGEXP_REPLACE(d.NIP, '[^0-9]', '')
),
kpp AS (
    SELECT LPAD(TO_CHAR(NIP), 10, '0')                                      AS NIP,
           MAX(REGEXP_SUBSTR(KOD_PKD, '^[0-9]{2}'))                         AS DZIAL_KPP
    FROM   WORK_POLAND.T_KATALOG_PODMIOTOW_PUBLICZNYCH
    WHERE  NIP IS NOT NULL AND KATEGORIA_PODMIOTU = 'PUBLIC' AND NVL(STATUS, 'ACTIVE') = 'ACTIVE'
    GROUP  BY LPAD(TO_CHAR(NIP), 10, '0')
),
f AS (
    SELECT db.NIP, db.ZATR,
           CASE WHEN (kpp.NIP IS NOT NULL
                      OR REGEXP_LIKE(UPPER(cg.FORMA_WLASNOSCI), '^ *1[0-9]{2}|SKARBU PA.{1,2}STWA|PA.{1,2}STWOWYCH OS.{1,2}B PRAWNYCH|SAMORZ.{1,2}DU TERYTORIALNEGO|W SEKTORZE PUBLICZNYM|SEKTORAMI Z PRZEWAG.{1,2} W.{1,2}ASNO.{1,2}CI SEKTORA PUBLICZNEGO'))
                 AND COALESCE(SUBSTR(REGEXP_REPLACE(cg.PKD_KOD, '[^0-9]', ''), 1, 2), kpp.DZIAL_KPP, db.DZIAL_DB)
                     IN ('84','85','86','87','88','90','91','92','93')
                THEN 'T' ELSE 'N' END                                       AS FLAGA_PUBLIC,
           CASE WHEN NVL(cg.DELETION_FLAG, 'N') = 'Y' OR cg.DATA_SKRESLENIA IS NOT NULL
                  OR cg.DATA_ZAKONCZENIA IS NOT NULL
                  OR (cg.DATA_ZAWIESZENIA IS NOT NULL
                      AND (cg.DATA_WZNAWIENIA IS NULL OR cg.DATA_WZNAWIENIA < cg.DATA_ZAWIESZENIA))
                THEN 'T' ELSE 'N' END                                       AS NIEAKTYWNA
    FROM   db
    LEFT JOIN WORK_POLAND.T_CEIDG_GUS cg ON cg.NIP = db.NIP
    LEFT JOIN kpp ON kpp.NIP = db.NIP
),
k AS (
    SELECT CASE WHEN ZATR < 10 THEN '0-9' WHEN ZATR < 50 THEN '10-49' WHEN ZATR < 250 THEN '50-249'
                WHEN ZATR < 1000 THEN '250-999' ELSE '1000+' END            AS KLASA_GUS,
           ZATR
    FROM   f
    WHERE  ZATR > 0 AND FLAGA_PUBLIC = 'N' AND NIEAKTYWNA = 'N'
    UNION ALL
    SELECT '250+', ZATR
    FROM   f
    WHERE  ZATR >= 250 AND FLAGA_PUBLIC = 'N' AND NIEAKTYWNA = 'N'
),
gus AS (
    SELECT '0-9'     AS KLASA_GUS, 1 AS LP, 2779281 AS GUS_FIRMY_AKTYWNE, 5326492 AS GUS_FIRMY_REGON, 3709518 AS GUS_PRACUJACY FROM dual UNION ALL
    SELECT '10-49',   2,   95785, 103248, 2115291 FROM dual UNION ALL
    SELECT '50-249',  3,   17245,  16670, 1878732 FROM dual UNION ALL
    SELECT '250-999', 4,    NULL,   2536, 1655497 FROM dual UNION ALL
    SELECT '1000+',   5,    NULL,    521, 1968204 FROM dual UNION ALL
    SELECT '250+',    6,    4170,   3057, 3623701 FROM dual
)
SELECT g.KLASA_GUS,
       COUNT(k.ZATR)                                                    AS DB_FIRMY,
       g.GUS_FIRMY_AKTYWNE,
       g.GUS_FIRMY_REGON,
       ROUND(COUNT(k.ZATR) / NVL(g.GUS_FIRMY_AKTYWNE, g.GUS_FIRMY_REGON) * 100, 1) AS DB_DO_GUS_FIRMY_PCT,
       SUM(k.ZATR)                                                      AS DB_PRACUJACY,
       g.GUS_PRACUJACY,
       ROUND(SUM(k.ZATR) / g.GUS_PRACUJACY * 100, 1)                    AS DB_DO_GUS_PRAC_PCT
FROM   gus g
LEFT JOIN k ON k.KLASA_GUS = g.KLASA_GUS
GROUP  BY g.KLASA_GUS, g.LP, g.GUS_FIRMY_AKTYWNE, g.GUS_FIRMY_REGON, g.GUS_PRACUJACY
ORDER  BY g.LP;


-- === D09 Proporcje podzialu klas GUS na pietra (% firm F_ i % pracujacych P_)
WITH db AS (
    SELECT REGEXP_REPLACE(d.NIP, '[^0-9]', '')                              AS NIP,
           MAX(d.ZATRUDNIENIE) KEEP (DENSE_RANK LAST ORDER BY
               CASE WHEN d.ZATRUDNIENIE IS NOT NULL THEN 1 ELSE 0 END,
               d.ROK_ZATRUDNIENIA NULLS FIRST)                              AS ZATR,
           MAX(COALESCE(REGEXP_SUBSTR(d.DZIALPKD, '^[0-9]{2}'),
                        REGEXP_SUBSTR(d.PKD, '^[0-9]{2}')))                 AS DZIAL_DB
    FROM   WORK_POLAND.DB_BAZA d
    WHERE  LENGTH(REGEXP_REPLACE(d.NIP, '[^0-9]', '')) = 10
    GROUP  BY REGEXP_REPLACE(d.NIP, '[^0-9]', '')
),
kpp AS (
    SELECT LPAD(TO_CHAR(NIP), 10, '0')                                      AS NIP,
           MAX(REGEXP_SUBSTR(KOD_PKD, '^[0-9]{2}'))                         AS DZIAL_KPP
    FROM   WORK_POLAND.T_KATALOG_PODMIOTOW_PUBLICZNYCH
    WHERE  NIP IS NOT NULL AND KATEGORIA_PODMIOTU = 'PUBLIC' AND NVL(STATUS, 'ACTIVE') = 'ACTIVE'
    GROUP  BY LPAD(TO_CHAR(NIP), 10, '0')
),
f AS (
    SELECT db.NIP, db.ZATR,
           CASE WHEN (kpp.NIP IS NOT NULL
                      OR REGEXP_LIKE(UPPER(cg.FORMA_WLASNOSCI), '^ *1[0-9]{2}|SKARBU PA.{1,2}STWA|PA.{1,2}STWOWYCH OS.{1,2}B PRAWNYCH|SAMORZ.{1,2}DU TERYTORIALNEGO|W SEKTORZE PUBLICZNYM|SEKTORAMI Z PRZEWAG.{1,2} W.{1,2}ASNO.{1,2}CI SEKTORA PUBLICZNEGO'))
                 AND COALESCE(SUBSTR(REGEXP_REPLACE(cg.PKD_KOD, '[^0-9]', ''), 1, 2), kpp.DZIAL_KPP, db.DZIAL_DB)
                     IN ('84','85','86','87','88','90','91','92','93')
                THEN 'T' ELSE 'N' END                                       AS FLAGA_PUBLIC,
           CASE WHEN NVL(cg.DELETION_FLAG, 'N') = 'Y' OR cg.DATA_SKRESLENIA IS NOT NULL
                  OR cg.DATA_ZAKONCZENIA IS NOT NULL
                  OR (cg.DATA_ZAWIESZENIA IS NOT NULL
                      AND (cg.DATA_WZNAWIENIA IS NULL OR cg.DATA_WZNAWIENIA < cg.DATA_ZAWIESZENIA))
                THEN 'T' ELSE 'N' END                                       AS NIEAKTYWNA
    FROM   db
    LEFT JOIN WORK_POLAND.T_CEIDG_GUS cg ON cg.NIP = db.NIP
    LEFT JOIN kpp ON kpp.NIP = db.NIP
),
p AS (
    SELECT ZATR,
           CASE WHEN ZATR < 10 THEN '0-9' WHEN ZATR < 50 THEN '10-49' WHEN ZATR < 250 THEN '50-249'
                WHEN ZATR < 1000 THEN '250-999' ELSE '1000+' END            AS KLASA_GUS,
           CASE WHEN ZATR <= 40 THEN 1 WHEN ZATR <= 200 THEN 2 WHEN ZATR <= 500 THEN 3
                WHEN ZATR <= 4000 THEN 4 ELSE 5 END                         AS PIETRO
    FROM   f
    WHERE  ZATR > 0 AND FLAGA_PUBLIC = 'N' AND NIEAKTYWNA = 'N'
),
k AS (
    SELECT KLASA_GUS, PIETRO, ZATR FROM p
    UNION ALL
    SELECT '250+', PIETRO, ZATR FROM p WHERE ZATR >= 250
)
SELECT KLASA_GUS,
       COUNT(*)                                                                         AS DB_FIRMY,
       ROUND(SUM(CASE WHEN PIETRO = 1 THEN 1 ELSE 0 END) / COUNT(*) * 100, 1)          AS F_0_40,
       ROUND(SUM(CASE WHEN PIETRO = 2 THEN 1 ELSE 0 END) / COUNT(*) * 100, 1)          AS F_41_200,
       ROUND(SUM(CASE WHEN PIETRO = 3 THEN 1 ELSE 0 END) / COUNT(*) * 100, 1)          AS F_201_500,
       ROUND(SUM(CASE WHEN PIETRO = 4 THEN 1 ELSE 0 END) / COUNT(*) * 100, 1)          AS F_501_4000,
       ROUND(SUM(CASE WHEN PIETRO = 5 THEN 1 ELSE 0 END) / COUNT(*) * 100, 1)          AS F_4001,
       ROUND(SUM(CASE WHEN PIETRO = 1 THEN ZATR ELSE 0 END) / SUM(ZATR) * 100, 1)      AS P_0_40,
       ROUND(SUM(CASE WHEN PIETRO = 2 THEN ZATR ELSE 0 END) / SUM(ZATR) * 100, 1)      AS P_41_200,
       ROUND(SUM(CASE WHEN PIETRO = 3 THEN ZATR ELSE 0 END) / SUM(ZATR) * 100, 1)      AS P_201_500,
       ROUND(SUM(CASE WHEN PIETRO = 4 THEN ZATR ELSE 0 END) / SUM(ZATR) * 100, 1)      AS P_501_4000,
       ROUND(SUM(CASE WHEN PIETRO = 5 THEN ZATR ELSE 0 END) / SUM(ZATR) * 100, 1)      AS P_4001
FROM   k
GROUP  BY KLASA_GUS
ORDER  BY DECODE(KLASA_GUS, '0-9', 1, '10-49', 2, '50-249', 3, '250-999', 4, '1000+', 5, '250+', 6);


-- === D10 Duze firmy w DB_BAZA: 1000+ i 4001+ vs GUS, duplikaty zatrudnienia w grupach
WITH db AS (
    SELECT REGEXP_REPLACE(d.NIP, '[^0-9]', '')                              AS NIP,
           MAX(d.ZATRUDNIENIE) KEEP (DENSE_RANK LAST ORDER BY
               CASE WHEN d.ZATRUDNIENIE IS NOT NULL THEN 1 ELSE 0 END,
               d.ROK_ZATRUDNIENIA NULLS FIRST)                              AS ZATR,
           MAX(d.GRUPA_KAPITALOWA) KEEP (DENSE_RANK LAST ORDER BY
               d.ROK_ZATRUDNIENIA NULLS FIRST)                              AS GRUPA,
           MAX(COALESCE(REGEXP_SUBSTR(d.DZIALPKD, '^[0-9]{2}'),
                        REGEXP_SUBSTR(d.PKD, '^[0-9]{2}')))                 AS DZIAL_DB
    FROM   WORK_POLAND.DB_BAZA d
    WHERE  LENGTH(REGEXP_REPLACE(d.NIP, '[^0-9]', '')) = 10
    GROUP  BY REGEXP_REPLACE(d.NIP, '[^0-9]', '')
),
kpp AS (
    SELECT LPAD(TO_CHAR(NIP), 10, '0')                                      AS NIP,
           MAX(REGEXP_SUBSTR(KOD_PKD, '^[0-9]{2}'))                         AS DZIAL_KPP
    FROM   WORK_POLAND.T_KATALOG_PODMIOTOW_PUBLICZNYCH
    WHERE  NIP IS NOT NULL AND KATEGORIA_PODMIOTU = 'PUBLIC' AND NVL(STATUS, 'ACTIVE') = 'ACTIVE'
    GROUP  BY LPAD(TO_CHAR(NIP), 10, '0')
),
f AS (
    SELECT db.NIP, db.ZATR, db.GRUPA,
           CASE WHEN (kpp.NIP IS NOT NULL
                      OR REGEXP_LIKE(UPPER(cg.FORMA_WLASNOSCI), '^ *1[0-9]{2}|SKARBU PA.{1,2}STWA|PA.{1,2}STWOWYCH OS.{1,2}B PRAWNYCH|SAMORZ.{1,2}DU TERYTORIALNEGO|W SEKTORZE PUBLICZNYM|SEKTORAMI Z PRZEWAG.{1,2} W.{1,2}ASNO.{1,2}CI SEKTORA PUBLICZNEGO'))
                 AND COALESCE(SUBSTR(REGEXP_REPLACE(cg.PKD_KOD, '[^0-9]', ''), 1, 2), kpp.DZIAL_KPP, db.DZIAL_DB)
                     IN ('84','85','86','87','88','90','91','92','93')
                THEN 'T' ELSE 'N' END                                       AS FLAGA_PUBLIC,
           CASE WHEN NVL(cg.DELETION_FLAG, 'N') = 'Y' OR cg.DATA_SKRESLENIA IS NOT NULL
                  OR cg.DATA_ZAKONCZENIA IS NOT NULL
                  OR (cg.DATA_ZAWIESZENIA IS NOT NULL
                      AND (cg.DATA_WZNAWIENIA IS NULL OR cg.DATA_WZNAWIENIA < cg.DATA_ZAWIESZENIA))
                THEN 'T' ELSE 'N' END                                       AS NIEAKTYWNA
    FROM   db
    LEFT JOIN WORK_POLAND.T_CEIDG_GUS cg ON cg.NIP = db.NIP
    LEFT JOIN kpp ON kpp.NIP = db.NIP
    WHERE  db.ZATR >= 1000
),
g AS (
    SELECT f.*,
           CASE WHEN GRUPA IS NOT NULL
                THEN COUNT(*) OVER (PARTITION BY GRUPA, ZATR) END           AS DUPL
    FROM   f
    WHERE  FLAGA_PUBLIC = 'N' AND NIEAKTYWNA = 'N'
)
SELECT COUNT(*)                                                         AS DB_FIRMY_1000,
       SUM(ZATR)                                                        AS DB_PRAC_1000,
       SUM(CASE WHEN ZATR > 4000 THEN 1 ELSE 0 END)                     AS DB_FIRMY_4001,
       SUM(CASE WHEN ZATR > 4000 THEN ZATR END)                         AS DB_PRAC_4001,
       SUM(CASE WHEN DUPL > 1 THEN 1 ELSE 0 END)                        AS DB_1000_DUPLIKAT_GRUPY,
       SUM(CASE WHEN ZATR > 4000 AND DUPL > 1 THEN 1 ELSE 0 END)        AS DB_4001_DUPLIKAT_GRUPY,
       521                                                              AS GUS_REGON_FIRMY_1000,
       1968204                                                          AS GUS_PRAC_1000
FROM   g;


-- === D11 Top 40 firm wg zatrudnienia w DB_BAZA (poza Public, aktywne)
WITH db AS (
    SELECT REGEXP_REPLACE(d.NIP, '[^0-9]', '')                              AS NIP,
           MAX(d.ZATRUDNIENIE) KEEP (DENSE_RANK LAST ORDER BY
               CASE WHEN d.ZATRUDNIENIE IS NOT NULL THEN 1 ELSE 0 END,
               d.ROK_ZATRUDNIENIA NULLS FIRST)                              AS ZATR,
           MAX(SUBSTR(d.ROK_ZATRUDNIENIA, 1, 10)) KEEP (DENSE_RANK LAST ORDER BY
               CASE WHEN d.ZATRUDNIENIE IS NOT NULL THEN 1 ELSE 0 END,
               d.ROK_ZATRUDNIENIA NULLS FIRST)                              AS ROK,
           MAX(d.NAZWA_REJ) KEEP (DENSE_RANK LAST ORDER BY
               d.ROK_ZATRUDNIENIA NULLS FIRST)                              AS NAZWA,
           MAX(d.GRUPA_KAPITALOWA) KEEP (DENSE_RANK LAST ORDER BY
               d.ROK_ZATRUDNIENIA NULLS FIRST)                              AS GRUPA,
           MAX(COALESCE(REGEXP_SUBSTR(d.DZIALPKD, '^[0-9]{2}'),
                        REGEXP_SUBSTR(d.PKD, '^[0-9]{2}')))                 AS DZIAL_DB
    FROM   WORK_POLAND.DB_BAZA d
    WHERE  LENGTH(REGEXP_REPLACE(d.NIP, '[^0-9]', '')) = 10
    GROUP  BY REGEXP_REPLACE(d.NIP, '[^0-9]', '')
),
kpp AS (
    SELECT LPAD(TO_CHAR(NIP), 10, '0')                                      AS NIP,
           MAX(REGEXP_SUBSTR(KOD_PKD, '^[0-9]{2}'))                         AS DZIAL_KPP
    FROM   WORK_POLAND.T_KATALOG_PODMIOTOW_PUBLICZNYCH
    WHERE  NIP IS NOT NULL AND KATEGORIA_PODMIOTU = 'PUBLIC' AND NVL(STATUS, 'ACTIVE') = 'ACTIVE'
    GROUP  BY LPAD(TO_CHAR(NIP), 10, '0')
),
f AS (
    SELECT db.NIP, db.ZATR, db.ROK, db.GRUPA,
           COALESCE(cg.NAZWA, db.NAZWA)                                     AS NAZWA,
           COALESCE(SUBSTR(REGEXP_REPLACE(cg.PKD_KOD, '[^0-9]', ''), 1, 2), kpp.DZIAL_KPP, db.DZIAL_DB) AS DZIAL,
           CASE WHEN (kpp.NIP IS NOT NULL
                      OR REGEXP_LIKE(UPPER(cg.FORMA_WLASNOSCI), '^ *1[0-9]{2}|SKARBU PA.{1,2}STWA|PA.{1,2}STWOWYCH OS.{1,2}B PRAWNYCH|SAMORZ.{1,2}DU TERYTORIALNEGO|W SEKTORZE PUBLICZNYM|SEKTORAMI Z PRZEWAG.{1,2} W.{1,2}ASNO.{1,2}CI SEKTORA PUBLICZNEGO'))
                 AND COALESCE(SUBSTR(REGEXP_REPLACE(cg.PKD_KOD, '[^0-9]', ''), 1, 2), kpp.DZIAL_KPP, db.DZIAL_DB)
                     IN ('84','85','86','87','88','90','91','92','93')
                THEN 'T' ELSE 'N' END                                       AS FLAGA_PUBLIC,
           CASE WHEN NVL(cg.DELETION_FLAG, 'N') = 'Y' OR cg.DATA_SKRESLENIA IS NOT NULL
                  OR cg.DATA_ZAKONCZENIA IS NOT NULL
                  OR (cg.DATA_ZAWIESZENIA IS NOT NULL
                      AND (cg.DATA_WZNAWIENIA IS NULL OR cg.DATA_WZNAWIENIA < cg.DATA_ZAWIESZENIA))
                THEN 'T' ELSE 'N' END                                       AS NIEAKTYWNA
    FROM   db
    LEFT JOIN WORK_POLAND.T_CEIDG_GUS cg ON cg.NIP = db.NIP
    LEFT JOIN kpp ON kpp.NIP = db.NIP
    WHERE  db.ZATR >= 1000
),
g AS (
    SELECT f.*,
           CASE WHEN GRUPA IS NOT NULL
                THEN COUNT(*) OVER (PARTITION BY GRUPA, ZATR) END           AS NIP_W_GRUPIE_Z_TYM_ZATR
    FROM   f
    WHERE  FLAGA_PUBLIC = 'N' AND NIEAKTYWNA = 'N'
)
SELECT NIP, SUBSTR(NAZWA, 1, 60) AS NAZWA, ZATR, ROK, DZIAL,
       SUBSTR(GRUPA, 1, 40) AS GRUPA, NIP_W_GRUPIE_Z_TYM_ZATR
FROM   g
ORDER  BY ZATR DESC
FETCH FIRST 40 ROWS ONLY;


-- =====================================================================
-- C. NASI KLIENCI (faktury z ostatnich 12 zamknietych miesiecy)
-- =====================================================================

-- === D12 Klienci LTM: NIP i pokrycie danymi (DB_BAZA, CEIDG_GUS, Katalog Podm. Publ.)
WITH linie AS (
    SELECT REGEXP_REPLACE(tp.TAX_NUMBER1, '[^0-9]', '')                     AS NIP,
           til.SALES_AMOUNT
    FROM   POLAND.T_INVOICE_LINE til
    LEFT JOIN POLAND.T_PAYER tp
           ON  tp.PAYER_NUMBER = til.PAYER_NUMBER
           AND tp.COUNTRY_CODE = til.COUNTRY_CODE
    WHERE  til.COUNTRY_CODE        = 'PL'
      AND  til.BUSINESS_SCOPE_FLAG = 'Y'
      AND  NVL(til.CANCELLED_FLAG, 'N')   <> 'Y'
      AND  NVL(til.DL_DELETION_FLAG, 'N') <> 'Y'
      AND  til.INVOICE_DATE >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -12)
      AND  til.INVOICE_DATE <  TRUNC(SYSDATE, 'MM')
),
nip AS (
    SELECT NIP, SUM(SALES_AMOUNT) AS SALES FROM linie GROUP BY NIP
),
db AS (
    SELECT REGEXP_REPLACE(d.NIP, '[^0-9]', '')                              AS NIP,
           MAX(d.ZATRUDNIENIE) KEEP (DENSE_RANK LAST ORDER BY
               CASE WHEN d.ZATRUDNIENIE IS NOT NULL THEN 1 ELSE 0 END,
               d.ROK_ZATRUDNIENIA NULLS FIRST)                              AS ZATR
    FROM   WORK_POLAND.DB_BAZA d
    WHERE  LENGTH(REGEXP_REPLACE(d.NIP, '[^0-9]', '')) = 10
    GROUP  BY REGEXP_REPLACE(d.NIP, '[^0-9]', '')
),
kpp AS (
    SELECT DISTINCT LPAD(TO_CHAR(NIP), 10, '0') AS NIP
    FROM   WORK_POLAND.T_KATALOG_PODMIOTOW_PUBLICZNYCH
    WHERE  NIP IS NOT NULL
)
SELECT CASE WHEN n.NIP IS NULL        THEN '1 BEZ_NIP'
            WHEN LENGTH(n.NIP) <> 10  THEN '2 NIP_NIE_10_CYFR'
            WHEN n.SALES <= 0         THEN '3 SPRZEDAZ_NETTO_<=0'
            ELSE                           '4 KLIENT_AKTYWNY' END       AS GRUPA,
       COUNT(n.NIP)                                                     AS LICZBA_NIP,
       ROUND(RATIO_TO_REPORT(SUM(n.SALES)) OVER () * 100, 2)            AS PCT_SPRZEDAZY,
       COUNT(db.NIP)                                                    AS W_DB_BAZA,
       SUM(CASE WHEN db.ZATR > 0 THEN 1 ELSE 0 END)                     AS Z_ZATRUDNIENIEM,
       ROUND(SUM(CASE WHEN db.ZATR > 0 THEN n.SALES END)
             / NULLIF(SUM(n.SALES), 0) * 100, 1)                        AS PCT_SPRZ_Z_ZATRUDNIENIEM,
       COUNT(cg.NIP)                                                    AS W_CEIDG_GUS,
       COUNT(kpp.NIP)                                                   AS W_KATALOGU_PUBL
FROM   nip n
LEFT JOIN db  ON db.NIP  = n.NIP
LEFT JOIN WORK_POLAND.T_CEIDG_GUS cg ON cg.NIP = n.NIP
LEFT JOIN kpp ON kpp.NIP = n.NIP
GROUP  BY CASE WHEN n.NIP IS NULL        THEN '1 BEZ_NIP'
               WHEN LENGTH(n.NIP) <> 10  THEN '2 NIP_NIE_10_CYFR'
               WHEN n.SALES <= 0         THEN '3 SPRZEDAZ_NETTO_<=0'
               ELSE                           '4 KLIENT_AKTYWNY' END
ORDER  BY GRUPA;


-- === D13 Wstepna piramida NASZYCH klientow (aktywni LTM)
WITH linie AS (
    SELECT REGEXP_REPLACE(tp.TAX_NUMBER1, '[^0-9]', '')                     AS NIP,
           til.SALES_AMOUNT
    FROM   POLAND.T_INVOICE_LINE til
    JOIN   POLAND.T_PAYER tp
           ON  tp.PAYER_NUMBER = til.PAYER_NUMBER
           AND tp.COUNTRY_CODE = til.COUNTRY_CODE
    WHERE  til.COUNTRY_CODE        = 'PL'
      AND  til.BUSINESS_SCOPE_FLAG = 'Y'
      AND  NVL(til.CANCELLED_FLAG, 'N')   <> 'Y'
      AND  NVL(til.DL_DELETION_FLAG, 'N') <> 'Y'
      AND  til.INVOICE_DATE >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -12)
      AND  til.INVOICE_DATE <  TRUNC(SYSDATE, 'MM')
),
nip AS (
    SELECT NIP, SUM(SALES_AMOUNT) AS SALES
    FROM   linie
    WHERE  NIP IS NOT NULL
    GROUP  BY NIP
    HAVING SUM(SALES_AMOUNT) > 0
),
db AS (
    SELECT REGEXP_REPLACE(d.NIP, '[^0-9]', '')                              AS NIP,
           MAX(d.ZATRUDNIENIE) KEEP (DENSE_RANK LAST ORDER BY
               CASE WHEN d.ZATRUDNIENIE IS NOT NULL THEN 1 ELSE 0 END,
               d.ROK_ZATRUDNIENIA NULLS FIRST)                              AS ZATR,
           MAX(COALESCE(REGEXP_SUBSTR(d.DZIALPKD, '^[0-9]{2}'),
                        REGEXP_SUBSTR(d.PKD, '^[0-9]{2}')))                 AS DZIAL_DB
    FROM   WORK_POLAND.DB_BAZA d
    WHERE  LENGTH(REGEXP_REPLACE(d.NIP, '[^0-9]', '')) = 10
    GROUP  BY REGEXP_REPLACE(d.NIP, '[^0-9]', '')
),
kpp AS (
    SELECT LPAD(TO_CHAR(NIP), 10, '0')                                      AS NIP,
           MAX(REGEXP_SUBSTR(KOD_PKD, '^[0-9]{2}'))                         AS DZIAL_KPP
    FROM   WORK_POLAND.T_KATALOG_PODMIOTOW_PUBLICZNYCH
    WHERE  NIP IS NOT NULL AND KATEGORIA_PODMIOTU = 'PUBLIC' AND NVL(STATUS, 'ACTIVE') = 'ACTIVE'
    GROUP  BY LPAD(TO_CHAR(NIP), 10, '0')
),
f AS (
    SELECT n.NIP, n.SALES, db.ZATR,
           CASE WHEN (kpp.NIP IS NOT NULL
                      OR REGEXP_LIKE(UPPER(cg.FORMA_WLASNOSCI), '^ *1[0-9]{2}|SKARBU PA.{1,2}STWA|PA.{1,2}STWOWYCH OS.{1,2}B PRAWNYCH|SAMORZ.{1,2}DU TERYTORIALNEGO|W SEKTORZE PUBLICZNYM|SEKTORAMI Z PRZEWAG.{1,2} W.{1,2}ASNO.{1,2}CI SEKTORA PUBLICZNEGO'))
                 AND COALESCE(SUBSTR(REGEXP_REPLACE(cg.PKD_KOD, '[^0-9]', ''), 1, 2), kpp.DZIAL_KPP, db.DZIAL_DB)
                     IN ('84','85','86','87','88','90','91','92','93')
                THEN 'T' ELSE 'N' END                                       AS FLAGA_PUBLIC
    FROM   nip n
    LEFT JOIN db  ON db.NIP  = n.NIP
    LEFT JOIN WORK_POLAND.T_CEIDG_GUS cg ON cg.NIP = n.NIP
    LEFT JOIN kpp ON kpp.NIP = n.NIP
),
p AS (
    SELECT f.*,
           CASE WHEN FLAGA_PUBLIC = 'T'      THEN '6 PUBLIC'
                WHEN ZATR IS NULL      THEN '99 NIEPRZYPISANE'
                WHEN ZATR <= 40        THEN '1 0-40'
                WHEN ZATR <= 200       THEN '2 41-200'
                WHEN ZATR <= 500       THEN '3 201-500'
                WHEN ZATR <= 4000      THEN '4 501-4000'
                ELSE                        '5 4001+' END                   AS PIETRO
    FROM   f
)
SELECT PIETRO,
       COUNT(*)                                                         AS FIRMY_LYRECO,
       COUNT(ZATR)                                                      AS FIRMY_Z_ZATRUDNIENIEM,
       SUM(ZATR)                                                        AS PRACUJACY_U_KLIENTOW,
       SUM(CASE WHEN ZATR <= 9 THEN 1 ELSE 0 END)                       AS W_TYM_0_9,
       ROUND(RATIO_TO_REPORT(SUM(SALES)) OVER () * 100, 1)              AS PCT_SPRZEDAZY
FROM   p
GROUP  BY PIETRO
ORDER  BY TO_NUMBER(SUBSTR(PIETRO, 1, INSTR(PIETRO, ' ') - 1));


-- === D14 Flaga Public vs przypisanie w sprzedazy (typ glownego SOLDTO, region z "PUBLI")
WITH linie AS (
    SELECT REGEXP_REPLACE(tp.TAX_NUMBER1, '[^0-9]', '')                     AS NIP,
           til.SOLDTO_NUMBER,
           til.SALES_AMOUNT
    FROM   POLAND.T_INVOICE_LINE til
    JOIN   POLAND.T_PAYER tp
           ON  tp.PAYER_NUMBER = til.PAYER_NUMBER
           AND tp.COUNTRY_CODE = til.COUNTRY_CODE
    WHERE  til.COUNTRY_CODE        = 'PL'
      AND  til.BUSINESS_SCOPE_FLAG = 'Y'
      AND  NVL(til.CANCELLED_FLAG, 'N')   <> 'Y'
      AND  NVL(til.DL_DELETION_FLAG, 'N') <> 'Y'
      AND  til.INVOICE_DATE >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -12)
      AND  til.INVOICE_DATE <  TRUNC(SYSDATE, 'MM')
),
soldto AS (
    SELECT NIP, SOLDTO_NUMBER, SUM(SALES_AMOUNT) AS SALES
    FROM   linie
    WHERE  NIP IS NOT NULL
    GROUP  BY NIP, SOLDTO_NUMBER
),
nip AS (
    SELECT s.NIP,
           SUM(s.SALES)                                                     AS SALES,
           MAX(ts.SALES_FORCE_TYPE_CODE) KEEP (DENSE_RANK LAST ORDER BY s.SALES NULLS FIRST) AS TYP,
           MAX(CASE WHEN UPPER(sfr.SALES_FORCE_REGION) LIKE '%PUBLI%' THEN 'T' ELSE 'N' END) AS REGION_PUBLIC
    FROM   soldto s
    LEFT JOIN POLAND.T_SOLDTO ts
           ON  ts.SOLDTO_NUMBER = s.SOLDTO_NUMBER
           AND ts.COUNTRY_CODE  = 'PL'
    LEFT JOIN SHARED.T_SALES_FORCE_REGION sfr
           ON  sfr.SALES_FORCE_REGION_CODE = ts.SALES_FORCE_REGION_CODE
           AND sfr.COUNTRY_CODE            = 'PL'
           AND sfr.LANGUAGE_CODE           = 'POLISH'
    GROUP  BY s.NIP
    HAVING SUM(s.SALES) > 0
),
db AS (
    SELECT REGEXP_REPLACE(d.NIP, '[^0-9]', '')                              AS NIP,
           MAX(COALESCE(REGEXP_SUBSTR(d.DZIALPKD, '^[0-9]{2}'),
                        REGEXP_SUBSTR(d.PKD, '^[0-9]{2}')))                 AS DZIAL_DB
    FROM   WORK_POLAND.DB_BAZA d
    WHERE  LENGTH(REGEXP_REPLACE(d.NIP, '[^0-9]', '')) = 10
    GROUP  BY REGEXP_REPLACE(d.NIP, '[^0-9]', '')
),
kpp AS (
    SELECT LPAD(TO_CHAR(NIP), 10, '0')                                      AS NIP,
           MAX(REGEXP_SUBSTR(KOD_PKD, '^[0-9]{2}'))                         AS DZIAL_KPP
    FROM   WORK_POLAND.T_KATALOG_PODMIOTOW_PUBLICZNYCH
    WHERE  NIP IS NOT NULL AND KATEGORIA_PODMIOTU = 'PUBLIC' AND NVL(STATUS, 'ACTIVE') = 'ACTIVE'
    GROUP  BY LPAD(TO_CHAR(NIP), 10, '0')
),
f AS (
    SELECT n.*,
           CASE WHEN kpp.NIP IS NOT NULL
                  OR REGEXP_LIKE(UPPER(cg.FORMA_WLASNOSCI), '^ *1[0-9]{2}|SKARBU PA.{1,2}STWA|PA.{1,2}STWOWYCH OS.{1,2}B PRAWNYCH|SAMORZ.{1,2}DU TERYTORIALNEGO|W SEKTORZE PUBLICZNYM|SEKTORAMI Z PRZEWAG.{1,2} W.{1,2}ASNO.{1,2}CI SEKTORA PUBLICZNEGO')            THEN 'PUBLICZNY'
                WHEN cg.FORMA_WLASNOSCI IS NOT NULL OR cg.TYP_PODMIOTU = 'F' THEN 'PRYWATNY'
                ELSE                                                             'NIEZNANY' END AS SEKTOR,
           COALESCE(SUBSTR(REGEXP_REPLACE(cg.PKD_KOD, '[^0-9]', ''), 1, 2), kpp.DZIAL_KPP, db.DZIAL_DB) AS DZIAL
    FROM   nip n
    LEFT JOIN db  ON db.NIP  = n.NIP
    LEFT JOIN WORK_POLAND.T_CEIDG_GUS cg ON cg.NIP = n.NIP
    LEFT JOIN kpp ON kpp.NIP = n.NIP
)
SELECT CASE WHEN SEKTOR = 'PUBLICZNY' AND DZIAL IN ('84','85','86','87','88','90','91','92','93')
            THEN 'T' ELSE 'N' END                                       AS FLAGA_PUBLIC,
       SEKTOR,
       NVL(TYP, '-')                                                    AS TYP_SOLDTO,
       REGION_PUBLIC,
       COUNT(*)                                                         AS KLIENCI,
       ROUND(RATIO_TO_REPORT(SUM(SALES)) OVER () * 100, 2)              AS PCT_SPRZEDAZY
FROM   f
GROUP  BY CASE WHEN SEKTOR = 'PUBLICZNY' AND DZIAL IN ('84','85','86','87','88','90','91','92','93')
               THEN 'T' ELSE 'N' END,
          SEKTOR, NVL(TYP, '-'), REGION_PUBLIC
ORDER  BY KLIENCI DESC;


-- === D15 Regiony sprzedazy (obecne przypisanie SOLDTO) - klienci LTM
WITH linie AS (
    SELECT REGEXP_REPLACE(tp.TAX_NUMBER1, '[^0-9]', '')                     AS NIP,
           til.SOLDTO_NUMBER,
           til.SALES_AMOUNT
    FROM   POLAND.T_INVOICE_LINE til
    JOIN   POLAND.T_PAYER tp
           ON  tp.PAYER_NUMBER = til.PAYER_NUMBER
           AND tp.COUNTRY_CODE = til.COUNTRY_CODE
    WHERE  til.COUNTRY_CODE        = 'PL'
      AND  til.BUSINESS_SCOPE_FLAG = 'Y'
      AND  NVL(til.CANCELLED_FLAG, 'N')   <> 'Y'
      AND  NVL(til.DL_DELETION_FLAG, 'N') <> 'Y'
      AND  til.INVOICE_DATE >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -12)
      AND  til.INVOICE_DATE <  TRUNC(SYSDATE, 'MM')
)
SELECT NVL(ts.SALES_FORCE_TYPE_CODE, '-')                               AS TYP_SOLDTO,
       ts.SALES_FORCE_REGION_CODE,
       SUBSTR(sfr.SALES_FORCE_REGION, 1, 50)                            AS REGION,
       COUNT(DISTINCT l.NIP)                                            AS NIP,
       ROUND(RATIO_TO_REPORT(SUM(l.SALES_AMOUNT)) OVER () * 100, 2)     AS PCT_SPRZEDAZY
FROM   linie l
LEFT JOIN POLAND.T_SOLDTO ts
       ON  ts.SOLDTO_NUMBER = l.SOLDTO_NUMBER
       AND ts.COUNTRY_CODE  = 'PL'
LEFT JOIN SHARED.T_SALES_FORCE_REGION sfr
       ON  sfr.SALES_FORCE_REGION_CODE = ts.SALES_FORCE_REGION_CODE
       AND sfr.COUNTRY_CODE            = 'PL'
       AND sfr.LANGUAGE_CODE           = 'POLISH'
GROUP  BY NVL(ts.SALES_FORCE_TYPE_CODE, '-'), ts.SALES_FORCE_REGION_CODE, SUBSTR(sfr.SALES_FORCE_REGION, 1, 50)
ORDER  BY PCT_SPRZEDAZY DESC
FETCH FIRST 60 ROWS ONLY;


-- =====================================================================
-- D. DOPISANE PO WYNIKACH D01-D04
-- =====================================================================

-- === D16 Katalog Podmiotow Publicznych (PUBLIC, ACTIVE) POZA dzialami wariantu B
-- Ktore podmioty publiczne z katalogu NIE trafia do Public, bo ich dzial PKD
-- jest spoza listy 84-88 / 90-93 (np. 69 - centra uslug wspolnych obslugujace
-- szkoly, 42 - zarzady drog, 68 - zarzady gospodarki mieszkaniowej).
SELECT NVL(REGEXP_SUBSTR(KOD_PKD, '^[0-9]{2}'), '??')                  AS DZIAL,
       SUBSTR(TYP_PODMIOTU, 1, 50)                                      AS TYP_PODMIOTU,
       COUNT(*)                                                         AS PODMIOTY,
       COUNT(DISTINCT NIP)                                              AS NIP_UNIKALNE,
       MAX(SUBSTR(FORMA_FINANSOWANIA, 1, 40))                           AS PRZYKLAD_FORMY_FINANSOWANIA,
       MAX(SUBSTR(NAZWA_PODMIOTU, 1, 60))                               AS PRZYKLAD_NAZWY
FROM   WORK_POLAND.T_KATALOG_PODMIOTOW_PUBLICZNYCH
WHERE  KATEGORIA_PODMIOTU = 'PUBLIC'
  AND  STATUS = 'ACTIVE'
  AND  NVL(REGEXP_SUBSTR(KOD_PKD, '^[0-9]{2}'), '??')
       NOT IN ('84','85','86','87','88','90','91','92','93')
GROUP  BY NVL(REGEXP_SUBSTR(KOD_PKD, '^[0-9]{2}'), '??'), SUBSTR(TYP_PODMIOTU, 1, 50)
ORDER  BY PODMIOTY DESC
FETCH FIRST 40 ROWS ONLY;


-- === D17 DB_BAZA: zrzuty (kolumna DB_BAZA) x rok badania (DATA_BADANIA)
-- Po D06: ROK_ZATRUDNIENIA nie mowi, jak stare jest zatrudnienie (lata od 1899,
-- 96% firm 1000+ bez roku). Sprawdzamy, czy aktualnosc pokazuje data zrzutu
-- albo data badania.
SELECT NVL(DB_BAZA, '(brak)')                                           AS ZRZUT,
       NVL(REGEXP_SUBSTR(DATA_BADANIA, '[0-9]{4}'), '(brak)')           AS ROK_BADANIA,
       COUNT(*)                                                         AS FIRMY,
       SUM(CASE WHEN ZATRUDNIENIE >= 50   THEN 1 ELSE 0 END)            AS FIRMY_50_PLUS,
       SUM(CASE WHEN ZATRUDNIENIE >= 1000 THEN 1 ELSE 0 END)            AS FIRMY_1000_PLUS
FROM   WORK_POLAND.DB_BAZA
GROUP  BY NVL(DB_BAZA, '(brak)'), NVL(REGEXP_SUBSTR(DATA_BADANIA, '[0-9]{4}'), '(brak)')
ORDER  BY ZRZUT, ROK_BADANIA DESC;


-- === D18 NASI klienci z sektora publicznego wg dzialu PKD: w wariancie B i POZA nim
-- Po D16: w katalogu sa publiczne podmioty spoza dzialow 84-88 / 90-93, np. centra
-- uslug wspolnych obslugujace szkoly (dzial 69), internaty i bursy (55), zarzady
-- drog (42, 52), zarzady gospodarki mieszkaniowej (68), komunalne (35-38).
-- Pokazuje, ile naszej sprzedazy wypada z Public przy obecnej definicji.
WITH linie AS (
    SELECT REGEXP_REPLACE(tp.TAX_NUMBER1, '[^0-9]', '')                     AS NIP,
           til.SALES_AMOUNT
    FROM   POLAND.T_INVOICE_LINE til
    JOIN   POLAND.T_PAYER tp
           ON  tp.PAYER_NUMBER = til.PAYER_NUMBER
           AND tp.COUNTRY_CODE = til.COUNTRY_CODE
    WHERE  til.COUNTRY_CODE        = 'PL'
      AND  til.BUSINESS_SCOPE_FLAG = 'Y'
      AND  NVL(til.CANCELLED_FLAG, 'N')   <> 'Y'
      AND  NVL(til.DL_DELETION_FLAG, 'N') <> 'Y'
      AND  til.INVOICE_DATE >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -12)
      AND  til.INVOICE_DATE <  TRUNC(SYSDATE, 'MM')
),
nip AS (
    SELECT NIP, SUM(SALES_AMOUNT) AS SALES
    FROM   linie
    WHERE  NIP IS NOT NULL
    GROUP  BY NIP
    HAVING SUM(SALES_AMOUNT) > 0
),
db AS (
    SELECT REGEXP_REPLACE(d.NIP, '[^0-9]', '')                              AS NIP,
           MAX(COALESCE(REGEXP_SUBSTR(d.DZIALPKD, '^[0-9]{2}'),
                        REGEXP_SUBSTR(d.PKD, '^[0-9]{2}')))                 AS DZIAL_DB
    FROM   WORK_POLAND.DB_BAZA d
    WHERE  LENGTH(REGEXP_REPLACE(d.NIP, '[^0-9]', '')) = 10
    GROUP  BY REGEXP_REPLACE(d.NIP, '[^0-9]', '')
),
kpp AS (
    SELECT LPAD(TO_CHAR(NIP), 10, '0')                                      AS NIP,
           MAX(REGEXP_SUBSTR(KOD_PKD, '^[0-9]{2}'))                         AS DZIAL_KPP,
           MAX(SUBSTR(TYP_PODMIOTU, 1, 40))                                 AS TYP_KPP
    FROM   WORK_POLAND.T_KATALOG_PODMIOTOW_PUBLICZNYCH
    WHERE  NIP IS NOT NULL AND KATEGORIA_PODMIOTU = 'PUBLIC' AND NVL(STATUS, 'ACTIVE') = 'ACTIVE'
    GROUP  BY LPAD(TO_CHAR(NIP), 10, '0')
),
f AS (
    SELECT n.NIP, n.SALES, kpp.TYP_KPP,
           CASE WHEN kpp.NIP IS NOT NULL
                  OR REGEXP_LIKE(UPPER(cg.FORMA_WLASNOSCI), '^ *1[0-9]{2}|SKARBU PA.{1,2}STWA|PA.{1,2}STWOWYCH OS.{1,2}B PRAWNYCH|SAMORZ.{1,2}DU TERYTORIALNEGO|W SEKTORZE PUBLICZNYM|SEKTORAMI Z PRZEWAG.{1,2} W.{1,2}ASNO.{1,2}CI SEKTORA PUBLICZNEGO')
                THEN 'PUBLICZNY' ELSE 'INNY' END                            AS SEKTOR,
           NVL(COALESCE(SUBSTR(REGEXP_REPLACE(cg.PKD_KOD, '[^0-9]', ''), 1, 2),
                        kpp.DZIAL_KPP, db.DZIAL_DB), '??')                  AS DZIAL
    FROM   nip n
    LEFT JOIN db  ON db.NIP  = n.NIP
    LEFT JOIN WORK_POLAND.T_CEIDG_GUS cg ON cg.NIP = n.NIP
    LEFT JOIN kpp ON kpp.NIP = n.NIP
),
tot AS (
    SELECT SUM(SALES) AS SALES_ALL FROM nip
)
SELECT CASE WHEN f.DZIAL IN ('84','85','86','87','88','90','91','92','93')
            THEN 'W PUBLIC (wariant B)' ELSE 'POZA PUBLIC' END              AS GRUPA,
       f.DZIAL,
       COUNT(*)                                                         AS KLIENCI,
       SUM(CASE WHEN f.TYP_KPP IS NOT NULL THEN 1 ELSE 0 END)           AS W_KATALOGU,
       MAX(f.TYP_KPP)                                                   AS PRZYKLAD_TYPU_Z_KATALOGU,
       ROUND(SUM(f.SALES) / MAX(t.SALES_ALL) * 100, 2)                  AS PCT_SPRZEDAZY_OGOLEM
FROM   f
CROSS JOIN tot t
WHERE  f.SEKTOR = 'PUBLICZNY'
GROUP  BY CASE WHEN f.DZIAL IN ('84','85','86','87','88','90','91','92','93')
               THEN 'W PUBLIC (wariant B)' ELSE 'POZA PUBLIC' END, f.DZIAL
ORDER  BY GRUPA DESC, PCT_SPRZEDAZY_OGOLEM DESC
FETCH FIRST 45 ROWS ONLY;


-- =====================================================================
-- E. DOPISANE PO WYNIKACH D12-D18: kim sa klienci NIEPRZYPISANI
-- (bez zatrudnienia w DB_BAZA, poza Public) - 14 tys. NIP, 17,5% sprzedazy.
-- DB_BAZA obejmuje ok. 100% firm 10+ (D08), wiec hipoteza: to glownie
-- mikrofirmy 0-9 i osoby fizyczne. Sprawdzamy, czy nie ma wsrod nich duzych.
-- =====================================================================

-- === D19 NIEPRZYPISANI wg typu podmiotu i formy prawnej (CEIDG_GUS)
WITH linie AS (
    SELECT REGEXP_REPLACE(tp.TAX_NUMBER1, '[^0-9]', '')                     AS NIP,
           til.SALES_AMOUNT
    FROM   POLAND.T_INVOICE_LINE til
    JOIN   POLAND.T_PAYER tp
           ON  tp.PAYER_NUMBER = til.PAYER_NUMBER
           AND tp.COUNTRY_CODE = til.COUNTRY_CODE
    WHERE  til.COUNTRY_CODE        = 'PL'
      AND  til.BUSINESS_SCOPE_FLAG = 'Y'
      AND  NVL(til.CANCELLED_FLAG, 'N')   <> 'Y'
      AND  NVL(til.DL_DELETION_FLAG, 'N') <> 'Y'
      AND  til.INVOICE_DATE >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -12)
      AND  til.INVOICE_DATE <  TRUNC(SYSDATE, 'MM')
),
nip AS (
    SELECT NIP, SUM(SALES_AMOUNT) AS SALES
    FROM   linie
    WHERE  NIP IS NOT NULL
    GROUP  BY NIP
    HAVING SUM(SALES_AMOUNT) > 0
),
tot AS (
    SELECT SUM(SALES) AS SALES_ALL FROM nip
),
db AS (
    SELECT DISTINCT REGEXP_REPLACE(d.NIP, '[^0-9]', '')                     AS NIP
    FROM   WORK_POLAND.DB_BAZA d
    WHERE  d.ZATRUDNIENIE IS NOT NULL
),
kpp AS (
    SELECT LPAD(TO_CHAR(NIP), 10, '0')                                      AS NIP,
           MAX(REGEXP_SUBSTR(KOD_PKD, '^[0-9]{2}'))                         AS DZIAL_KPP
    FROM   WORK_POLAND.T_KATALOG_PODMIOTOW_PUBLICZNYCH
    WHERE  NIP IS NOT NULL AND KATEGORIA_PODMIOTU = 'PUBLIC' AND NVL(STATUS, 'ACTIVE') = 'ACTIVE'
    GROUP  BY LPAD(TO_CHAR(NIP), 10, '0')
),
f AS (
    SELECT n.NIP, n.SALES, cg.TYP_PODMIOTU, cg.FORMA_PRAWNA, cg.DATA_WPISU_DO_REGON,
           CASE WHEN NVL(cg.DELETION_FLAG, 'N') = 'Y' OR cg.DATA_SKRESLENIA IS NOT NULL
                  OR cg.DATA_ZAKONCZENIA IS NOT NULL THEN 'T' ELSE 'N' END  AS ZAKONCZONA,
           CASE WHEN (kpp.NIP IS NOT NULL
                      OR REGEXP_LIKE(UPPER(cg.FORMA_WLASNOSCI), '^ *1[0-9]{2}|SKARBU PA.{1,2}STWA|PA.{1,2}STWOWYCH OS.{1,2}B PRAWNYCH|SAMORZ.{1,2}DU TERYTORIALNEGO|W SEKTORZE PUBLICZNYM|SEKTORAMI Z PRZEWAG.{1,2} W.{1,2}ASNO.{1,2}CI SEKTORA PUBLICZNEGO'))
                 AND COALESCE(SUBSTR(REGEXP_REPLACE(cg.PKD_KOD, '[^0-9]', ''), 1, 2), kpp.DZIAL_KPP)
                     IN ('84','85','86','87','88','90','91','92','93')
                THEN 'T' ELSE 'N' END                                       AS FLAGA_PUBLIC
    FROM   nip n
    LEFT JOIN db  ON db.NIP  = n.NIP
    LEFT JOIN WORK_POLAND.T_CEIDG_GUS cg ON cg.NIP = n.NIP
    LEFT JOIN kpp ON kpp.NIP = n.NIP
    WHERE  db.NIP IS NULL
)
SELECT NVL(f.TYP_PODMIOTU, '(brak w CEIDG_GUS)')                        AS TYP_PODMIOTU,
       SUBSTR(NVL(f.FORMA_PRAWNA, '(brak)'), 1, 60)                     AS FORMA_PRAWNA,
       COUNT(*)                                                         AS KLIENCI,
       SUM(CASE WHEN f.ZAKONCZONA = 'T' THEN 1 ELSE 0 END)              AS ZAKONCZONE,
       SUM(CASE WHEN f.DATA_WPISU_DO_REGON >= DATE '2024-01-01'
                THEN 1 ELSE 0 END)                                      AS ZAREJESTR_OD_2024,
       ROUND(SUM(f.SALES) / MAX(t.SALES_ALL) * 100, 2)                  AS PCT_SPRZEDAZY_OGOLEM,
       ROUND(MAX(f.SALES) / MAX(t.SALES_ALL) * 100, 3)                  AS PCT_NAJWIEKSZY_KLIENT
FROM   f
CROSS JOIN tot t
WHERE  f.FLAGA_PUBLIC = 'N'
GROUP  BY NVL(f.TYP_PODMIOTU, '(brak w CEIDG_GUS)'), SUBSTR(NVL(f.FORMA_PRAWNA, '(brak)'), 1, 60)
ORDER  BY PCT_SPRZEDAZY_OGOLEM DESC
FETCH FIRST 20 ROWS ONLY;


-- === D20 NIEPRZYPISANI: 30 najwiekszych wg sprzedazy (udzial %, bez kwot)
WITH linie AS (
    SELECT REGEXP_REPLACE(tp.TAX_NUMBER1, '[^0-9]', '')                     AS NIP,
           til.SALES_AMOUNT
    FROM   POLAND.T_INVOICE_LINE til
    JOIN   POLAND.T_PAYER tp
           ON  tp.PAYER_NUMBER = til.PAYER_NUMBER
           AND tp.COUNTRY_CODE = til.COUNTRY_CODE
    WHERE  til.COUNTRY_CODE        = 'PL'
      AND  til.BUSINESS_SCOPE_FLAG = 'Y'
      AND  NVL(til.CANCELLED_FLAG, 'N')   <> 'Y'
      AND  NVL(til.DL_DELETION_FLAG, 'N') <> 'Y'
      AND  til.INVOICE_DATE >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -12)
      AND  til.INVOICE_DATE <  TRUNC(SYSDATE, 'MM')
),
nip AS (
    SELECT NIP, SUM(SALES_AMOUNT) AS SALES
    FROM   linie
    WHERE  NIP IS NOT NULL
    GROUP  BY NIP
    HAVING SUM(SALES_AMOUNT) > 0
),
tot AS (
    SELECT SUM(SALES) AS SALES_ALL FROM nip
),
db AS (
    SELECT DISTINCT REGEXP_REPLACE(d.NIP, '[^0-9]', '')                     AS NIP
    FROM   WORK_POLAND.DB_BAZA d
    WHERE  d.ZATRUDNIENIE IS NOT NULL
),
kpp AS (
    SELECT LPAD(TO_CHAR(NIP), 10, '0')                                      AS NIP,
           MAX(REGEXP_SUBSTR(KOD_PKD, '^[0-9]{2}'))                         AS DZIAL_KPP
    FROM   WORK_POLAND.T_KATALOG_PODMIOTOW_PUBLICZNYCH
    WHERE  NIP IS NOT NULL AND KATEGORIA_PODMIOTU = 'PUBLIC' AND NVL(STATUS, 'ACTIVE') = 'ACTIVE'
    GROUP  BY LPAD(TO_CHAR(NIP), 10, '0')
),
f AS (
    SELECT n.NIP, n.SALES, cg.NAZWA, cg.TYP_PODMIOTU, cg.FORMA_PRAWNA, cg.DATA_WPISU_DO_REGON,
           COALESCE(SUBSTR(REGEXP_REPLACE(cg.PKD_KOD, '[^0-9]', ''), 1, 2), kpp.DZIAL_KPP) AS DZIAL,
           CASE WHEN (kpp.NIP IS NOT NULL
                      OR REGEXP_LIKE(UPPER(cg.FORMA_WLASNOSCI), '^ *1[0-9]{2}|SKARBU PA.{1,2}STWA|PA.{1,2}STWOWYCH OS.{1,2}B PRAWNYCH|SAMORZ.{1,2}DU TERYTORIALNEGO|W SEKTORZE PUBLICZNYM|SEKTORAMI Z PRZEWAG.{1,2} W.{1,2}ASNO.{1,2}CI SEKTORA PUBLICZNEGO'))
                 AND COALESCE(SUBSTR(REGEXP_REPLACE(cg.PKD_KOD, '[^0-9]', ''), 1, 2), kpp.DZIAL_KPP)
                     IN ('84','85','86','87','88','90','91','92','93')
                THEN 'T' ELSE 'N' END                                       AS FLAGA_PUBLIC
    FROM   nip n
    LEFT JOIN db  ON db.NIP  = n.NIP
    LEFT JOIN WORK_POLAND.T_CEIDG_GUS cg ON cg.NIP = n.NIP
    LEFT JOIN kpp ON kpp.NIP = n.NIP
    WHERE  db.NIP IS NULL
)
SELECT f.NIP,
       SUBSTR(f.NAZWA, 1, 60)                                           AS NAZWA,
       f.TYP_PODMIOTU,
       SUBSTR(f.FORMA_PRAWNA, 1, 40)                                    AS FORMA_PRAWNA,
       f.DZIAL,
       EXTRACT(YEAR FROM f.DATA_WPISU_DO_REGON)                         AS ROK_WPISU,
       ROUND(f.SALES / t.SALES_ALL * 100, 3)                            AS PCT_SPRZEDAZY_OGOLEM
FROM   f
CROSS JOIN tot t
WHERE  f.FLAGA_PUBLIC = 'N'
ORDER  BY f.SALES DESC
FETCH FIRST 30 ROWS ONLY;


-- =====================================================================
-- F. DOPISANE PO WYNIKACH D19-D20: wsrod nieprzypisanych sa tez duze firmy
-- (np. nowe spolki z 2022-2025 i firmy, ktorych DB_BAZA nie ma). Ile firm
-- trzeba uzupelnic recznie, zeby objac wiekszosc ich sprzedazy?
-- =====================================================================

-- === D21 NIEPRZYPISANI: ilu najwiekszych (wg sprzedazy) daje jaki % sprzedazy
WITH linie AS (
    SELECT REGEXP_REPLACE(tp.TAX_NUMBER1, '[^0-9]', '')                     AS NIP,
           til.SALES_AMOUNT
    FROM   POLAND.T_INVOICE_LINE til
    JOIN   POLAND.T_PAYER tp
           ON  tp.PAYER_NUMBER = til.PAYER_NUMBER
           AND tp.COUNTRY_CODE = til.COUNTRY_CODE
    WHERE  til.COUNTRY_CODE        = 'PL'
      AND  til.BUSINESS_SCOPE_FLAG = 'Y'
      AND  NVL(til.CANCELLED_FLAG, 'N')   <> 'Y'
      AND  NVL(til.DL_DELETION_FLAG, 'N') <> 'Y'
      AND  til.INVOICE_DATE >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -12)
      AND  til.INVOICE_DATE <  TRUNC(SYSDATE, 'MM')
),
nip AS (
    SELECT NIP, SUM(SALES_AMOUNT) AS SALES
    FROM   linie
    WHERE  NIP IS NOT NULL
    GROUP  BY NIP
    HAVING SUM(SALES_AMOUNT) > 0
),
tot AS (
    SELECT SUM(SALES) AS SALES_ALL FROM nip
),
db AS (
    SELECT DISTINCT REGEXP_REPLACE(d.NIP, '[^0-9]', '')                     AS NIP
    FROM   WORK_POLAND.DB_BAZA d
    WHERE  d.ZATRUDNIENIE IS NOT NULL
),
kpp AS (
    SELECT LPAD(TO_CHAR(NIP), 10, '0')                                      AS NIP,
           MAX(REGEXP_SUBSTR(KOD_PKD, '^[0-9]{2}'))                         AS DZIAL_KPP
    FROM   WORK_POLAND.T_KATALOG_PODMIOTOW_PUBLICZNYCH
    WHERE  NIP IS NOT NULL AND KATEGORIA_PODMIOTU = 'PUBLIC' AND NVL(STATUS, 'ACTIVE') = 'ACTIVE'
    GROUP  BY LPAD(TO_CHAR(NIP), 10, '0')
),
f AS (
    SELECT n.NIP, n.SALES,
           CASE WHEN cg.NIP IS NULL          THEN '3 BRAK_W_CEIDG_GUS'
                WHEN cg.TYP_PODMIOTU = 'F'   THEN '2 OSOBA_FIZYCZNA'
                ELSE                              '1 SPOLKA_LUB_INNA' END   AS GRUPA,
           CASE WHEN (kpp.NIP IS NOT NULL
                      OR REGEXP_LIKE(UPPER(cg.FORMA_WLASNOSCI), '^ *1[0-9]{2}|SKARBU PA.{1,2}STWA|PA.{1,2}STWOWYCH OS.{1,2}B PRAWNYCH|SAMORZ.{1,2}DU TERYTORIALNEGO|W SEKTORZE PUBLICZNYM|SEKTORAMI Z PRZEWAG.{1,2} W.{1,2}ASNO.{1,2}CI SEKTORA PUBLICZNEGO'))
                 AND COALESCE(SUBSTR(REGEXP_REPLACE(cg.PKD_KOD, '[^0-9]', ''), 1, 2), kpp.DZIAL_KPP)
                     IN ('84','85','86','87','88','90','91','92','93')
                THEN 'T' ELSE 'N' END                                       AS FLAGA_PUBLIC
    FROM   nip n
    LEFT JOIN db  ON db.NIP  = n.NIP
    LEFT JOIN WORK_POLAND.T_CEIDG_GUS cg ON cg.NIP = n.NIP
    LEFT JOIN kpp ON kpp.NIP = n.NIP
    WHERE  db.NIP IS NULL
),
u AS (
    SELECT f.*, ROW_NUMBER() OVER (PARTITION BY GRUPA ORDER BY SALES DESC)  AS RN
    FROM   f
    WHERE  FLAGA_PUBLIC = 'N'
),
progi AS (
    SELECT 50 AS TOP_N FROM dual UNION ALL SELECT 100 FROM dual UNION ALL
    SELECT 200 FROM dual UNION ALL SELECT 500 FROM dual UNION ALL
    SELECT 1000 FROM dual UNION ALL SELECT 2000 FROM dual UNION ALL
    SELECT 999999 FROM dual
)
SELECT u.GRUPA,
       CASE WHEN p.TOP_N = 999999 THEN 'WSZYSCY' ELSE 'TOP ' || p.TOP_N END AS ZAKRES,
       COUNT(*)                                                         AS KLIENCI,
       ROUND(SUM(u.SALES) / MAX(t.SALES_ALL) * 100, 2)                  AS PCT_SPRZEDAZY_OGOLEM
FROM   u
JOIN   progi p ON u.RN <= p.TOP_N
CROSS JOIN tot t
GROUP  BY u.GRUPA, p.TOP_N
ORDER  BY u.GRUPA, p.TOP_N;


-- === D22 NIEPRZYPISANI spoza T_CEIDG_GUS: kto to jest (top 25, nazwa z T_ACCOUNT)
WITH linie AS (
    SELECT REGEXP_REPLACE(tp.TAX_NUMBER1, '[^0-9]', '')                     AS NIP,
           tp.TAX_NUMBER1,
           til.PAYER_NUMBER,
           til.SALES_AMOUNT
    FROM   POLAND.T_INVOICE_LINE til
    JOIN   POLAND.T_PAYER tp
           ON  tp.PAYER_NUMBER = til.PAYER_NUMBER
           AND tp.COUNTRY_CODE = til.COUNTRY_CODE
    WHERE  til.COUNTRY_CODE        = 'PL'
      AND  til.BUSINESS_SCOPE_FLAG = 'Y'
      AND  NVL(til.CANCELLED_FLAG, 'N')   <> 'Y'
      AND  NVL(til.DL_DELETION_FLAG, 'N') <> 'Y'
      AND  til.INVOICE_DATE >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -12)
      AND  til.INVOICE_DATE <  TRUNC(SYSDATE, 'MM')
),
nip AS (
    SELECT NIP,
           SUM(SALES_AMOUNT)                                                AS SALES,
           MAX(TAX_NUMBER1)                                                 AS TAX_NUMBER1,
           MAX(PAYER_NUMBER)                                                AS PAYER_NUMBER
    FROM   linie
    WHERE  NIP IS NOT NULL
    GROUP  BY NIP
    HAVING SUM(SALES_AMOUNT) > 0
),
tot AS (
    SELECT SUM(SALES) AS SALES_ALL FROM nip
),
db AS (
    SELECT DISTINCT REGEXP_REPLACE(d.NIP, '[^0-9]', '')                     AS NIP
    FROM   WORK_POLAND.DB_BAZA d
    WHERE  d.ZATRUDNIENIE IS NOT NULL
)
SELECT n.NIP,
       n.TAX_NUMBER1                                                    AS NIP_W_SAP,
       SUBSTR(ta.NAME, 1, 60)                                           AS NAZWA_W_SAP,
       ta.CITY                                                          AS MIASTO,
       ROUND(n.SALES / t.SALES_ALL * 100, 3)                            AS PCT_SPRZEDAZY_OGOLEM
FROM   nip n
CROSS JOIN tot t
LEFT JOIN db ON db.NIP = n.NIP
LEFT JOIN WORK_POLAND.T_CEIDG_GUS cg ON cg.NIP = n.NIP
LEFT JOIN POLAND.T_ACCOUNT ta
       ON  ta.ACCOUNT_NUMBER = n.PAYER_NUMBER
       AND ta.COUNTRY_CODE   = 'PL'
WHERE  db.NIP IS NULL
  AND  cg.NIP IS NULL
ORDER  BY n.SALES DESC
FETCH FIRST 25 ROWS ONLY;


-- (D23-D26 o zatrudnieniu z BvD usuniete - decyzja 2026-11-26: BvD to slabe
--  zrodlo, nie uzywamy.)


-- =====================================================================
-- H. TOP_LEVEL (lider grupy zakupowej: COALESCE(NATIONAL_LEADER_NUMBER,
-- SOLDTO_NUMBER)) - czy pomoze oszacowac pietro NIEPRZYPISANYCH?
-- Pomysl: jezeli NIP-y z tej samej grupy, ktore maja zatrudnienie, sa
-- w wiekszosci na jednym pietrze (np. siec franczyzowa - wszystkie 0-40),
-- nieprzypisany NIP z tej grupy dostaje to pietro jako szacunek.
-- NIE przypisujemy NIP-owi zatrudnienia calej grupy (GUS liczy spolki).
-- =====================================================================

-- === D23 NIEPRZYPISANI wg rodzaju grupy TOP_LEVEL (+ najczestsze pietro w grupie)
WITH linie AS (
    SELECT REGEXP_REPLACE(tp.TAX_NUMBER1, '[^0-9]', '')                     AS NIP,
           til.SOLDTO_NUMBER,
           til.SALES_AMOUNT
    FROM   POLAND.T_INVOICE_LINE til
    JOIN   POLAND.T_PAYER tp
           ON  tp.PAYER_NUMBER = til.PAYER_NUMBER
           AND tp.COUNTRY_CODE = til.COUNTRY_CODE
    WHERE  til.COUNTRY_CODE        = 'PL'
      AND  til.BUSINESS_SCOPE_FLAG = 'Y'
      AND  NVL(til.CANCELLED_FLAG, 'N')   <> 'Y'
      AND  NVL(til.DL_DELETION_FLAG, 'N') <> 'Y'
      AND  til.INVOICE_DATE >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -12)
      AND  til.INVOICE_DATE <  TRUNC(SYSDATE, 'MM')
),
nip AS (
    SELECT NIP, SUM(SALES_AMOUNT) AS SALES
    FROM   linie
    WHERE  NIP IS NOT NULL
    GROUP  BY NIP
    HAVING SUM(SALES_AMOUNT) > 0
),
tot AS (
    SELECT SUM(SALES) AS SALES_ALL FROM nip
),
nip_top AS (                                    -- TOP_LEVEL glownego SOLDTO NIP-u
    SELECT s.NIP,
           MAX(COALESCE(ts.NATIONAL_LEADER_NUMBER, s.SOLDTO_NUMBER))
               KEEP (DENSE_RANK LAST ORDER BY s.SALES NULLS FIRST)           AS TOP_LEVEL
    FROM  (SELECT NIP, SOLDTO_NUMBER, SUM(SALES_AMOUNT) AS SALES
           FROM   linie
           WHERE  NIP IS NOT NULL
           GROUP  BY NIP, SOLDTO_NUMBER) s
    LEFT JOIN POLAND.T_SOLDTO ts
           ON  ts.SOLDTO_NUMBER = s.SOLDTO_NUMBER
           AND ts.COUNTRY_CODE  = 'PL'
    GROUP  BY s.NIP
),
db AS (
    SELECT REGEXP_REPLACE(d.NIP, '[^0-9]', '')                              AS NIP,
           MAX(d.ZATRUDNIENIE)                                              AS ZATR
    FROM   WORK_POLAND.DB_BAZA d
    WHERE  d.ZATRUDNIENIE IS NOT NULL
    GROUP  BY REGEXP_REPLACE(d.NIP, '[^0-9]', '')
),
kpp AS (
    SELECT LPAD(TO_CHAR(NIP), 10, '0')                                      AS NIP,
           MAX(REGEXP_SUBSTR(KOD_PKD, '^[0-9]{2}'))                         AS DZIAL_KPP
    FROM   WORK_POLAND.T_KATALOG_PODMIOTOW_PUBLICZNYCH
    WHERE  NIP IS NOT NULL AND KATEGORIA_PODMIOTU = 'PUBLIC' AND NVL(STATUS, 'ACTIVE') = 'ACTIVE'
    GROUP  BY LPAD(TO_CHAR(NIP), 10, '0')
),
f AS (                                          -- aktywni klienci (10-cyfrowy NIP, poza Public)
    SELECT n.NIP, n.SALES, t.TOP_LEVEL, db.ZATR,
           CASE WHEN db.ZATR IS NULL THEN NULL WHEN db.ZATR <= 40 THEN 1 WHEN db.ZATR <= 200 THEN 2 WHEN db.ZATR <= 500 THEN 3 WHEN db.ZATR <= 4000 THEN 4 ELSE 5 END AS PIETRO,
           CASE WHEN cg.NIP IS NULL THEN 'BRAK_W_CEIDG'
                WHEN cg.TYP_PODMIOTU = 'F' THEN 'OSOBA_FIZ'
                ELSE 'SPOLKA' END                                           AS TYP
    FROM   nip n
    JOIN   nip_top t ON t.NIP = n.NIP
    LEFT JOIN db  ON db.NIP  = n.NIP
    LEFT JOIN WORK_POLAND.T_CEIDG_GUS cg ON cg.NIP = n.NIP
    LEFT JOIN kpp ON kpp.NIP = n.NIP
    WHERE  LENGTH(n.NIP) = 10
      AND  CASE WHEN (kpp.NIP IS NOT NULL
                 OR REGEXP_LIKE(UPPER(cg.FORMA_WLASNOSCI), '^ *1[0-9]{2}|SKARBU PA.{1,2}STWA|PA.{1,2}STWOWYCH OS.{1,2}B PRAWNYCH|SAMORZ.{1,2}DU TERYTORIALNEGO|W SEKTORZE PUBLICZNYM|SEKTORAMI Z PRZEWAG.{1,2} W.{1,2}ASNO.{1,2}CI SEKTORA PUBLICZNEGO'))
                AND COALESCE(SUBSTR(REGEXP_REPLACE(cg.PKD_KOD, '[^0-9]', ''), 1, 2), kpp.DZIAL_KPP)
                    IN ('84','85','86','87','88','90','91','92','93')
                THEN 'T' ELSE 'N' END = 'N'     -- CASE, nie NOT(...): NULL nie moze wycinac wierszy
),
grp AS (                                        -- grupa TOP_LEVEL: ile NIP-ow, ile ze znanym zatrudnieniem
    SELECT TOP_LEVEL,
           COUNT(*)                                                         AS NIP_W_GRUPIE,
           COUNT(ZATR)                                                      AS NIP_Z_ZATR,
           MEDIAN(ZATR)                                                     AS MEDIANA_ZATR
    FROM   f
    GROUP  BY TOP_LEVEL
),
moda AS (                                       -- najczestsze pietro wsrod NIP-ow ze znanym zatrudnieniem
    SELECT TOP_LEVEL, PIETRO, UDZIAL
    FROM  (SELECT TOP_LEVEL, PIETRO,
                  CNT / SUM(CNT) OVER (PARTITION BY TOP_LEVEL)              AS UDZIAL,
                  ROW_NUMBER() OVER (PARTITION BY TOP_LEVEL ORDER BY CNT DESC, PIETRO) AS RN
           FROM  (SELECT TOP_LEVEL, PIETRO, COUNT(*) AS CNT
                  FROM   f
                  WHERE  ZATR IS NOT NULL
                  GROUP  BY TOP_LEVEL, PIETRO))
    WHERE  RN = 1
),
u AS (                                          -- NIEPRZYPISANI (bez zatrudnienia) z opisem ich grupy
    SELECT f.NIP, f.SALES, f.TYP, f.TOP_LEVEL,
           g.NIP_W_GRUPIE, g.NIP_Z_ZATR, g.MEDIANA_ZATR,
           m.PIETRO AS PIETRO_MODA, m.UDZIAL AS UDZIAL_MODY,
           CASE WHEN g.NIP_W_GRUPIE = 1                  THEN '1 SAM (grupa = 1 NIP)'
                WHEN g.NIP_Z_ZATR = 0                    THEN '2 GRUPA BEZ DANYCH'
                WHEN g.NIP_Z_ZATR >= 2 AND m.UDZIAL >= 0.7 THEN '3 GRUPA JEDNORODNA (>=70% w 1 pietrze)'
                ELSE                                          '4 GRUPA ROZNORODNA / 1 ZNANY' END AS KLASA
    FROM   f
    JOIN   grp g ON g.TOP_LEVEL = f.TOP_LEVEL
    LEFT JOIN moda m ON m.TOP_LEVEL = f.TOP_LEVEL
    WHERE  f.ZATR IS NULL
)
SELECT u.KLASA,
       u.TYP,
       COUNT(*)                                                         AS KLIENCI,
       ROUND(SUM(u.SALES) / MAX(t.SALES_ALL) * 100, 2)                  AS PCT_SPRZEDAZY,
       SUM(CASE WHEN u.PIETRO_MODA = 1 THEN 1 ELSE 0 END)               AS MODA_0_40,
       SUM(CASE WHEN u.PIETRO_MODA = 2 THEN 1 ELSE 0 END)               AS MODA_41_200,
       SUM(CASE WHEN u.PIETRO_MODA = 3 THEN 1 ELSE 0 END)               AS MODA_201_500,
       SUM(CASE WHEN u.PIETRO_MODA = 4 THEN 1 ELSE 0 END)               AS MODA_501_4000,
       SUM(CASE WHEN u.PIETRO_MODA = 5 THEN 1 ELSE 0 END)               AS MODA_4001
FROM   u
CROSS JOIN tot t
GROUP  BY u.KLASA, u.TYP
ORDER  BY u.KLASA, u.TYP;


-- === D24 Grupy TOP_LEVEL z najwieksza sprzedaza NIEPRZYPISANYCH (top 30)
-- Czy to grupy kapitalowe (spolki roznej wielkosci) czy sieci / konsorcja
-- (podobne, male firmy)? Nazwa lidera z T_ACCOUNT.
WITH linie AS (
    SELECT REGEXP_REPLACE(tp.TAX_NUMBER1, '[^0-9]', '')                     AS NIP,
           til.SOLDTO_NUMBER,
           til.SALES_AMOUNT
    FROM   POLAND.T_INVOICE_LINE til
    JOIN   POLAND.T_PAYER tp
           ON  tp.PAYER_NUMBER = til.PAYER_NUMBER
           AND tp.COUNTRY_CODE = til.COUNTRY_CODE
    WHERE  til.COUNTRY_CODE        = 'PL'
      AND  til.BUSINESS_SCOPE_FLAG = 'Y'
      AND  NVL(til.CANCELLED_FLAG, 'N')   <> 'Y'
      AND  NVL(til.DL_DELETION_FLAG, 'N') <> 'Y'
      AND  til.INVOICE_DATE >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -12)
      AND  til.INVOICE_DATE <  TRUNC(SYSDATE, 'MM')
),
nip AS (
    SELECT NIP, SUM(SALES_AMOUNT) AS SALES
    FROM   linie
    WHERE  NIP IS NOT NULL
    GROUP  BY NIP
    HAVING SUM(SALES_AMOUNT) > 0
),
tot AS (
    SELECT SUM(SALES) AS SALES_ALL FROM nip
),
nip_top AS (                                    -- TOP_LEVEL glownego SOLDTO NIP-u
    SELECT s.NIP,
           MAX(COALESCE(ts.NATIONAL_LEADER_NUMBER, s.SOLDTO_NUMBER))
               KEEP (DENSE_RANK LAST ORDER BY s.SALES NULLS FIRST)           AS TOP_LEVEL
    FROM  (SELECT NIP, SOLDTO_NUMBER, SUM(SALES_AMOUNT) AS SALES
           FROM   linie
           WHERE  NIP IS NOT NULL
           GROUP  BY NIP, SOLDTO_NUMBER) s
    LEFT JOIN POLAND.T_SOLDTO ts
           ON  ts.SOLDTO_NUMBER = s.SOLDTO_NUMBER
           AND ts.COUNTRY_CODE  = 'PL'
    GROUP  BY s.NIP
),
db AS (
    SELECT REGEXP_REPLACE(d.NIP, '[^0-9]', '')                              AS NIP,
           MAX(d.ZATRUDNIENIE)                                              AS ZATR
    FROM   WORK_POLAND.DB_BAZA d
    WHERE  d.ZATRUDNIENIE IS NOT NULL
    GROUP  BY REGEXP_REPLACE(d.NIP, '[^0-9]', '')
),
kpp AS (
    SELECT LPAD(TO_CHAR(NIP), 10, '0')                                      AS NIP,
           MAX(REGEXP_SUBSTR(KOD_PKD, '^[0-9]{2}'))                         AS DZIAL_KPP
    FROM   WORK_POLAND.T_KATALOG_PODMIOTOW_PUBLICZNYCH
    WHERE  NIP IS NOT NULL AND KATEGORIA_PODMIOTU = 'PUBLIC' AND NVL(STATUS, 'ACTIVE') = 'ACTIVE'
    GROUP  BY LPAD(TO_CHAR(NIP), 10, '0')
),
f AS (                                          -- aktywni klienci (10-cyfrowy NIP, poza Public)
    SELECT n.NIP, n.SALES, t.TOP_LEVEL, db.ZATR,
           CASE WHEN db.ZATR IS NULL THEN NULL WHEN db.ZATR <= 40 THEN 1 WHEN db.ZATR <= 200 THEN 2 WHEN db.ZATR <= 500 THEN 3 WHEN db.ZATR <= 4000 THEN 4 ELSE 5 END AS PIETRO,
           CASE WHEN cg.NIP IS NULL THEN 'BRAK_W_CEIDG'
                WHEN cg.TYP_PODMIOTU = 'F' THEN 'OSOBA_FIZ'
                ELSE 'SPOLKA' END                                           AS TYP
    FROM   nip n
    JOIN   nip_top t ON t.NIP = n.NIP
    LEFT JOIN db  ON db.NIP  = n.NIP
    LEFT JOIN WORK_POLAND.T_CEIDG_GUS cg ON cg.NIP = n.NIP
    LEFT JOIN kpp ON kpp.NIP = n.NIP
    WHERE  LENGTH(n.NIP) = 10
      AND  CASE WHEN (kpp.NIP IS NOT NULL
                 OR REGEXP_LIKE(UPPER(cg.FORMA_WLASNOSCI), '^ *1[0-9]{2}|SKARBU PA.{1,2}STWA|PA.{1,2}STWOWYCH OS.{1,2}B PRAWNYCH|SAMORZ.{1,2}DU TERYTORIALNEGO|W SEKTORZE PUBLICZNYM|SEKTORAMI Z PRZEWAG.{1,2} W.{1,2}ASNO.{1,2}CI SEKTORA PUBLICZNEGO'))
                AND COALESCE(SUBSTR(REGEXP_REPLACE(cg.PKD_KOD, '[^0-9]', ''), 1, 2), kpp.DZIAL_KPP)
                    IN ('84','85','86','87','88','90','91','92','93')
                THEN 'T' ELSE 'N' END = 'N'     -- CASE, nie NOT(...): NULL nie moze wycinac wierszy
),
grp AS (                                        -- grupa TOP_LEVEL: ile NIP-ow, ile ze znanym zatrudnieniem
    SELECT TOP_LEVEL,
           COUNT(*)                                                         AS NIP_W_GRUPIE,
           COUNT(ZATR)                                                      AS NIP_Z_ZATR,
           MEDIAN(ZATR)                                                     AS MEDIANA_ZATR
    FROM   f
    GROUP  BY TOP_LEVEL
),
moda AS (                                       -- najczestsze pietro wsrod NIP-ow ze znanym zatrudnieniem
    SELECT TOP_LEVEL, PIETRO, UDZIAL
    FROM  (SELECT TOP_LEVEL, PIETRO,
                  CNT / SUM(CNT) OVER (PARTITION BY TOP_LEVEL)              AS UDZIAL,
                  ROW_NUMBER() OVER (PARTITION BY TOP_LEVEL ORDER BY CNT DESC, PIETRO) AS RN
           FROM  (SELECT TOP_LEVEL, PIETRO, COUNT(*) AS CNT
                  FROM   f
                  WHERE  ZATR IS NOT NULL
                  GROUP  BY TOP_LEVEL, PIETRO))
    WHERE  RN = 1
),
u AS (                                          -- NIEPRZYPISANI (bez zatrudnienia) z opisem ich grupy
    SELECT f.NIP, f.SALES, f.TYP, f.TOP_LEVEL,
           g.NIP_W_GRUPIE, g.NIP_Z_ZATR, g.MEDIANA_ZATR,
           m.PIETRO AS PIETRO_MODA, m.UDZIAL AS UDZIAL_MODY,
           CASE WHEN g.NIP_W_GRUPIE = 1                  THEN '1 SAM (grupa = 1 NIP)'
                WHEN g.NIP_Z_ZATR = 0                    THEN '2 GRUPA BEZ DANYCH'
                WHEN g.NIP_Z_ZATR >= 2 AND m.UDZIAL >= 0.7 THEN '3 GRUPA JEDNORODNA (>=70% w 1 pietrze)'
                ELSE                                          '4 GRUPA ROZNORODNA / 1 ZNANY' END AS KLASA
    FROM   f
    JOIN   grp g ON g.TOP_LEVEL = f.TOP_LEVEL
    LEFT JOIN moda m ON m.TOP_LEVEL = f.TOP_LEVEL
    WHERE  f.ZATR IS NULL
)
SELECT u.TOP_LEVEL,
       SUBSTR(MAX(ta.NAME), 1, 50)                                      AS LIDER_GRUPY,
       MAX(u.NIP_W_GRUPIE)                                              AS NIP_W_GRUPIE,
       MAX(u.NIP_Z_ZATR)                                                AS NIP_Z_ZATR,
       COUNT(*)                                                         AS NIP_BEZ_ZATR,
       SUM(CASE WHEN u.TYP = 'BRAK_W_CEIDG' THEN 1 ELSE 0 END)          AS W_TYM_BRAK_W_CEIDG,
       MAX(u.MEDIANA_ZATR)                                              AS MEDIANA_ZATR_ZNANYCH,
       MAX(u.PIETRO_MODA)                                               AS PIETRO_MODA,
       ROUND(MAX(u.UDZIAL_MODY) * 100)                                  AS UDZIAL_MODY_PCT,
       ROUND(SUM(u.SALES) / MAX(t.SALES_ALL) * 100, 3)                  AS PCT_SPRZEDAZY_NIEPRZYP
FROM   u
CROSS JOIN tot t
LEFT JOIN POLAND.T_ACCOUNT ta
       ON  ta.ACCOUNT_NUMBER = u.TOP_LEVEL
       AND ta.COUNTRY_CODE   = 'PL'
WHERE  u.NIP_W_GRUPIE > 1
GROUP  BY u.TOP_LEVEL
ORDER  BY SUM(u.SALES) DESC
FETCH FIRST 30 ROWS ONLY;


-- =====================================================================
-- I. WALIDACJA: czy SEGMENT OBECNY zgadza sie z pietrem wg zatrudnienia?
-- Decyzja 2026-11-26: NIP-y samodzielne (bez grupy TOP_LEVEL) bez zatrudnienia
-- dostaja pietro z segmentu obecnego. Sprawdzamy to na klientach, KTORZY MAJA
-- zatrudnienie w DB_BAZA: jaki % z nich jest na pietrze zgodnym z segmentem.
-- Segment -> pietro: IS 0-40, PF 41-200, MM 201-500, Strategic 4001+,
-- pozostale CORPORATE 501-4000, SMB bez segmentu 0-40 (MATRYCA_ZATRUDNIENIA).
-- =====================================================================

-- === D25 Segment obecny x pietro wg DB_BAZA (klienci ze znanym zatrudnieniem, poza Public)
WITH linie AS (
    SELECT REGEXP_REPLACE(tp.TAX_NUMBER1, '[^0-9]', '')                     AS NIP,
           til.SOLDTO_NUMBER,
           til.SALES_AMOUNT
    FROM   POLAND.T_INVOICE_LINE til
    JOIN   POLAND.T_PAYER tp
           ON  tp.PAYER_NUMBER = til.PAYER_NUMBER
           AND tp.COUNTRY_CODE = til.COUNTRY_CODE
    WHERE  til.COUNTRY_CODE        = 'PL'
      AND  til.BUSINESS_SCOPE_FLAG = 'Y'
      AND  NVL(til.CANCELLED_FLAG, 'N')   <> 'Y'
      AND  NVL(til.DL_DELETION_FLAG, 'N') <> 'Y'
      AND  til.INVOICE_DATE >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -12)
      AND  til.INVOICE_DATE <  TRUNC(SYSDATE, 'MM')
),
soldto AS (
    SELECT NIP, SOLDTO_NUMBER, SUM(SALES_AMOUNT) AS SALES
    FROM   linie
    WHERE  NIP IS NOT NULL
    GROUP  BY NIP, SOLDTO_NUMBER
),
nip AS (
    SELECT NIP,
           SUM(SALES)                                                       AS SALES,
           MAX(SOLDTO_NUMBER) KEEP (DENSE_RANK LAST ORDER BY SALES NULLS FIRST) AS SOLDTO_GLOWNY
    FROM   soldto
    GROUP  BY NIP
    HAVING SUM(SALES) > 0
),
tot AS (
    SELECT SUM(SALES) AS SALES_ALL FROM nip
),
area_seg AS (
    SELECT AREA_CODE, MAX(SEGMENT) AS SEGMENT
    FROM   WORK_POLAND.T_KOD_POCZTOWY_OPIEKUN
    WHERE  SEGMENT IS NOT NULL
    GROUP  BY AREA_CODE
),
seg AS (
    SELECT n.NIP, n.SALES,
           COALESCE(ts.NATIONAL_LEADER_NUMBER, ts.SOLDTO_NUMBER)            AS TOP_LEVEL,
           CASE
               WHEN ts.SALES_FORCE_TYPE_CODE = 'CORPORATE' THEN
                   CASE WHEN UPPER(sfr.SALES_FORCE_REGION) LIKE '%STRATEG%'             THEN 'STRATEGIC'
                        WHEN UPPER(sfr.SALES_FORCE_REGION) LIKE '%K' || CHR(38) || 'N%' THEN 'K' || CHR(38) || 'N'
                        WHEN UPPER(sfr.SALES_FORCE_REGION) LIKE '%INTERNAT%'            THEN 'INTERNATIONAL'
                        WHEN UPPER(sfr.SALES_FORCE_REGION) LIKE '%PUBLI%'               THEN 'CA_PUBLIC'
                        ELSE                                                                 'CA_INNE' END
               WHEN ars.SEGMENT IN ('IS', 'PF', 'MM')       THEN ars.SEGMENT
               ELSE                                              'SMB_INNE'
           END                                                              AS SEGMENT_OBECNY
    FROM   nip n
    LEFT JOIN POLAND.T_SOLDTO ts
           ON  ts.SOLDTO_NUMBER = n.SOLDTO_GLOWNY
           AND ts.COUNTRY_CODE  = 'PL'
    LEFT JOIN SHARED.T_SALES_FORCE_REGION sfr
           ON  sfr.SALES_FORCE_REGION_CODE = ts.SALES_FORCE_REGION_CODE
           AND sfr.COUNTRY_CODE            = 'PL'
           AND sfr.LANGUAGE_CODE           = 'POLISH'
    LEFT JOIN area_seg ars
           ON  ars.AREA_CODE = ts.AREA_CODE
),
grp AS (
    SELECT TOP_LEVEL, COUNT(*) AS NIP_W_GRUPIE FROM seg GROUP BY TOP_LEVEL
),
db AS (
    SELECT REGEXP_REPLACE(d.NIP, '[^0-9]', '')                              AS NIP,
           MAX(d.ZATRUDNIENIE)                                              AS ZATR
    FROM   WORK_POLAND.DB_BAZA d
    WHERE  d.ZATRUDNIENIE IS NOT NULL
    GROUP  BY REGEXP_REPLACE(d.NIP, '[^0-9]', '')
),
kpp AS (
    SELECT LPAD(TO_CHAR(NIP), 10, '0')                                      AS NIP,
           MAX(REGEXP_SUBSTR(KOD_PKD, '^[0-9]{2}'))                         AS DZIAL_KPP
    FROM   WORK_POLAND.T_KATALOG_PODMIOTOW_PUBLICZNYCH
    WHERE  NIP IS NOT NULL AND KATEGORIA_PODMIOTU = 'PUBLIC' AND NVL(STATUS, 'ACTIVE') = 'ACTIVE'
    GROUP  BY LPAD(TO_CHAR(NIP), 10, '0')
),
f AS (
    SELECT s.SEGMENT_OBECNY, s.SALES,
           CASE WHEN g.NIP_W_GRUPIE = 1 THEN '1 SAM' ELSE '2 W_GRUPIE' END  AS RODZAJ,
           CASE WHEN db.ZATR <= 40 THEN 1 WHEN db.ZATR <= 200 THEN 2 WHEN db.ZATR <= 500 THEN 3 WHEN db.ZATR <= 4000 THEN 4 ELSE 5 END AS PIETRO_DB,
           CASE s.SEGMENT_OBECNY WHEN 'IS' THEN 1 WHEN 'PF' THEN 2 WHEN 'MM' THEN 3
                                 WHEN 'STRATEGIC' THEN 5 WHEN 'SMB_INNE' THEN 1 ELSE 4 END AS PIETRO_SEGMENT,
           CASE WHEN (kpp.NIP IS NOT NULL
                      OR REGEXP_LIKE(UPPER(cg.FORMA_WLASNOSCI), '^ *1[0-9]{2}|SKARBU PA.{1,2}STWA|PA.{1,2}STWOWYCH OS.{1,2}B PRAWNYCH|SAMORZ.{1,2}DU TERYTORIALNEGO|W SEKTORZE PUBLICZNYM|SEKTORAMI Z PRZEWAG.{1,2} W.{1,2}ASNO.{1,2}CI SEKTORA PUBLICZNEGO'))
                 AND COALESCE(SUBSTR(REGEXP_REPLACE(cg.PKD_KOD, '[^0-9]', ''), 1, 2), kpp.DZIAL_KPP)
                     IN ('84','85','86','87','88','90','91','92','93')
                THEN 'T' ELSE 'N' END                                       AS FLAGA_PUBLIC
    FROM   seg s
    JOIN   grp g ON g.TOP_LEVEL = s.TOP_LEVEL
    JOIN   db  ON db.NIP = s.NIP
    LEFT JOIN WORK_POLAND.T_CEIDG_GUS cg ON cg.NIP = s.NIP
    LEFT JOIN kpp ON kpp.NIP = s.NIP
)
SELECT f.RODZAJ,
       f.SEGMENT_OBECNY,
       COUNT(*)                                                         AS KLIENCI_ZE_ZNANYM_ZATR,
       ROUND(SUM(CASE WHEN f.PIETRO_DB = f.PIETRO_SEGMENT THEN 1 ELSE 0 END) / COUNT(*) * 100, 1)
                                                                        AS ZGODNE_PCT,
       ROUND(SUM(CASE WHEN ABS(f.PIETRO_DB - f.PIETRO_SEGMENT) <= 1 THEN 1 ELSE 0 END) / COUNT(*) * 100, 1)
                                                                        AS ZGODNE_LUB_SASIEDNIE_PCT,
       SUM(CASE WHEN f.PIETRO_DB = 1 THEN 1 ELSE 0 END)                 AS DB_0_40,
       SUM(CASE WHEN f.PIETRO_DB = 2 THEN 1 ELSE 0 END)                 AS DB_41_200,
       SUM(CASE WHEN f.PIETRO_DB = 3 THEN 1 ELSE 0 END)                 AS DB_201_500,
       SUM(CASE WHEN f.PIETRO_DB = 4 THEN 1 ELSE 0 END)                 AS DB_501_4000,
       SUM(CASE WHEN f.PIETRO_DB = 5 THEN 1 ELSE 0 END)                 AS DB_4001,
       ROUND(SUM(f.SALES) / MAX(t.SALES_ALL) * 100, 2)                  AS PCT_SPRZEDAZY
FROM   f
CROSS JOIN tot t
WHERE  f.FLAGA_PUBLIC = 'N'
GROUP  BY f.RODZAJ, f.SEGMENT_OBECNY
ORDER  BY f.RODZAJ, DECODE(f.SEGMENT_OBECNY, 'IS', 1, 'PF', 2, 'MM', 3, 'SMB_INNE', 4,
                           'STRATEGIC', 6, 7), f.SEGMENT_OBECNY;


-- =====================================================================
-- J. SLAJD "GUS x BIZNES LINIE" W STANDARDOWYCH KLASACH GUS (2026-11-26)
-- Klasy GUS bez zmian: 0-9 / 10-49 / 50-249 / 250-999 / 1000+ (+ Public,
-- + bez zatrudnienia). Dwie miary:
--   PORTFOLIO = klienci w kartotece: NIP platnika z co najmniej jednym
--               nieusunietym SOLDTO (T_SOLDTO) albo z zakupami w 12 mies.
--   AKTYWNE   = NIP z dodatnia sprzedaza netto w ostatnich 12 zamknietych mies.
-- Biznes linia = region sprzedazy glownego SOLDTO (najwieksza sprzedaz 12 mies.,
-- bez sprzedazy - najwyzszy numer SOLDTO): IS, FS, Mid Market, Other SMB,
-- K&N, Strategic, International, Public, Other CA, Quarantine.
-- Klasa = zatrudnienie z DB_BAZA; Public = flaga wariantu B (pierwsza).
-- =====================================================================

-- === D26 Portfolio i aktywni: klasa GUS x biznes linia (liczba NIP)
WITH linie AS (
    SELECT REGEXP_REPLACE(tp.TAX_NUMBER1, '[^0-9]', '')                     AS NIP,
           til.SOLDTO_NUMBER,
           til.SALES_AMOUNT
    FROM   POLAND.T_INVOICE_LINE til
    JOIN   POLAND.T_PAYER tp
           ON  tp.PAYER_NUMBER = til.PAYER_NUMBER
           AND tp.COUNTRY_CODE = til.COUNTRY_CODE
    WHERE  til.COUNTRY_CODE        = 'PL'
      AND  til.BUSINESS_SCOPE_FLAG = 'Y'
      AND  NVL(til.CANCELLED_FLAG, 'N')   <> 'Y'
      AND  NVL(til.DL_DELETION_FLAG, 'N') <> 'Y'
      AND  til.INVOICE_DATE >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -12)
      AND  til.INVOICE_DATE <  TRUNC(SYSDATE, 'MM')
),
sprz AS (
    SELECT NIP, SOLDTO_NUMBER, SUM(SALES_AMOUNT) AS SALES
    FROM   linie
    WHERE  NIP IS NOT NULL
    GROUP  BY NIP, SOLDTO_NUMBER
),
aktywni AS (
    SELECT NIP, SUM(SALES) AS SALES
    FROM   sprz
    GROUP  BY NIP
    HAVING SUM(SALES) > 0
),
tot AS (
    SELECT SUM(SALES) AS SALES_ALL FROM aktywni
),
kartoteka AS (                                  -- nieusuniete SOLDTO z NIP-em platnika
    SELECT REGEXP_REPLACE(tp.TAX_NUMBER1, '[^0-9]', '')                     AS NIP,
           ts.SOLDTO_NUMBER
    FROM   POLAND.T_SOLDTO ts
    JOIN   POLAND.T_PAYER tp
           ON  tp.PAYER_NUMBER = ts.PAYER_NUMBER
           AND tp.COUNTRY_CODE = ts.COUNTRY_CODE
    WHERE  ts.COUNTRY_CODE = 'PL'
      AND  NVL(ts.DL_DELETION_FLAG, 'N') <> 'Y'
),
soldto_all AS (                                 -- SOLDTO NIP-u z kartoteki i z faktur (sprzedaz 0 gdy brak)
    SELECT NIP, SOLDTO_NUMBER, SUM(SALES) AS SALES
    FROM  (SELECT NIP, SOLDTO_NUMBER, SALES FROM sprz
           UNION ALL
           SELECT NIP, SOLDTO_NUMBER, 0 FROM kartoteka)
    WHERE  LENGTH(NIP) = 10
    GROUP  BY NIP, SOLDTO_NUMBER
),
glowny AS (
    SELECT NIP,
           MAX(SOLDTO_NUMBER) KEEP (DENSE_RANK LAST ORDER BY SALES NULLS FIRST, SOLDTO_NUMBER) AS SOLDTO_GLOWNY
    FROM   soldto_all
    GROUP  BY NIP
),
linia AS (
    SELECT g.NIP,
           CASE
               WHEN UPPER(sfr.SALES_FORCE_REGION) LIKE 'IS %'
                 OR UPPER(sfr.SALES_FORCE_REGION) = 'IS'              THEN 'IS'
               WHEN UPPER(sfr.SALES_FORCE_REGION) LIKE 'FS %'
                 OR UPPER(sfr.SALES_FORCE_REGION) = 'FS'              THEN 'FS'
               WHEN UPPER(sfr.SALES_FORCE_REGION) LIKE '%MID MARKET%'   THEN 'MM'
               WHEN UPPER(sfr.SALES_FORCE_REGION) LIKE '%QUARANT%'      THEN 'KWARANTANNA'
               WHEN UPPER(sfr.SALES_FORCE_REGION) LIKE '%OTHER SMB%'    THEN 'INNE_SMB'
               WHEN UPPER(sfr.SALES_FORCE_REGION) LIKE '%K' || CHR(38) || 'N%' THEN 'KN'
               WHEN UPPER(sfr.SALES_FORCE_REGION) LIKE '%STRATEG%'      THEN 'STRATEGIC'
               WHEN UPPER(sfr.SALES_FORCE_REGION) LIKE '%INTERNAT%'     THEN 'INTERNATIONAL'
               WHEN UPPER(sfr.SALES_FORCE_REGION) LIKE '%PUBLI%'        THEN 'PUBLIC'
               WHEN UPPER(sfr.SALES_FORCE_REGION) LIKE '%OTHER CA%'     THEN 'INNE_CA'
               ELSE                                                          'BRAK'
           END                                                              AS LINIA
    FROM   glowny g
    LEFT JOIN POLAND.T_SOLDTO ts
           ON  ts.SOLDTO_NUMBER = g.SOLDTO_GLOWNY
           AND ts.COUNTRY_CODE  = 'PL'
    LEFT JOIN SHARED.T_SALES_FORCE_REGION sfr
           ON  sfr.SALES_FORCE_REGION_CODE = ts.SALES_FORCE_REGION_CODE
           AND sfr.COUNTRY_CODE            = 'PL'
           AND sfr.LANGUAGE_CODE           = 'POLISH'
),
db AS (
    SELECT REGEXP_REPLACE(d.NIP, '[^0-9]', '')                              AS NIP,
           MAX(d.ZATRUDNIENIE)                                              AS ZATR
    FROM   WORK_POLAND.DB_BAZA d
    WHERE  d.ZATRUDNIENIE IS NOT NULL
    GROUP  BY REGEXP_REPLACE(d.NIP, '[^0-9]', '')
),
kpp AS (
    SELECT LPAD(TO_CHAR(NIP), 10, '0')                                      AS NIP,
           MAX(REGEXP_SUBSTR(KOD_PKD, '^[0-9]{2}'))                         AS DZIAL_KPP
    FROM   WORK_POLAND.T_KATALOG_PODMIOTOW_PUBLICZNYCH
    WHERE  NIP IS NOT NULL AND KATEGORIA_PODMIOTU = 'PUBLIC' AND NVL(STATUS, 'ACTIVE') = 'ACTIVE'
    GROUP  BY LPAD(TO_CHAR(NIP), 10, '0')
),
f AS (
    SELECT l.NIP, l.LINIA,
           CASE WHEN a.NIP IS NOT NULL THEN 1 ELSE 0 END                    AS AKTYWNY,
           NVL(a.SALES, 0)                                                  AS SALES,
           CASE
               WHEN (kpp.NIP IS NOT NULL
                     OR REGEXP_LIKE(UPPER(cg.FORMA_WLASNOSCI), '^ *1[0-9]{2}|SKARBU PA.{1,2}STWA|PA.{1,2}STWOWYCH OS.{1,2}B PRAWNYCH|SAMORZ.{1,2}DU TERYTORIALNEGO|W SEKTORZE PUBLICZNYM|SEKTORAMI Z PRZEWAG.{1,2} W.{1,2}ASNO.{1,2}CI SEKTORA PUBLICZNEGO'))
                AND COALESCE(SUBSTR(REGEXP_REPLACE(cg.PKD_KOD, '[^0-9]', ''), 1, 2), kpp.DZIAL_KPP)
                    IN ('84','85','86','87','88','90','91','92','93')       THEN '6 PUBLIC'
               WHEN db.ZATR IS NULL                                         THEN '7 BRAK ZATRUDNIENIA'
               WHEN db.ZATR < 10                                            THEN '1 0-9'
               WHEN db.ZATR < 50                                            THEN '2 10-49'
               WHEN db.ZATR < 250                                           THEN '3 50-249'
               WHEN db.ZATR < 1000                                          THEN '4 250-999'
               ELSE                                                              '5 1000+'
           END                                                              AS KLASA
    FROM   linia l
    LEFT JOIN aktywni a ON a.NIP = l.NIP
    LEFT JOIN db  ON db.NIP  = l.NIP
    LEFT JOIN WORK_POLAND.T_CEIDG_GUS cg ON cg.NIP = l.NIP
    LEFT JOIN kpp ON kpp.NIP = l.NIP
),
m AS (
    SELECT f.*, '1 PORTFOLIO' AS MIARA FROM f
    UNION ALL
    SELECT f.*, '2 AKTYWNE'   AS MIARA FROM f WHERE f.AKTYWNY = 1
)
SELECT m.KLASA,
       m.MIARA,
       SUM(CASE WHEN LINIA = 'IS' THEN 1 ELSE 0 END)                                            AS LN_IS,
       SUM(CASE WHEN LINIA = 'FS' THEN 1 ELSE 0 END)                                            AS LN_FS,
       SUM(CASE WHEN LINIA = 'MM' THEN 1 ELSE 0 END)                                            AS LN_MM,
       SUM(CASE WHEN LINIA = 'INNE_SMB' THEN 1 ELSE 0 END)                                      AS LN_INNE_SMB,
       SUM(CASE WHEN LINIA = 'KN' THEN 1 ELSE 0 END)                                            AS LN_KN,
       SUM(CASE WHEN LINIA = 'STRATEGIC' THEN 1 ELSE 0 END)                                     AS LN_STRATEGIC,
       SUM(CASE WHEN LINIA = 'INTERNATIONAL' THEN 1 ELSE 0 END)                                 AS LN_INTERNATIONAL,
       SUM(CASE WHEN LINIA = 'PUBLIC' THEN 1 ELSE 0 END)                                        AS LN_PUBLIC,
       SUM(CASE WHEN LINIA = 'INNE_CA' THEN 1 ELSE 0 END)                                       AS LN_INNE_CA,
       SUM(CASE WHEN LINIA = 'KWARANTANNA' THEN 1 ELSE 0 END)                                   AS LN_KWARANTANNA,
       SUM(CASE WHEN LINIA = 'BRAK' THEN 1 ELSE 0 END)                                          AS LN_BRAK,
       COUNT(*)                                                         AS RAZEM,
       ROUND(SUM(m.SALES) / MAX(t.SALES_ALL) * 100, 1)                  AS PCT_SPRZEDAZY
FROM   m
CROSS JOIN tot t
GROUP  BY m.KLASA, m.MIARA
ORDER  BY m.KLASA, m.MIARA;


-- =====================================================================
-- K. NIP-y z T_CEIDG_GUS a kartoteka SAP (2026-11-26)
-- T_CEIDG_GUS ma ok. 526 tys. NIP-ow, portfolio SAP ok. 302 tys. (z Kwarantanna).
-- Ktore NIP-y z T_CEIDG_GUS sa w SAP, a ktore nie (kandydaci na
-- "niezarejestrowanych")? Podzial wg statusu w rejestrze i klasy GUS.
--   1 PORTFOLIO          - nieusuniety SOLDTO poza Kwarantanna
--   2 KWARANTANNA        - nieusuniety SOLDTO tylko w regionach Quarantine
--   3 W SAP, BEZ KONTA   - platnik jest w T_PAYER, ale wszystkie SOLDTO usuniete
--                          (byly klient) albo brak SOLDTO
--   4 BRAK W SAP         - NIP-u nie ma w T_PAYER
-- =====================================================================

-- === D27 T_CEIDG_GUS wg obecnosci w SAP x status rejestru x klasa GUS
WITH sap AS (
    SELECT REGEXP_REPLACE(tp.TAX_NUMBER1, '[^0-9]', '')                     AS NIP,
           MAX(CASE
                   WHEN ts.SOLDTO_NUMBER IS NOT NULL
                    AND NVL(ts.DL_DELETION_FLAG, 'N') <> 'Y'
                    AND NVL(UPPER(sfr.SALES_FORCE_REGION), '-') NOT LIKE '%QUARANT%' THEN 3
                   WHEN ts.SOLDTO_NUMBER IS NOT NULL
                    AND NVL(ts.DL_DELETION_FLAG, 'N') <> 'Y'                         THEN 2
                   ELSE                                                                   1
               END)                                                         AS POZIOM
    FROM   POLAND.T_PAYER tp
    LEFT JOIN POLAND.T_SOLDTO ts
           ON  ts.PAYER_NUMBER = tp.PAYER_NUMBER
           AND ts.COUNTRY_CODE = tp.COUNTRY_CODE
    LEFT JOIN SHARED.T_SALES_FORCE_REGION sfr
           ON  sfr.SALES_FORCE_REGION_CODE = ts.SALES_FORCE_REGION_CODE
           AND sfr.COUNTRY_CODE            = 'PL'
           AND sfr.LANGUAGE_CODE           = 'POLISH'
    WHERE  tp.COUNTRY_CODE = 'PL'
      AND  LENGTH(REGEXP_REPLACE(tp.TAX_NUMBER1, '[^0-9]', '')) = 10
    GROUP  BY REGEXP_REPLACE(tp.TAX_NUMBER1, '[^0-9]', '')
),
db AS (
    SELECT REGEXP_REPLACE(d.NIP, '[^0-9]', '')                              AS NIP,
           MAX(d.ZATRUDNIENIE)                                              AS ZATR
    FROM   WORK_POLAND.DB_BAZA d
    WHERE  d.ZATRUDNIENIE IS NOT NULL
    GROUP  BY REGEXP_REPLACE(d.NIP, '[^0-9]', '')
),
f AS (
    SELECT CASE s.POZIOM WHEN 3 THEN '1 PORTFOLIO' WHEN 2 THEN '2 KWARANTANNA'
                         WHEN 1 THEN '3 W SAP, BEZ KONTA' ELSE '4 BRAK W SAP' END AS SAP,
           CASE WHEN NVL(cg.DELETION_FLAG, 'N') = 'Y' OR cg.DATA_SKRESLENIA IS NOT NULL
                  OR cg.DATA_ZAKONCZENIA IS NOT NULL                          THEN '3 ZAKONCZONA'
                WHEN cg.DATA_ZAWIESZENIA IS NOT NULL
                 AND (cg.DATA_WZNAWIENIA IS NULL OR cg.DATA_WZNAWIENIA < cg.DATA_ZAWIESZENIA)
                                                                              THEN '2 ZAWIESZONA'
                ELSE                                                               '1 AKTYWNA' END AS STATUS,
           db.ZATR,
           cg.TYP_PODMIOTU
    FROM   WORK_POLAND.T_CEIDG_GUS cg
    LEFT JOIN sap s ON s.NIP = cg.NIP
    LEFT JOIN db    ON db.NIP = cg.NIP
)
SELECT SAP, STATUS,
       COUNT(*)                                                         AS NIP_CEIDG,
       SUM(CASE WHEN TYP_PODMIOTU = 'F' THEN 1 ELSE 0 END)              AS W_TYM_OS_FIZ,
       SUM(CASE WHEN ZATR < 10 THEN 1 ELSE 0 END)                       AS KL_0_9,
       SUM(CASE WHEN ZATR >= 10  AND ZATR < 50   THEN 1 ELSE 0 END)     AS KL_10_49,
       SUM(CASE WHEN ZATR >= 50  AND ZATR < 250  THEN 1 ELSE 0 END)     AS KL_50_249,
       SUM(CASE WHEN ZATR >= 250 AND ZATR < 1000 THEN 1 ELSE 0 END)     AS KL_250_999,
       SUM(CASE WHEN ZATR >= 1000 THEN 1 ELSE 0 END)                    AS KL_1000,
       SUM(CASE WHEN ZATR IS NULL THEN 1 ELSE 0 END)                    AS BRAK_KLASY
FROM   f
GROUP  BY SAP, STATUS
ORDER  BY SAP, STATUS;
