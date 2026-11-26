SET DEFINE OFF;
-- =====================================================================
-- 02_klienci_ltm.sql
-- Piramida klientow / Strategia Odyssey
--
-- WORK_POLAND.T_ODY_KLIENT_LTM - "firma u nas" = NIP platnika z dodatnia
-- sprzedaza netto w ostatnich 12 ZAMKNIETYCH miesiacach (decyzja 2026-11-26).
-- Jeden wiersz na NIP: sprzedaz i marza LTM + glowny SOLDTO (najwieksza
-- sprzedaz LTM w NIP) i jego obecne przypisanie (typ i region sprzedazy).
--
-- Reguly z BAZA_WIEDZY_HALO_RAG (DB_KNOWLEDGE sek. 3, 8):
--   NIP = REGEXP_REPLACE(T_PAYER.TAX_NUMBER1, '[^0-9]', '')
--   filtry standardowe T_INVOICE_LINE.
-- Odswiezenie: TRUNCATE + ponowny INSERT (krok 2).
-- =====================================================================


-- ---------------------------------------------------------------------
-- KROK 1. Tabela (jednorazowo)
-- ---------------------------------------------------------------------
CALL WORK_POLAND.WORK_SCHEMA_CREATE_TABLE ('T_ODY_KLIENT_LTM',
    'NIP                      VARCHAR2(20)   NOT NULL,
     LTM_OD                   DATE           NOT NULL,
     LTM_DO                   DATE           NOT NULL,
     SALES_LTM                NUMBER,
     MARGIN_LTM               NUMBER,
     LICZBA_SOLDTO            NUMBER,
     SOLDTO_GLOWNY            VARCHAR2(30),
     SALES_FORCE_TYPE_CODE    VARCHAR2(100),
     SALES_FORCE_REGION_CODE  VARCHAR2(12),
     SALES_FORCE_REGION       VARCHAR2(400),
     DATA_WCZYTANIA           DATE           DEFAULT SYSDATE');
-- LTM_OD / LTM_DO: okres [LTM_OD, LTM_DO) - LTM_DO = 1. dzien biezacego miesiaca


-- ---------------------------------------------------------------------
-- KROK 2. Zasilenie
-- ---------------------------------------------------------------------
-- TRUNCATE TABLE WORK_POLAND.T_ODY_KLIENT_LTM;

INSERT INTO WORK_POLAND.T_ODY_KLIENT_LTM
    (NIP, LTM_OD, LTM_DO, SALES_LTM, MARGIN_LTM, LICZBA_SOLDTO, SOLDTO_GLOWNY,
     SALES_FORCE_TYPE_CODE, SALES_FORCE_REGION_CODE, SALES_FORCE_REGION)
WITH p AS (
    SELECT ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -12) AS LTM_OD,
           TRUNC(SYSDATE, 'MM')                  AS LTM_DO
    FROM   dual
),
linie AS (
    SELECT REGEXP_REPLACE(tp.TAX_NUMBER1, '[^0-9]', '')             AS NIP,
           til.SOLDTO_NUMBER,
           til.SALES_AMOUNT,
           til.MARGIN_AMOUNT
    FROM   POLAND.T_INVOICE_LINE til
    CROSS JOIN p
    JOIN   POLAND.T_PAYER tp
           ON  tp.PAYER_NUMBER = til.PAYER_NUMBER
           AND tp.COUNTRY_CODE = til.COUNTRY_CODE
    WHERE  til.COUNTRY_CODE        = 'PL'
      AND  til.BUSINESS_SCOPE_FLAG = 'Y'
      AND  NVL(til.CANCELLED_FLAG, 'N')   <> 'Y'
      AND  NVL(til.DL_DELETION_FLAG, 'N') <> 'Y'
      AND  til.INVOICE_DATE >= p.LTM_OD
      AND  til.INVOICE_DATE <  p.LTM_DO
),
nip AS (
    SELECT NIP,
           SUM(SALES_AMOUNT)  AS SALES_LTM,
           SUM(MARGIN_AMOUNT) AS MARGIN_LTM
    FROM   linie
    WHERE  NIP IS NOT NULL
    GROUP  BY NIP
),
soldto AS (
    SELECT NIP, SOLDTO_NUMBER, SUM(SALES_AMOUNT) AS SALES
    FROM   linie
    WHERE  NIP IS NOT NULL
    GROUP  BY NIP, SOLDTO_NUMBER
),
glowny AS (                                     -- glowny SOLDTO = najwieksza sprzedaz LTM
    SELECT NIP,
           MAX(SOLDTO_NUMBER) KEEP (DENSE_RANK LAST ORDER BY SALES NULLS FIRST) AS SOLDTO_GLOWNY,
           COUNT(*)                                                           AS LICZBA_SOLDTO
    FROM   soldto
    GROUP  BY NIP
)
SELECT n.NIP, p.LTM_OD, p.LTM_DO,
       n.SALES_LTM, n.MARGIN_LTM,
       g.LICZBA_SOLDTO, g.SOLDTO_GLOWNY,
       ts.SALES_FORCE_TYPE_CODE,
       ts.SALES_FORCE_REGION_CODE,
       sfr.SALES_FORCE_REGION
