SET DEFINE OFF;
-- =====================================================================
-- 04_listy_do_weryfikacji.sql
-- Piramida klientow / Strategia Odyssey
--
-- Trzy listy do recznej pracy przed liczeniem proporcji (05) i piramidy (06):
--
--   LISTA A - DUZE FIRMY (>= 3000 osob, caly rynek): weryfikacja pieter
--     501-4000 i 4001+. GUS nie publikuje progu 4000, wiec pietro 4001+
--     powstaje z DB_BAZA. Typowe bledy DB_BAZA:
--       (a) zatrudnienie CALEJ GRUPY przy kazdej spolce (D10: 0 takich, ale
--           np. Lasy Panstwowe - caly PGL przy Dyrekcji Generalnej),
--       (b) nieaktualne dane: duze firmy sa glownie w zrzucie z 01.01.2022 (D17),
--       (c) firma zakonczona / zawieszona (STATUS_REJESTR).
--
--   LISTA B - NASI KLIENCI DO UZUPELNIENIA (pietro 99): spolki bez zatrudnienia
--     z TOP_N wg sprzedazy (03, parametr TOP_N_RECZNIE = 200). Zatrudnienie
--     z eKRS (przecietne zatrudnienie ze sprawozdania finansowego).
--
--   LISTA C - NIP-Y SPOZA T_CEIDG_GUS (grupy VAT, NIP-y zagraniczne): do
--     zmapowania w T_ODY_MAPA_NIP (grupa VAT -> NIP spolki; zagraniczny).
--
-- Gdzie wpisujemy:
--   zatrudnienie (A, B):
--     INSERT INTO WORK_POLAND.T_ODY_KOREKTA_FIRMY (NIP, ZATRUDNIENIE, FLAGA_PUBLIC, UWAGI)
--     VALUES ('1234567890', 2500, NULL, 'eKRS: przecietne zatrudnienie 2025');
--   mapowanie (C):
--     INSERT INTO WORK_POLAND.T_ODY_MAPA_NIP (NIP_SAP, NIP_DOCELOWY, TYP, UWAGI)
--     VALUES ('1234567890', '0987654321', 'GRUPA_VAT', 'Grupa VAT X - X S.A.');
--   COMMIT;
-- Potem ponownie: 02 (tylko gdy zmienilo sie mapowanie), 03, 05, 06
-- (TRUNCATE + INSERT w kazdym).
--
-- Wymaga: 03_profil_firm.sql.
-- =====================================================================


-- ---------------------------------------------------------------------
-- LISTA A: firmy (caly rynek, nie tylko klienci) z
-- zatrudnieniem >= 3000, poza Public. Od 3000, bo firmy tuz pod progiem
-- z nieaktualnym zatrudnieniem tez moga nalezec do 4001+.
-- Eksport do Excela -> przeglad -> korekty.
-- ---------------------------------------------------------------------
SELECT p.NIP,
       p.NAZWA,
       p.ZATRUDNIENIE,
       p.ZRZUT_DB_BAZA,
       p.DATA_BADANIA,
       p.ZRODLO_ZATR,
       p.PIETRO,
       p.GRUPA_KAPITALOWA,
       CASE WHEN p.GRUPA_KAPITALOWA IS NOT NULL
            THEN COUNT(*) OVER (PARTITION BY p.GRUPA_KAPITALOWA, p.ZATRUDNIENIE)
       END                                                              AS NIP_W_GRUPIE_Z_TYM_ZATR,
       p.DZIAL_PKD,
       p.SEKTOR,
       p.STATUS_REJESTR,
       p.CZY_KLIENT,
       ROUND(k.SALES_LTM)                                               AS SALES_LTM,
       k.SALES_FORCE_TYPE_CODE,
       k.SALES_FORCE_REGION
