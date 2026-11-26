SET DEFINE OFF;
-- =====================================================================
-- 06_piramida.sql
-- Piramida klientow / Strategia Odyssey
--
-- WORK_POLAND.T_ODY_PIRAMIDA - wynik: na kazdym pietrze
--   rynek (GUS):  firmy, pracujacy
--   Lyreco:       firmy (NIP z zakupami LTM), pracujacy u nich (DB_BAZA),
--                 sprzedaz i marza LTM
--   wskazniki:    penetracja firm, pokrycie pracujacych, udzial w sprzedazy
--
-- Rynek, pietra 1-5: klasy GUS x proporcje z 05 (T_ODY_PROPORCJE)
--   FIRMY_RYNEK       = przedsiebiorstwa aktywne GUS (glowna liczba)
--   FIRMY_RYNEK_REGON = podmioty REGON (kontrola; w klasie 0-9 ok. 2x wiecej,
--                       bo REGON liczy tez firmy niedzialajace)
--   PRACUJACY_RYNEK   = pracujacy GUS (bez rolnikow indywidualnych)
-- Rynek, PUBLIC (jeden blok, wariant B): podmioty REGON i pracujacy GUS
--   (przedsiebiorstwa aktywne nie obejmuja jednostek budzetowych).
--   Uwaga: GUS liczy podmioty (np. kazda szkole), my liczymy NIP-y - szkoly
--   placace przez NIP gminy / CUW to u nas jeden NIP. Penetracja Public
--   w liczbie firm jest wiec zanizona; lepsza miara: pokrycie pracujacych.
-- NIEPRZYPISANE: nasi klienci bez zatrudnienia w DB_BAZA (bez rynku).
--
-- Wymaga: 01, 02, 03, 05.
-- Odswiezenie: TRUNCATE + ponowny INSERT (krok 2).
-- =====================================================================


