SET DEFINE OFF;
-- =====================================================================
-- 04_lista_4001.sql
-- Piramida klientow / Strategia Odyssey
--
-- Weryfikacja gornych pieter (501-4000 i 4001+) przed liczeniem proporcji.
-- GUS nie publikuje progu 4000 - pietro 4001+ powstaje z DB_BAZA, wiec
-- duze firmy trzeba przejrzec recznie. Typowe bledy DB_BAZA:
--   (a) zatrudnienie CALEJ GRUPY KAPITALOWEJ wpisane przy kazdej spolce
--       (kolumna NIP_W_GRUPIE_Z_TYM_ZATR > 1),
--   (b) stare dane (ROK_ZATRUDNIENIA sprzed kilku lat),
--   (c) firma zakonczona / zawieszona (STATUS_REJESTR).
-- Poprawki wpisujemy do WORK_POLAND.T_ODY_KOREKTA_FIRMY, np.:
--   INSERT INTO WORK_POLAND.T_ODY_KOREKTA_FIRMY (NIP, ZATRUDNIENIE, FLAGA_PUBLIC, UWAGI)
--   VALUES ('1234567890', 2500, NULL, 'DB_BAZA = grupa; spolka ok. 2500 wg sprawozdania KRS 2025');
--   COMMIT;
-- a potem ponownie 03_profil_firm.sql (TRUNCATE + INSERT) i dalej 05, 06.
-- Zrodla do weryfikacji: sprawozdania finansowe w eKRS (przecietne
-- zatrudnienie), strona firmy, raporty roczne spolek gieldowych.
--
-- Wymaga: 03_profil_firm.sql.
-- =====================================================================


-- ---------------------------------------------------------------------
-- LISTA DO WERYFIKACJI: firmy (caly rynek, nie tylko klienci) z
-- zatrudnieniem >= 3000, poza Public. Od 3000, bo firmy tuz pod progiem
-- z nieaktualnym zatrudnieniem tez moga nalezec do 4001+.
-- Eksport do Excela -> przeglad -> korekty.
-- ---------------------------------------------------------------------
SELECT p.NIP,
       p.NAZWA,
       p.ZATRUDNIENIE,
       p.ROK_ZATRUDNIENIA,
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