FROM   WORK_POLAND.T_ODY_FIRMA_PROFIL p
LEFT JOIN WORK_POLAND.T_ODY_KLIENT_LTM k ON k.NIP = p.NIP
WHERE  p.ZATRUDNIENIE >= 3000
  AND  p.FLAGA_PUBLIC = 'N'
ORDER  BY p.ZATRUDNIENIE DESC, p.NAZWA;


-- ---------------------------------------------------------------------
-- KONTROLA: DB_BAZA vs GUS dla duzych firm (poza Public, bez zakonczonych
-- i zawieszonych). Jesli DB_BAZA ma wyraznie WIECEJ firm 1000+ niz GUS,
-- to zwykle znak bledu (a) - zatrudnienie grupy przy kazdej spolce.
-- GUS: REGON 1000+ (deklarowana wielkosc) i pracujacy w podmiotach 1000+.
-- ---------------------------------------------------------------------
WITH db AS (
    SELECT SUM(CASE WHEN ZATRUDNIENIE >= 1000 THEN 1 END)               AS DB_FIRMY_1000,
           SUM(CASE WHEN ZATRUDNIENIE >= 1000 THEN ZATRUDNIENIE END)    AS DB_PRAC_1000,
           SUM(CASE WHEN ZATRUDNIENIE >  4000 THEN 1 END)               AS DB_FIRMY_4001,
           SUM(CASE WHEN ZATRUDNIENIE >  4000 THEN ZATRUDNIENIE END)    AS DB_PRAC_4001,
           SUM(CASE WHEN ZATRUDNIENIE >  4000 AND CZY_KLIENT = 'T'
                    THEN 1 END)                                         AS DB_FIRMY_4001_KLIENCI
    FROM   WORK_POLAND.T_ODY_FIRMA_PROFIL
    WHERE  FLAGA_PUBLIC = 'N'
      AND  STATUS_REJESTR NOT IN ('ZAKONCZONA', 'ZAWIESZONA')
),
gus AS (
    SELECT SUM(CASE WHEN MIARA = 'FIRMY_REGON'   AND KLASA_GUS = '1000+' THEN WARTOSC END) AS GUS_FIRMY_REGON_1000,
           SUM(CASE WHEN MIARA = 'FIRMY_AKTYWNE' AND KLASA_GUS = '250+'  THEN WARTOSC END) AS GUS_FIRMY_AKT_250,
           SUM(CASE WHEN MIARA = 'PRACUJACY'     AND KLASA_GUS = '1000+' THEN WARTOSC END) AS GUS_PRAC_1000
    FROM   WORK_POLAND.T_ODY_RYNEK_GUS
    WHERE  GRUPA = 'POZA_PUBLIC'
)
SELECT db.*, gus.*,
       ROUND(db.DB_FIRMY_1000 / NULLIF(gus.GUS_FIRMY_REGON_1000, 0), 2) AS RELACJA_FIRMY_DB_DO_GUS,
       ROUND(db.DB_PRAC_1000  / NULLIF(gus.GUS_PRAC_1000, 0), 2)        AS RELACJA_PRAC_DB_DO_GUS
FROM   db CROSS JOIN gus;


-- ---------------------------------------------------------------------
-- KONTROLA: grupy kapitalowe, w ktorych wiele NIP-ow ma identyczne duze
-- zatrudnienie (najczestsze zrodlo zawyzenia pietra 4001+)
-- ---------------------------------------------------------------------
SELECT GRUPA_KAPITALOWA, ZATRUDNIENIE,
       COUNT(*)                                                         AS LICZBA_NIP,
       SUM(CASE WHEN CZY_KLIENT = 'T' THEN 1 ELSE 0 END)                AS KLIENCI,
       LISTAGG(SUBSTR(NAZWA, 1, 60), ' | ' ON OVERFLOW TRUNCATE)
           WITHIN GROUP (ORDER BY NAZWA)                                AS SPOLKI
FROM   WORK_POLAND.T_ODY_FIRMA_PROFIL
WHERE  ZATRUDNIENIE >= 1000
  AND  FLAGA_PUBLIC = 'N'
  AND  GRUPA_KAPITALOWA IS NOT NULL