-- ---------------------------------------------------------------------
-- KROK 1. Tabela (jednorazowo)
-- ---------------------------------------------------------------------
CALL WORK_POLAND.WORK_SCHEMA_CREATE_TABLE ('T_ODY_PIRAMIDA',
    'PIETRO_NR            NUMBER(2)      NOT NULL,
     PIETRO               VARCHAR2(20)   NOT NULL,
     FIRMY_RYNEK          NUMBER,
     FIRMY_RYNEK_REGON    NUMBER,
     PRACUJACY_RYNEK      NUMBER,
     FIRMY_LYRECO         NUMBER,
     FIRMY_LYRECO_Z_ZATR  NUMBER,
     PRACUJACY_LYRECO     NUMBER,
     SALES_LTM            NUMBER,
     MARGIN_LTM           NUMBER,
     PENETRACJA_FIRM_PCT  NUMBER,
     POKRYCIE_PRAC_PCT    NUMBER,
     UDZIAL_SALES_PCT     NUMBER,
     DATA_WCZYTANIA       DATE           DEFAULT SYSDATE');


-- ---------------------------------------------------------------------
-- KROK 2. Zasilenie
-- ---------------------------------------------------------------------
-- TRUNCATE TABLE WORK_POLAND.T_ODY_PIRAMIDA;

INSERT INTO WORK_POLAND.T_ODY_PIRAMIDA
    (PIETRO_NR, PIETRO, FIRMY_RYNEK, FIRMY_RYNEK_REGON, PRACUJACY_RYNEK,
     FIRMY_LYRECO, FIRMY_LYRECO_Z_ZATR, PRACUJACY_LYRECO, SALES_LTM, MARGIN_LTM,
     PENETRACJA_FIRM_PCT, POKRYCIE_PRAC_PCT, UDZIAL_SALES_PCT)
WITH rynek_klasy AS (
    SELECT MIARA, GRUPA, KLASA_GUS, SUM(WARTOSC) AS WARTOSC
    FROM   WORK_POLAND.T_ODY_RYNEK_GUS
    GROUP  BY MIARA, GRUPA, KLASA_GUS
),
rynek_pietra AS (
    -- pietra 1-5: klasa GUS x proporcja z DB_BAZA
    SELECT pr.PIETRO_NR,
           SUM(CASE WHEN r.MIARA = 'FIRMY_AKTYWNE' THEN r.WARTOSC * pr.W_FIRMY END) AS FIRMY_RYNEK,
           SUM(CASE WHEN r.MIARA = 'FIRMY_REGON'   THEN r.WARTOSC * pr.W_FIRMY END) AS FIRMY_RYNEK_REGON,
           SUM(CASE WHEN r.MIARA = 'PRACUJACY'     THEN r.WARTOSC * pr.W_PRAC  END) AS PRACUJACY_RYNEK
    FROM   rynek_klasy r
    JOIN   WORK_POLAND.T_ODY_PROPORCJE pr
           ON pr.KLASA_GUS = r.KLASA_GUS
    WHERE  r.GRUPA = 'POZA_PUBLIC'
    GROUP  BY pr.PIETRO_NR
    UNION ALL
    -- Public: jeden blok, wprost z GUS
    SELECT 6,
           SUM(CASE WHEN MIARA = 'FIRMY_REGON' THEN WARTOSC END),
           SUM(CASE WHEN MIARA = 'FIRMY_REGON' THEN WARTOSC END),
           SUM(CASE WHEN MIARA = 'PRACUJACY'   THEN WARTOSC END)
    FROM   rynek_klasy
    WHERE  GRUPA = 'PUBLIC'
),
lyreco AS (
    SELECT NVL(p.PIETRO_NR, 99)                                         AS PIETRO_NR,
           COUNT(*)                                                     AS FIRMY_LYRECO,
           COUNT(p.ZATRUDNIENIE)                                        AS FIRMY_LYRECO_Z_ZATR,
           SUM(p.ZATRUDNIENIE)                                          AS PRACUJACY_LYRECO,
           SUM(k.SALES_LTM)                                             AS SALES_LTM,
           SUM(k.MARGIN_LTM)                                            AS MARGIN_LTM
    FROM   WORK_POLAND.T_ODY_KLIENT_LTM k
    LEFT JOIN WORK_POLAND.T_ODY_FIRMA_PROFIL p
           ON p.NIP = k.NIP
    GROUP  BY NVL(p.PIETRO_NR, 99)
)
SELECT pg.PIETRO_NR,
       pg.PIETRO,
       ROUND(r.FIRMY_RYNEK),
       ROUND(r.FIRMY_RYNEK_REGON),
       ROUND(r.PRACUJACY_RYNEK),
       NVL(l.FIRMY_LYRECO, 0),
       NVL(l.FIRMY_LYRECO_Z_ZATR, 0),
       l.PRACUJACY_LYRECO,
       l.SALES_LTM,
       l.MARGIN_LTM,
       ROUND(l.FIRMY_LYRECO     / NULLIF(r.FIRMY_RYNEK, 0)     * 100, 2) AS PENETRACJA_FIRM_PCT,
       ROUND(l.PRACUJACY_LYRECO / NULLIF(r.PRACUJACY_RYNEK, 0) * 100, 2) AS POKRYCIE_PRAC_PCT,
       ROUND(RATIO_TO_REPORT(l.SALES_LTM) OVER () * 100, 1)              AS UDZIAL_SALES_PCT
FROM   WORK_POLAND.T_ODY_PIRAMIDA_PROGI pg
LEFT JOIN rynek_pietra r ON r.PIETRO_NR = pg.PIETRO_NR
LEFT JOIN lyreco       l ON l.PIETRO_NR = pg.PIETRO_NR;

COMMIT;


-- ---------------------------------------------------------------------
-- WYNIK: piramida
-- ---------------------------------------------------------------------
SELECT PIETRO_NR, PIETRO,
       FIRMY_RYNEK, FIRMY_LYRECO, PENETRACJA_FIRM_PCT,
       PRACUJACY_RYNEK, PRACUJACY_LYRECO, POKRYCIE_PRAC_PCT,
       ROUND(SALES_LTM) AS SALES_LTM, UDZIAL_SALES_PCT,
       FIRMY_RYNEK_REGON, FIRMY_LYRECO_Z_ZATR
FROM   WORK_POLAND.T_ODY_PIRAMIDA
ORDER  BY PIETRO_NR;


-- ---------------------------------------------------------------------
-- KONTROLA 1: suma pieter 1-5 = suma GUS poza Public (dla kazdej miary).
-- Roznica != 0 oznacza klase GUS bez proporcji w T_ODY_PROPORCJE.
-- ---------------------------------------------------------------------
WITH gus AS (
    SELECT MIARA, SUM(WARTOSC) AS GUS
    FROM   WORK_POLAND.T_ODY_RYNEK_GUS
    WHERE  GRUPA = 'POZA_PUBLIC'
    GROUP  BY MIARA
),
pietra AS (
    SELECT 'FIRMY_AKTYWNE' AS MIARA, SUM(FIRMY_RYNEK)       AS PIETRA FROM WORK_POLAND.T_ODY_PIRAMIDA WHERE PIETRO_NR BETWEEN 1 AND 5
    UNION ALL
    SELECT 'FIRMY_REGON',            SUM(FIRMY_RYNEK_REGON)           FROM WORK_POLAND.T_ODY_PIRAMIDA WHERE PIETRO_NR BETWEEN 1 AND 5
    UNION ALL
    SELECT 'PRACUJACY',              SUM(PRACUJACY_RYNEK)             FROM WORK_POLAND.T_ODY_PIRAMIDA WHERE PIETRO_NR BETWEEN 1 AND 5
)
SELECT g.MIARA, g.GUS, p.PIETRA, p.PIETRA - g.GUS AS ROZNICA
FROM   gus g
JOIN   pietra p ON p.MIARA = g.MIARA
ORDER  BY g.MIARA;


-- ---------------------------------------------------------------------
-- KONTROLA 2: nasi klienci nie moga przekraczac rynku w pietrze.
-- Przekroczenie = zle zatrudnienie w DB_BAZA (wrocic do 04) albo
-- za malo firm w GUS dla danego pietra.
-- ---------------------------------------------------------------------
SELECT PIETRO_NR, PIETRO, FIRMY_RYNEK, FIRMY_LYRECO, PRACUJACY_RYNEK, PRACUJACY_LYRECO,
       CASE WHEN FIRMY_LYRECO     > FIRMY_RYNEK     THEN 'FIRMY > RYNEK'     END AS UWAGA_FIRMY,
       CASE WHEN PRACUJACY_LYRECO > PRACUJACY_RYNEK THEN 'PRACUJACY > RYNEK' END AS UWAGA_PRACUJACY
FROM   WORK_POLAND.T_ODY_PIRAMIDA
WHERE  PIETRO_NR BETWEEN 1 AND 6
ORDER  BY PIETRO_NR;


-- ---------------------------------------------------------------------
-- PODWARSTWA pietra 0-40: mikrofirmy 0-9 i firmy 10-40
-- (0-9 w calosci z GUS, 10-40 = czesc klasy 10-49 wg proporcji)
-- ---------------------------------------------------------------------
WITH r AS (
    SELECT MIARA, KLASA_GUS, SUM(WARTOSC) AS WARTOSC
    FROM   WORK_POLAND.T_ODY_RYNEK_GUS
    WHERE  GRUPA = 'POZA_PUBLIC'
      AND  KLASA_GUS IN ('0-9', '10-49')
    GROUP  BY MIARA, KLASA_GUS
),
rp AS (
    SELECT CASE r.KLASA_GUS WHEN '0-9' THEN '1a: 0-9' ELSE '1b: 10-40' END AS PODWARSTWA,
           ROUND(SUM(CASE WHEN r.MIARA = 'FIRMY_AKTYWNE' THEN r.WARTOSC * pr.W_FIRMY END)) AS FIRMY_RYNEK,
           ROUND(SUM(CASE WHEN r.MIARA = 'FIRMY_REGON'   THEN r.WARTOSC * pr.W_FIRMY END)) AS FIRMY_RYNEK_REGON,
           ROUND(SUM(CASE WHEN r.MIARA = 'PRACUJACY'     THEN r.WARTOSC * pr.W_PRAC  END)) AS PRACUJACY_RYNEK
    FROM   r
    JOIN   WORK_POLAND.T_ODY_PROPORCJE pr
           ON  pr.KLASA_GUS = r.KLASA_GUS
           AND pr.PIETRO_NR = 1
    GROUP  BY CASE r.KLASA_GUS WHEN '0-9' THEN '1a: 0-9' ELSE '1b: 10-40' END
),
l AS (
    SELECT CASE WHEN p.ZATRUDNIENIE <= 9 THEN '1a: 0-9' ELSE '1b: 10-40' END AS PODWARSTWA,
           COUNT(*)                AS FIRMY_LYRECO,
           SUM(p.ZATRUDNIENIE)     AS PRACUJACY_LYRECO,
           ROUND(SUM(k.SALES_LTM)) AS SALES_LTM
    FROM   WORK_POLAND.T_ODY_KLIENT_LTM k
    JOIN   WORK_POLAND.T_ODY_FIRMA_PROFIL p ON p.NIP = k.NIP
    WHERE  p.PIETRO_NR = 1
    GROUP  BY CASE WHEN p.ZATRUDNIENIE <= 9 THEN '1a: 0-9' ELSE '1b: 10-40' END
)
SELECT PODWARSTWA,
       rp.FIRMY_RYNEK, l.FIRMY_LYRECO,
       ROUND(l.FIRMY_LYRECO / NULLIF(rp.FIRMY_RYNEK, 0) * 100, 2)          AS PENETRACJA_FIRM_PCT,
       rp.PRACUJACY_RYNEK, l.PRACUJACY_LYRECO,
       ROUND(l.PRACUJACY_LYRECO / NULLIF(rp.PRACUJACY_RYNEK, 0) * 100, 2)  AS POKRYCIE_PRAC_PCT,
       l.SALES_LTM, rp.FIRMY_RYNEK_REGON
FROM   rp
FULL OUTER JOIN l USING (PODWARSTWA)
ORDER  BY PODWARSTWA;
