SET DEFINE OFF;
-- =====================================================================
-- 02_klienci_ltm.sql
-- Piramida klientow / Strategia Odyssey
--
-- WORK_POLAND.T_ODY_KLIENT_LTM - "firma u nas" = NIP platnika z dodatnia
-- sprzedaza netto w ostatnich 12 ZAMKNIETYCH miesiacach (decyzja 2026-11-26).
-- Jeden wiersz na NIP: sprzedaz i marza LTM, glowny platnik i glowny SOLDTO
-- (najwieksza sprzedaz LTM w NIP), przypisanie w sprzedazy (typ, region)
-- i flaga REGION_PUBLIC (czy ktorykolwiek SOLDTO jest w regionie "Public").
-- SEGMENT_OBECNY i TOP_LEVEL glownego SOLDTO - do szacunku pietra klientow
-- bez zatrudnienia w 03 (decyzja 2026-11-26):
--   CORPORATE -> region: STRATEGIC / K&N / INTERNATIONAL / CA_PUBLIC / CA_INNE
--   SMB       -> segment terytorium opiekuna (T_KOD_POCZTOWY_OPIEKUN po
--                AREA_CODE): IS / PF / MM; brak -> SMB_INNE
--   TOP_LEVEL = COALESCE(NATIONAL_LEADER_NUMBER, SOLDTO_NUMBER)
--
-- Mapowanie NIP-ow (T_ODY_MAPA_NIP, lista C w 04):
--   grupa VAT  -> sprzedaz liczona na NIP spolki (NIP_DOCELOWY)
--   zagraniczny -> TYP_NIP = 'ZAGRANICZNY' (w 03 pietro 98, poza rynkiem PL)
-- NIP inny niz 10 cyfr -> TYP_NIP = 'NIE_10_CYFR' (tez pietro 98).
--
-- Reguly z BAZA_WIEDZY_HALO_RAG (DB_KNOWLEDGE sek. 3, 8):
--   NIP = REGEXP_REPLACE(T_PAYER.TAX_NUMBER1, '[^0-9]', '')
--   filtry standardowe T_INVOICE_LINE.
-- Odswiezenie (np. po uzupelnieniu T_ODY_MAPA_NIP): TRUNCATE + INSERT (krok 2).
-- =====================================================================


