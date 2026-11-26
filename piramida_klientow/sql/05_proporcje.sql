SET DEFINE OFF;
-- =====================================================================
-- 05_proporcje.sql
-- Piramida klientow / Strategia Odyssey
--
-- JAK PRZYPISUJEMY DANE GUS DO NASZYCH PIETER
-- GUS podaje firmy i pracujacych w klasach 0-9 / 10-49 / 50-249 /
-- 250-999 / 1000+ (oraz 250+ w tablicy przedsiebiorstw aktywnych).
-- Nasze progi (40 / 200 / 500 / 4000) przecinaja klasy GUS:
--     0-9     -> 0-40 (w calosci)
--     10-49   -> 0-40 (10-40)      + 41-200 (41-49)
--     50-249  -> 41-200 (50-200)   + 201-500 (201-249)
--     250-999 -> 201-500 (250-500) + 501-4000 (501-999)
--     1000+   -> 501-4000 (1000-4000) + 4001+
--     250+    -> 201-500 + 501-4000 + 4001+
-- Proporcje podzialu bierzemy z rozkladu firm w DB_BAZA (caly rynek,
-- nie tylko nasi klienci): w kazdej klasie GUS liczymy, jaki odsetek
-- firm (W_FIRMY) i jaki odsetek pracujacych (W_PRAC) wypada w danym
-- pietrze. W 06: firmy GUS x W_FIRMY, pracujacy GUS x W_PRAC.
-- Suma po pietrach = suma GUS (liczby z GUS, z DB_BAZA tylko proporcje).
--
-- Populacja DB_BAZA: poza Public (ta sama flaga co u klientow), z
-- zatrudnieniem > 0, bez firm zakonczonych / zawieszonych w REGON.
-- Bez filtra na ROK_ZATRUDNIENIA - kolumna nie mowi o aktualnosci danych
-- (diagnostyka D06: lata od 1899, 96% firm 1000+ bez roku).
--
-- Wymaga: 03_profil_firm.sql (po korektach z 04).
-- Odswiezenie: TRUNCATE + ponowny INSERT (krok 2).
-- =====================================================================


-- ---------------------------------------------------------------------
-- KROK 1. Tabela (jednorazowo)
-- ---------------------------------------------------------------------
CALL WORK_POLAND.WORK_SCHEMA_CREATE_TABLE ('T_ODY_PROPORCJE',
    'KLASA_GUS       VARCHAR2(10)   NOT NULL,
     PIETRO_NR       NUMBER(2)      NOT NULL,
     LICZBA_FIRM_DB  NUMBER,
     SUMA_ZATR_DB    NUMBER,
     W_FIRMY         NUMBER,
     W_PRAC          NUMBER,
     DATA_WCZYTANIA  DATE           DEFAULT SYSDATE');


-- ---------------------------------------------------------------------
-- KROK 2. Zasilenie
-- ---------------------------------------------------------------------
-- TRUNCATE TABLE WORK_POLAND.T_ODY_PROPORCJE;

INSERT INTO WORK_POLAND.T_ODY_PROPORCJE
    (KLASA_GUS, PIETRO_NR, LICZBA_FIRM_DB, SUMA_ZATR_DB, W_FIRMY, W_PRAC)
WITH f AS (
    SELECT p.ZATRUDNIENIE AS ZATR, p.KLASA_GUS, p.PIETRO_NR
    FROM   WORK_POLAND.T_ODY_FIRMA_PROFIL p
    WHERE  p.FLAGA_PUBLIC = 'N'
      AND  p.ZATRUDNIENIE > 0
      AND  p.PIETRO_NR BETWEEN 1 AND 5
      AND  p.STATUS_REJESTR NOT IN ('ZAKONCZONA', 'ZAWIESZONA')
      AND  LENGTH(p.NIP) = 10
),
k AS (
    SELECT KLASA_GUS, PIETRO_NR, ZATR FROM f
    UNION ALL                                   -- przedsiebiorstwa aktywne GUS maja tylko 250+
    SELECT '250+', PIETRO_NR, ZATR FROM f WHERE ZATR >= 250
)
SELECT KLASA_GUS, PIETRO_NR,
       COUNT(*)                                                         AS LICZBA_FIRM_DB,
       SUM(ZATR)                                                        AS SUMA_ZATR_DB,
       RATIO_TO_REPORT(COUNT(*))  OVER (PARTITION BY KLASA_GUS)         AS W_FIRMY,
       RATIO_TO_REPORT(SUM(ZATR)) OVER (PARTITION BY KLASA_GUS)         AS W_PRAC
FROM   k
GROUP  BY KLASA_GUS, PIETRO_NR;

COMMIT;


-- ---------------------------------------------------------------------
-- KONTROLA 1: macierz podzialu - % firm z klasy GUS w kazdym pietrze
-- (kazdy wiersz sumuje sie do 100)
-- ---------------------------------------------------------------------
SELECT KLASA_GUS,
       ROUND(SUM(CASE WHEN PIETRO_NR = 1 THEN W_FIRMY END) * 100, 1)   AS "0-40 %FIRM",
       ROUND(SUM(CASE WHEN PIETRO_NR = 2 THEN W_FIRMY END) * 100, 1)   AS "41-200 %FIRM",
       ROUND(SUM(CASE WHEN PIETRO_NR = 3 THEN W_FIRMY END) * 100, 1)   AS "201-500 %FIRM",
       ROUND(SUM(CASE WHEN PIETRO_NR = 4 THEN W_FIRMY END) * 100, 1)   AS "501-4000 %FIRM",
       ROUND(SUM(CASE WHEN PIETRO_NR = 5 THEN W_FIRMY END) * 100, 1)   AS "4001+ %FIRM",
       ROUND(SUM(W_FIRMY) * 100, 1)                                    AS SUMA,
       SUM(LICZBA_FIRM_DB)                                             AS FIRMY_DB
FROM   WORK_POLAND.T_ODY_PROPORCJE
GROUP  BY KLASA_GUS
ORDER  BY DECODE(KLASA_GUS, '0-9', 1, '10-49', 2, '50-249', 3, '250-999', 4, '1000+', 5, '250+', 6);


-- ---------------------------------------------------------------------
-- KONTROLA 2: to samo dla pracujacych (% pracujacych z klasy GUS)
-- ---------------------------------------------------------------------
SELECT KLASA_GUS,
       ROUND(SUM(CASE WHEN PIETRO_NR = 1 THEN W_PRAC END) * 100, 1)    AS "0-40 %PRAC",
       ROUND(SUM(CASE WHEN PIETRO_NR = 2 THEN W_PRAC END) * 100, 1)    AS "41-200 %PRAC",
       ROUND(SUM(CASE WHEN PIETRO_NR = 3 THEN W_PRAC END) * 100, 1)    AS "201-500 %PRAC",
       ROUND(SUM(CASE WHEN PIETRO_NR = 4 THEN W_PRAC END) * 100, 1)    AS "501-4000 %PRAC",
       ROUND(SUM(CASE WHEN PIETRO_NR = 5 THEN W_PRAC END) * 100, 1)    AS "4001+ %PRAC",
       ROUND(SUM(W_PRAC) * 100, 1)                                     AS SUMA,
       SUM(SUMA_ZATR_DB)                                               AS ZATR_DB
FROM   WORK_POLAND.T_ODY_PROPORCJE
GROUP  BY KLASA_GUS
ORDER  BY DECODE(KLASA_GUS, '0-9', 1, '10-49', 2, '50-249', 3, '250-999', 4, '1000+', 5, '250+', 6);