GROUP  BY GRUPA_KAPITALOWA, ZATRUDNIENIE
HAVING COUNT(*) > 1
ORDER  BY ZATRUDNIENIE DESC;


-- ---------------------------------------------------------------------
-- LISTA B: nasi klienci DO_UZUPELNIENIA - spolki bez zatrudnienia z TOP_N
-- wg sprzedazy. Sprzedaz jako udzial %. Uzupelnic ZATRUDNIENIE z eKRS.
-- Grupy VAT (TYP_NIP = 'GRUPA_VAT' po mapowaniu) dostaja zatrudnienie
-- spolki docelowej.
-- ---------------------------------------------------------------------
SELECT p.NIP,
       SUBSTR(p.NAZWA, 1, 80)                                           AS NAZWA,
       p.TYP_PODMIOTU,
       k.TYP_NIP,
       p.DZIAL_PKD,
       p.STATUS_REJESTR,
       k.SALES_FORCE_TYPE_CODE,
       k.SALES_FORCE_REGION,
       ROUND(k.SALES_LTM / (SELECT SUM(SALES_LTM) FROM WORK_POLAND.T_ODY_KLIENT_LTM) * 100, 3)
                                                                        AS PCT_SPRZEDAZY,
       CAST(NULL AS NUMBER)                                             AS ZATRUDNIENIE_DO_WPISANIA
FROM   WORK_POLAND.T_ODY_FIRMA_PROFIL p
JOIN   WORK_POLAND.T_ODY_KLIENT_LTM k ON k.NIP = p.NIP
WHERE  p.PIETRO_ZRODLO = 'DO_UZUPELNIENIA'
ORDER  BY k.SALES_LTM DESC;


-- ---------------------------------------------------------------------
-- LISTA C: NIP-y z SAP, ktorych nie ma w T_CEIDG_GUS ani w mapowaniu
-- (diagnostyka D22: grupy VAT i NIP-y zagraniczne). Nazwa i NIP VAT z T_PAYER.
-- Grupa VAT -> wpisac NIP spolki (przedstawiciel grupy albo spolka, ktora
-- kupuje); zagraniczny -> TYP = 'ZAGRANICZNY', bez NIP_DOCELOWY.
-- ---------------------------------------------------------------------
SELECT k.NIP_SAP,
       SUBSTR(tp.PAYER_NAME, 1, 60)                                     AS NAZWA_PLATNIKA,
       tp.VAT_NUMBER,
       tp.TAX_NUMBER1,
       k.LICZBA_SOLDTO,
       k.SALES_FORCE_TYPE_CODE,
       k.SALES_FORCE_REGION,
       ROUND(k.SALES_LTM / (SELECT SUM(SALES_LTM) FROM WORK_POLAND.T_ODY_KLIENT_LTM) * 100, 3)
                                                                        AS PCT_SPRZEDAZY,
       CAST(NULL AS VARCHAR2(20))                                       AS NIP_DOCELOWY_DO_WPISANIA,
       CAST(NULL AS VARCHAR2(20))                                       AS TYP_DO_WPISANIA
FROM   WORK_POLAND.T_ODY_KLIENT_LTM k
LEFT JOIN WORK_POLAND.T_CEIDG_GUS cg ON cg.NIP = k.NIP
LEFT JOIN WORK_POLAND.T_ODY_MAPA_NIP m ON m.NIP_SAP = k.NIP_SAP
LEFT JOIN POLAND.T_PAYER tp
       ON  tp.PAYER_NUMBER = k.PAYER_GLOWNY
       AND tp.COUNTRY_CODE = 'PL'
WHERE  cg.NIP IS NULL
  AND  m.NIP_SAP IS NULL
  AND  k.TYP_NIP = 'NIP'
ORDER  BY k.SALES_LTM DESC
FETCH FIRST 100 ROWS ONLY;