-- ---------------------------------------------------------------------
-- KROK 1. Tabela (jednorazowo)
-- ---------------------------------------------------------------------
CALL WORK_POLAND.WORK_SCHEMA_CREATE_TABLE ('T_ODY_KLIENT_LTM',
    'NIP                      VARCHAR2(20)   NOT NULL,
     TYP_NIP                  VARCHAR2(20),
     NIP_SAP                  VARCHAR2(20),
     LICZBA_NIP_SAP           NUMBER,
     LTM_OD                   DATE           NOT NULL,
     LTM_DO                   DATE           NOT NULL,
     SALES_LTM                NUMBER,
     MARGIN_LTM               NUMBER,
     PAYER_GLOWNY             VARCHAR2(30),
     LICZBA_SOLDTO            NUMBER,
     SOLDTO_GLOWNY            VARCHAR2(30),
     SALES_FORCE_TYPE_CODE    VARCHAR2(100),
     SALES_FORCE_REGION_CODE  VARCHAR2(12),
     SALES_FORCE_REGION       VARCHAR2(400),
     REGION_PUBLIC            CHAR(1),
     SEGMENT_OBECNY           VARCHAR2(20),
     TOP_LEVEL                VARCHAR2(30),
     DATA_WCZYTANIA           DATE           DEFAULT SYSDATE');
-- TYP_NIP      : NIP / GRUPA_VAT / ZAGRANICZNY / NIE_10_CYFR
-- NIP_SAP      : NIP z T_PAYER (rozny od NIP dla grup VAT); przy kilku - najwieksza sprzedaz
-- LTM_OD/LTM_DO: okres [LTM_OD, LTM_DO) - LTM_DO = 1. dzien biezacego miesiaca
-- REGION_PUBLIC: 'T' gdy ktorykolwiek SOLDTO NIP-u jest w regionie sprzedazy
--                z "PUBLI" w nazwie (dzis region 1620 "Public", diagnostyka D15)


-- ---------------------------------------------------------------------
-- KROK 2. Zasilenie
-- ---------------------------------------------------------------------
-- TRUNCATE TABLE WORK_POLAND.T_ODY_KLIENT_LTM;

INSERT INTO WORK_POLAND.T_ODY_KLIENT_LTM
    (NIP, TYP_NIP, NIP_SAP, LICZBA_NIP_SAP, LTM_OD, LTM_DO, SALES_LTM, MARGIN_LTM,
     PAYER_GLOWNY, LICZBA_SOLDTO, SOLDTO_GLOWNY,
     SALES_FORCE_TYPE_CODE, SALES_FORCE_REGION_CODE, SALES_FORCE_REGION, REGION_PUBLIC,
     SEGMENT_OBECNY, TOP_LEVEL)
WITH p AS (
    SELECT ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -12) AS LTM_OD,
           TRUNC(SYSDATE, 'MM')                  AS LTM_DO
    FROM   dual
),
linie0 AS (
    SELECT REGEXP_REPLACE(tp.TAX_NUMBER1, '[^0-9]', '')             AS NIP_SAP,
           til.PAYER_NUMBER,
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
area_seg AS (                                  -- segment terytorium opiekuna (jak w Go2M)
    SELECT AREA_CODE, MAX(SEGMENT) AS SEGMENT
    FROM   WORK_POLAND.T_KOD_POCZTOWY_OPIEKUN
    WHERE  SEGMENT IS NOT NULL
    GROUP  BY AREA_CODE
),
mapa AS (
    SELECT NIP_SAP, MAX(NIP_DOCELOWY) AS NIP_DOCELOWY, MAX(TYP) AS TYP
    FROM   WORK_POLAND.T_ODY_MAPA_NIP
    GROUP  BY NIP_SAP
),
linie AS (                                      -- NIP po mapowaniu + typ NIP-u
    SELECT CASE WHEN m.TYP = 'GRUPA_VAT' AND m.NIP_DOCELOWY IS NOT NULL
                THEN m.NIP_DOCELOWY ELSE l.NIP_SAP END                AS NIP,
           CASE WHEN m.TYP = 'ZAGRANICZNY'          THEN 4
                WHEN m.TYP = 'GRUPA_VAT'            THEN 3
                WHEN LENGTH(l.NIP_SAP) <> 10        THEN 2
                ELSE                                     1 END         AS TYP_NIP_NR,
           l.NIP_SAP, l.PAYER_NUMBER, l.SOLDTO_NUMBER, l.SALES_AMOUNT, l.MARGIN_AMOUNT
    FROM   linie0 l
    LEFT JOIN mapa m ON m.NIP_SAP = l.NIP_SAP
    WHERE  l.NIP_SAP IS NOT NULL
),
nip AS (
    SELECT NIP,
           MAX(TYP_NIP_NR)                                            AS TYP_NIP_NR,
           COUNT(DISTINCT NIP_SAP)                                    AS LICZBA_NIP_SAP,
           SUM(SALES_AMOUNT)                                          AS SALES_LTM,
           SUM(MARGIN_AMOUNT)                                         AS MARGIN_LTM
    FROM   linie
    GROUP  BY NIP
),
nip_sap AS (                                    -- NIP z SAP o najwiekszej sprzedazy
    SELECT NIP, MAX(NIP_SAP) KEEP (DENSE_RANK LAST ORDER BY SALES NULLS FIRST) AS NIP_SAP
    FROM  (SELECT NIP, NIP_SAP, SUM(SALES_AMOUNT) AS SALES FROM linie GROUP BY NIP, NIP_SAP)
    GROUP  BY NIP
),
platnik AS (                                    -- glowny platnik = najwieksza sprzedaz LTM
    SELECT NIP, MAX(PAYER_NUMBER) KEEP (DENSE_RANK LAST ORDER BY SALES NULLS FIRST) AS PAYER_GLOWNY
    FROM  (SELECT NIP, PAYER_NUMBER, SUM(SALES_AMOUNT) AS SALES FROM linie GROUP BY NIP, PAYER_NUMBER)
    GROUP  BY NIP
),
soldto AS (
    SELECT l.NIP, l.SOLDTO_NUMBER, SUM(l.SALES_AMOUNT) AS SALES,
           MAX(CASE WHEN UPPER(sfr.SALES_FORCE_REGION) LIKE '%PUBLI%' THEN 'T' ELSE 'N' END) AS REGION_PUBLIC
    FROM   linie l
    LEFT JOIN POLAND.T_SOLDTO ts
           ON  ts.SOLDTO_NUMBER = l.SOLDTO_NUMBER
           AND ts.COUNTRY_CODE  = 'PL'
    LEFT JOIN SHARED.T_SALES_FORCE_REGION sfr
           ON  sfr.SALES_FORCE_REGION_CODE = ts.SALES_FORCE_REGION_CODE
           AND sfr.COUNTRY_CODE            = 'PL'
           AND sfr.LANGUAGE_CODE           = 'POLISH'
    GROUP  BY l.NIP, l.SOLDTO_NUMBER
),
glowny AS (                                     -- glowny SOLDTO = najwieksza sprzedaz LTM
    SELECT NIP,
           MAX(SOLDTO_NUMBER) KEEP (DENSE_RANK LAST ORDER BY SALES NULLS FIRST) AS SOLDTO_GLOWNY,
           COUNT(*)                                                           AS LICZBA_SOLDTO,
           MAX(REGION_PUBLIC)                                                 AS REGION_PUBLIC
    FROM   soldto
    GROUP  BY NIP
)
SELECT n.NIP,
       DECODE(n.TYP_NIP_NR, 4, 'ZAGRANICZNY', 3, 'GRUPA_VAT', 2, 'NIE_10_CYFR', 'NIP') AS TYP_NIP,
       ns.NIP_SAP,
       n.LICZBA_NIP_SAP,
       p.LTM_OD, p.LTM_DO,
       n.SALES_LTM, n.MARGIN_LTM,
       pl.PAYER_GLOWNY,
       g.LICZBA_SOLDTO, g.SOLDTO_GLOWNY,
       ts.SALES_FORCE_TYPE_CODE,
       ts.SALES_FORCE_REGION_CODE,
       sfr.SALES_FORCE_REGION,
       g.REGION_PUBLIC,
       CASE
           WHEN ts.SALES_FORCE_TYPE_CODE = 'CORPORATE' THEN
               CASE WHEN UPPER(sfr.SALES_FORCE_REGION) LIKE '%STRATEG%'                 THEN 'STRATEGIC'
                    WHEN UPPER(sfr.SALES_FORCE_REGION) LIKE '%K' || CHR(38) || 'N%'     THEN 'K' || CHR(38) || 'N'
                    WHEN UPPER(sfr.SALES_FORCE_REGION) LIKE '%INTERNAT%'                THEN 'INTERNATIONAL'
                    WHEN UPPER(sfr.SALES_FORCE_REGION) LIKE '%PUBLI%'                   THEN 'CA_PUBLIC'
                    ELSE                                                                     'CA_INNE' END
           WHEN ars.SEGMENT IN ('IS', 'PF', 'MM')       THEN ars.SEGMENT
           ELSE                                              'SMB_INNE'
       END                                                              AS SEGMENT_OBECNY,
       COALESCE(ts.NATIONAL_LEADER_NUMBER, ts.SOLDTO_NUMBER)            AS TOP_LEVEL
FROM   nip n
CROSS JOIN p
JOIN   glowny g   ON g.NIP  = n.NIP
JOIN   nip_sap ns ON ns.NIP = n.NIP
JOIN   platnik pl ON pl.NIP = n.NIP
LEFT JOIN POLAND.T_SOLDTO ts
       ON  ts.SOLDTO_NUMBER = g.SOLDTO_GLOWNY
       AND ts.COUNTRY_CODE  = 'PL'
LEFT JOIN SHARED.T_SALES_FORCE_REGION sfr
       ON  sfr.SALES_FORCE_REGION_CODE = ts.SALES_FORCE_REGION_CODE
       AND sfr.COUNTRY_CODE            = 'PL'
       AND sfr.LANGUAGE_CODE           = 'POLISH'
LEFT JOIN area_seg ars
       ON  ars.AREA_CODE = ts.AREA_CODE
WHERE  n.SALES_LTM > 0;                         -- aktywny = dodatnia sprzedaz netto

COMMIT;


-- ---------------------------------------------------------------------
-- KONTROLA 1: klienci wg typu NIP-u (udzial w sprzedazy)
-- ---------------------------------------------------------------------
SELECT TYP_NIP,
       COUNT(*)                                                             AS LICZBA_NIP,
       ROUND(RATIO_TO_REPORT(SUM(SALES_LTM)) OVER () * 100, 2)              AS PCT_SPRZEDAZY,
       SUM(CASE WHEN REGION_PUBLIC = 'T' THEN 1 ELSE 0 END)                 AS W_REGIONIE_PUBLIC,
       MIN(LTM_OD) AS LTM_OD, MIN(LTM_DO) AS LTM_DO
FROM   WORK_POLAND.T_ODY_KLIENT_LTM
GROUP  BY TYP_NIP
ORDER  BY LICZBA_NIP DESC;


-- ---------------------------------------------------------------------
-- KONTROLA 1b: klienci wg segmentu obecnego (glowny SOLDTO)
-- ---------------------------------------------------------------------
SELECT SEGMENT_OBECNY,
       COUNT(*)                                                             AS LICZBA_NIP,
       ROUND(RATIO_TO_REPORT(SUM(SALES_LTM)) OVER () * 100, 2)              AS PCT_SPRZEDAZY
FROM   WORK_POLAND.T_ODY_KLIENT_LTM
GROUP  BY SEGMENT_OBECNY
ORDER  BY LICZBA_NIP DESC;


-- ---------------------------------------------------------------------
-- KONTROLA 2: sprzedaz LTM bez NIP-u platnika (poza piramida)
-- ---------------------------------------------------------------------
SELECT ROUND(SUM(CASE WHEN REGEXP_REPLACE(tp.TAX_NUMBER1, '[^0-9]', '') IS NULL
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
