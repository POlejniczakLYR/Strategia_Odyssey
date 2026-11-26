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