FROM   nip n
CROSS JOIN p
JOIN   glowny g
       ON  g.NIP = n.NIP
LEFT JOIN POLAND.T_SOLDTO ts
       ON  ts.SOLDTO_NUMBER = g.SOLDTO_GLOWNY
       AND ts.COUNTRY_CODE  = 'PL'
LEFT JOIN SHARED.T_SALES_FORCE_REGION sfr
       ON  sfr.SALES_FORCE_REGION_CODE = ts.SALES_FORCE_REGION_CODE
       AND sfr.COUNTRY_CODE            = 'PL'
       AND sfr.LANGUAGE_CODE           = 'POLISH'
WHERE  n.SALES_LTM > 0;                         -- aktywny = dodatnia sprzedaz netto

COMMIT;


-- ---------------------------------------------------------------------
-- KONTROLA 1: liczba klientow i sprzedaz; NIP-y inne niz 10 cyfr
-- (zagraniczne / bledne) nie trafia do pieter - widac ile to sprzedazy
-- ---------------------------------------------------------------------
SELECT CASE WHEN LENGTH(NIP) = 10 THEN 'NIP_10_CYFR' ELSE 'NIP_INNY' END     AS GRUPA,
       COUNT(*)                                                             AS LICZBA_NIP,
       ROUND(SUM(SALES_LTM))                                                AS SALES_LTM,
       ROUND(RATIO_TO_REPORT(SUM(SALES_LTM)) OVER () * 100, 2)              AS PCT_SALES,
       MIN(LTM_OD) AS LTM_OD, MIN(LTM_DO) AS LTM_DO
FROM   WORK_POLAND.T_ODY_KLIENT_LTM
GROUP  BY CASE WHEN LENGTH(NIP) = 10 THEN 'NIP_10_CYFR' ELSE 'NIP_INNY' END;


-- ---------------------------------------------------------------------
-- KONTROLA 2: sprzedaz LTM bez NIP-u platnika (poza piramida)
-- ---------------------------------------------------------------------
SELECT ROUND(SUM(CASE WHEN REGEXP_REPLACE(tp.TAX_NUMBER1, '[^0-9]', '') IS NULL
                      THEN til.SALES_AMOUNT END))                           AS SALES_BEZ_NIP,
       ROUND(SUM(til.SALES_AMOUNT))                                         AS SALES_TOTAL,
       ROUND(SUM(CASE WHEN REGEXP_REPLACE(tp.TAX_NUMBER1, '[^0-9]', '') IS NULL
                      THEN til.SALES_AMOUNT END)
             / NULLIF(SUM(til.SALES_AMOUNT), 0) * 100, 2)                   AS PCT_BEZ_NIP
FROM   POLAND.T_INVOICE_LINE til
LEFT JOIN POLAND.T_PAYER tp
       ON  tp.PAYER_NUMBER = til.PAYER_NUMBER
       AND tp.COUNTRY_CODE = til.COUNTRY_CODE
WHERE  til.COUNTRY_CODE        = 'PL'
  AND  til.BUSINESS_SCOPE_FLAG = 'Y'
  AND  NVL(til.CANCELLED_FLAG, 'N')   <> 'Y'
  AND  NVL(til.DL_DELETION_FLAG, 'N') <> 'Y'
  AND  til.INVOICE_DATE >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -12)
  AND  til.INVOICE_DATE <  TRUNC(SYSDATE, 'MM');
