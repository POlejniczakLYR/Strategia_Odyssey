SET DEFINE OFF;
-- =====================================================================
-- 03_profil_firm.sql
-- Piramida klientow / Strategia Odyssey
--
-- WORK_POLAND.T_ODY_FIRMA_PROFIL - jeden wiersz na NIP dla:
--   (a) wszystkich firm z DB_BAZA (rynek - do proporcji podzialu klas GUS, 05)
--   (b) wszystkich naszych klientow LTM (T_ODY_KLIENT_LTM, 02)
-- Te same reguly dla rynku i dla nas: zatrudnienie, dzial PKD, sektor,
-- flaga PUBLIC, klasa GUS, pietro piramidy.
--
-- ZATRUDNIENIE : korekta reczna (T_ODY_KOREKTA_FIRMY) > DB_BAZA
--                (DB_BAZA: wiersz z ostatnim rokiem, w ktorym jest zatrudnienie)
-- DZIAL_PKD    : T_CEIDG_GUS > Katalog Podmiotow Publicznych > DB_BAZA
--                (2 pierwsze cyfry - dzialy 84-93 sa takie same w PKD 2007 i 2025)
-- SEKTOR       : PUBLICZNY gdy NIP jest w Katalogu Podmiotow Publicznych
--                (KATEGORIA_PODMIOTU = 'PUBLIC', STATUS = 'ACTIVE') albo forma
--                wlasnosci w T_CEIDG_GUS: Skarb Panstwa, panstwowe osoby prawne, JST,
--                mieszana w sektorze publicznym / z przewaga sektora publicznego
-- FLAGA_PUBLIC : wariant B = SEKTOR PUBLICZNY i dzial 84-88 / 90-93
--                (administracja, edukacja, zdrowie, pomoc spoleczna, kultura);
--                korekta reczna ma pierwszenstwo
-- PIETRO (kolumna PIETRO_ZRODLO mowi, skad sie wzielo):
--   98 POZA_RYNKIEM_PL  NIP zagraniczny / inny niz 10 cyfr (ZAGRANICZNY)
--    6 PUBLIC           flaga Public (PUBLIC)
--  1-5                  wg zatrudnienia i T_ODY_PIRAMIDA_PROGI (ZATRUDNIENIE)
--  klienci BEZ zatrudnienia (decyzja 2026-11-26, diagnostyka D19-D21):
--    1 0-40             osoba fizyczna z CEIDG (SZACUNEK_OSOBA_FIZYCZNA)
--    1 0-40             spolka spoza TOP_N wg sprzedazy - sprzedaz na NIP nizsza
--                       niz srednio w 0-40 (SZACUNEK_MALA_SPRZEDAZ)
--   99 DO_UZUPELNIENIA  spolka z TOP_N wg sprzedazy - uzupelnic zatrudnienie
--                       recznie (lista B w 04) albo zmapowac grupe VAT (lista C)
--   TOP_N_RECZNIE = 200 (CTE par) - 200 najwiekszych to polowa sprzedazy
--   spolek bez zatrudnienia (D21)
--  firmy rynku (nie klienci) bez zatrudnienia: 99 (BRAK_ZATRUDNIENIA), nie
--  wchodza do proporcji w 05
--
-- Wymaga: 00_setup.sql, 02_klienci_ltm.sql.
-- Odswiezenie (np. po korektach z 04): TRUNCATE + ponowny INSERT (krok 2).
-- =====================================================================


-- ---------------------------------------------------------------------
-- KROK 1. Tabela (jednorazowo)
-- ---------------------------------------------------------------------
CALL WORK_POLAND.WORK_SCHEMA_CREATE_TABLE ('T_ODY_FIRMA_PROFIL',
    'NIP               VARCHAR2(20)   NOT NULL,
     NAZWA             VARCHAR2(1000),
     ZATRUDNIENIE      NUMBER,
     ZRZUT_DB_BAZA     VARCHAR2(20),
     DATA_BADANIA      VARCHAR2(20),
     ZRODLO_ZATR       VARCHAR2(20),
     GRUPA_KAPITALOWA  VARCHAR2(255),
     DZIAL_PKD         VARCHAR2(2),
     ZRODLO_PKD        VARCHAR2(20),
     FORMA_WLASNOSCI   VARCHAR2(500),
     SEKTOR            VARCHAR2(20),
     ZRODLO_SEKTORA    VARCHAR2(20),
     FLAGA_PUBLIC      CHAR(1),
     STATUS_REJESTR    VARCHAR2(20),
     KLASA_GUS         VARCHAR2(10),
     PIETRO_NR         NUMBER(2),
     PIETRO            VARCHAR2(20),
     PIETRO_ZRODLO     VARCHAR2(30),
     TYP_PODMIOTU      VARCHAR2(5),
     TYP_NIP           VARCHAR2(20),
     CZY_KLIENT        CHAR(1),
     DATA_WCZYTANIA    DATE           DEFAULT SYSDATE');
-- ZRODLO_ZATR   : DB_BAZA / KOREKTA
-- SEKTOR        : PUBLICZNY / PRYWATNY / NIEZNANY
-- STATUS_REJESTR: AKTYWNA / ZAWIESZONA / ZAKONCZONA / BRAK (NIP-u nie ma w T_CEIDG_GUS)
-- PIETRO_ZRODLO : ZATRUDNIENIE / PUBLIC / ZAGRANICZNY / SZACUNEK_OSOBA_FIZYCZNA /
--                 SZACUNEK_MALA_SPRZEDAZ / DO_UZUPELNIENIA / BRAK_ZATRUDNIENIA
-- TYP_PODMIOTU  : z T_CEIDG_GUS (P / F / LP ...); TYP_NIP: z T_ODY_KLIENT_LTM


-- ---------------------------------------------------------------------
-- KROK 2. Zasilenie
-- ---------------------------------------------------------------------
-- TRUNCATE TABLE WORK_POLAND.T_ODY_FIRMA_PROFIL;

INSERT INTO WORK_POLAND.T_ODY_FIRMA_PROFIL
    (NIP, NAZWA, ZATRUDNIENIE, ZRZUT_DB_BAZA, DATA_BADANIA, ZRODLO_ZATR, GRUPA_KAPITALOWA,
     DZIAL_PKD, ZRODLO_PKD, FORMA_WLASNOSCI, SEKTOR, ZRODLO_SEKTORA, FLAGA_PUBLIC,
     STATUS_REJESTR, KLASA_GUS, PIETRO_NR, PIETRO, PIETRO_ZRODLO, TYP_PODMIOTU, TYP_NIP,
     CZY_KLIENT)
WITH par AS (                                   -- parametr: ilu najwiekszych klientow bez
    SELECT 200 AS TOP_N_RECZNIE FROM dual       -- zatrudnienia uzupelniamy recznie (lista B w 04)
),
db AS (                                    -- DB_BAZA: 1 wiersz na NIP (D05);
    -- KEEP zostaje na wypadek dubli: bierzemy wiersz z wypelnionym zatrudnieniem
    SELECT REGEXP_REPLACE(d.NIP, '[^0-9]', '')                       AS NIP,
           MAX(d.ZATRUDNIENIE) KEEP (DENSE_RANK LAST ORDER BY
               CASE WHEN d.ZATRUDNIENIE IS NOT NULL THEN 1 ELSE 0 END,
               d.ROK_ZATRUDNIENIA NULLS FIRST)                       AS ZATRUDNIENIE,
           -- aktualnosc danych: data zrzutu DB_BAZA (01.01.2022 = duze firmy,
           -- 29.02.2024 = glownie male, 13.03.2026) i data badania (D17)
           MAX(SUBSTR(d.DB_BAZA, 1, 20)) KEEP (DENSE_RANK LAST ORDER BY
               CASE WHEN d.ZATRUDNIENIE IS NOT NULL THEN 1 ELSE 0 END,
               d.ROK_ZATRUDNIENIA NULLS FIRST)                       AS ZRZUT_DB_BAZA,
           MAX(SUBSTR(d.DATA_BADANIA, 1, 20)) KEEP (DENSE_RANK LAST ORDER BY
               CASE WHEN d.ZATRUDNIENIE IS NOT NULL THEN 1 ELSE 0 END,
               d.ROK_ZATRUDNIENIA NULLS FIRST)                       AS DATA_BADANIA,
           MAX(d.NAZWA_REJ) KEEP (DENSE_RANK LAST ORDER BY
               d.ROK_ZATRUDNIENIA NULLS FIRST)                       AS NAZWA,
           MAX(d.GRUPA_KAPITALOWA) KEEP (DENSE_RANK LAST ORDER BY
               d.ROK_ZATRUDNIENIA NULLS FIRST)                       AS GRUPA_KAPITALOWA,
           MAX(COALESCE(REGEXP_SUBSTR(d.DZIALPKD, '^[0-9]{2}'),
                        REGEXP_SUBSTR(d.PKD, '^[0-9]{2}'))) KEEP (DENSE_RANK LAST ORDER BY
               d.ROK_ZATRUDNIENIA NULLS FIRST)                       AS DZIAL_PKD
    FROM   WORK_POLAND.DB_BAZA d
    WHERE  LENGTH(REGEXP_REPLACE(d.NIP, '[^0-9]', '')) = 10
    GROUP  BY REGEXP_REPLACE(d.NIP, '[^0-9]', '')
),
kl AS (
    SELECT NIP, TYP_NIP, SALES_LTM FROM WORK_POLAND.T_ODY_KLIENT_LTM
),
nipy AS (
    SELECT NIP FROM db
    UNION
    SELECT NIP FROM kl
),
cg AS (                                         -- REGON / CEIDG (klucz: NIP, same cyfry)
    SELECT c.NIP, c.NAZWA, c.FORMA_WLASNOSCI, c.TYP_PODMIOTU,
           SUBSTR(REGEXP_REPLACE(c.PKD_KOD, '[^0-9]', ''), 1, 2)    AS DZIAL_PKD,
           CASE
               WHEN NVL(c.DELETION_FLAG, 'N') = 'Y'
                 OR c.DATA_SKRESLENIA  IS NOT NULL
                 OR c.DATA_ZAKONCZENIA IS NOT NULL                   THEN 'ZAKONCZONA'
               WHEN c.DATA_ZAWIESZENIA IS NOT NULL
                AND (c.DATA_WZNAWIENIA IS NULL
                     OR c.DATA_WZNAWIENIA < c.DATA_ZAWIESZENIA)      THEN 'ZAWIESZONA'
               ELSE                                                       'AKTYWNA'
           END                                                       AS STATUS_REJESTR
    FROM   WORK_POLAND.T_CEIDG_GUS c
),
kpp AS (                                        -- Katalog Podmiotow Publicznych
    SELECT LPAD(TO_CHAR(k.NIP), 10, '0')                             AS NIP,
           MAX(k.NAZWA_PODMIOTU)                                     AS NAZWA,
           MAX(k.FORMA_WLASNOSCI)                                    AS FORMA_WLASNOSCI,
           MAX(REGEXP_SUBSTR(k.KOD_PKD, '^[0-9]{2}'))                AS DZIAL_PKD,
           MAX(CASE WHEN REGEXP_SUBSTR(k.KOD_PKD, '^[0-9]{2}')
                         IN ('84','85','86','87','88','90','91','92','93')
                    THEN 1 ELSE 0 END)                               AS KPP_INSTYTUCJA
    FROM   WORK_POLAND.T_KATALOG_PODMIOTOW_PUBLICZNYCH k
    WHERE  k.NIP IS NOT NULL
      AND  k.KATEGORIA_PODMIOTU = 'PUBLIC'                           -- sprawdzic: KONTROLA 3
      AND  NVL(k.STATUS, 'ACTIVE') = 'ACTIVE'
    GROUP  BY LPAD(TO_CHAR(k.NIP), 10, '0')
),
ko AS (                                         -- korekty reczne
    SELECT NIP,
           MAX(ZATRUDNIENIE) AS ZATRUDNIENIE,
           MAX(FLAGA_PUBLIC) AS FLAGA_PUBLIC
    FROM   WORK_POLAND.T_ODY_KOREKTA_FIRMY
    GROUP  BY NIP
),
baza AS (
    SELECT n.NIP,
           COALESCE(cg.NAZWA, db.NAZWA, kpp.NAZWA)                   AS NAZWA,
           NVL(ko.ZATRUDNIENIE, db.ZATRUDNIENIE)                     AS ZATRUDNIENIE,
           db.ZRZUT_DB_BAZA,
           db.DATA_BADANIA,
           CASE WHEN ko.ZATRUDNIENIE IS NOT NULL THEN 'KOREKTA'
                WHEN db.ZATRUDNIENIE IS NOT NULL THEN 'DB_BAZA' END  AS ZRODLO_ZATR,
           db.GRUPA_KAPITALOWA,
           COALESCE(cg.DZIAL_PKD, kpp.DZIAL_PKD, db.DZIAL_PKD)       AS DZIAL_PKD,
           CASE WHEN cg.DZIAL_PKD  IS NOT NULL THEN 'CEIDG_GUS'
                WHEN kpp.DZIAL_PKD IS NOT NULL THEN 'KPP'
                WHEN db.DZIAL_PKD  IS NOT NULL THEN 'DB_BAZA' END    AS ZRODLO_PKD,
           COALESCE(cg.FORMA_WLASNOSCI, kpp.FORMA_WLASNOSCI)         AS FORMA_WLASNOSCI,
           CASE
               WHEN kpp.NIP IS NOT NULL                                  THEN 'PUBLICZNY'
               -- forma wlasnosci w T_CEIDG_GUS jest tekstem bez kodu (sprawdzone 2026-11-26, D03):
               -- Skarb Panstwa, panstwowe osoby prawne, JST, mieszana "w sektorze publicznym"
               -- i "miedzy sektorami z przewaga sektora publicznego"; kod 1xx - gdyby byl z kodem
               WHEN REGEXP_LIKE(UPPER(cg.FORMA_WLASNOSCI),
                    '^ *1[0-9]{2}|SKARBU PA.{1,2}STWA|PA.{1,2}STWOWYCH OS.{1,2}B PRAWNYCH|SAMORZ.{1,2}DU TERYTORIALNEGO|W SEKTORZE PUBLICZNYM|SEKTORAMI Z PRZEWAG.{1,2} W.{1,2}ASNO.{1,2}CI SEKTORA PUBLICZNEGO')
                                                                         THEN 'PUBLICZNY'
               WHEN cg.FORMA_WLASNOSCI IS NOT NULL                       THEN 'PRYWATNY'
               WHEN cg.TYP_PODMIOTU = 'F'                                THEN 'PRYWATNY'   -- osoba fizyczna (CEIDG)
               ELSE                                                           'NIEZNANY'
           END                                                       AS SEKTOR,
           CASE
               WHEN kpp.NIP IS NOT NULL                                  THEN 'KPP'
               WHEN cg.FORMA_WLASNOSCI IS NOT NULL OR cg.TYP_PODMIOTU = 'F' THEN 'CEIDG_GUS'
           END                                                       AS ZRODLO_SEKTORA,
           ko.FLAGA_PUBLIC                                           AS FLAGA_PUBLIC_KOREKTA,
           NVL(kpp.KPP_INSTYTUCJA, 0)                                AS KPP_INSTYTUCJA,
           NVL(cg.STATUS_REJESTR, 'BRAK')                            AS STATUS_REJESTR,
           cg.TYP_PODMIOTU,
           kl.TYP_NIP,
           kl.SALES_LTM,
           CASE WHEN kl.NIP IS NOT NULL THEN 'T' ELSE 'N' END        AS CZY_KLIENT
    FROM   nipy n
    LEFT JOIN db  ON db.NIP  = n.NIP
    LEFT JOIN cg  ON cg.NIP  = n.NIP
    LEFT JOIN kpp ON kpp.NIP = n.NIP
    LEFT JOIN ko  ON ko.NIP  = n.NIP
    LEFT JOIN kl  ON kl.NIP  = n.NIP
),
flaga AS (
    SELECT b.*,
           CASE
               WHEN b.FLAGA_PUBLIC_KOREKTA IN ('T', 'N')                      THEN b.FLAGA_PUBLIC_KOREKTA
               WHEN b.SEKTOR = 'PUBLICZNY'
                AND (b.DZIAL_PKD IN ('84','85','86','87','88','90','91','92','93')
                     OR b.KPP_INSTYTUCJA = 1)                                 THEN 'T'
               ELSE                                                                'N'
           END                                                       AS FLAGA_PUBLIC
    FROM   baza b
),
ranking AS (                                    -- klienci-spolki bez zatrudnienia: ranking wg sprzedazy
    SELECT f.*,
           CASE WHEN f.CZY_KLIENT = 'T'
                 AND f.ZATRUDNIENIE IS NULL
                 AND f.FLAGA_PUBLIC = 'N'
                 AND NVL(f.TYP_NIP, 'NIP') IN ('NIP', 'GRUPA_VAT')
                 AND NVL(f.TYP_PODMIOTU, '-') <> 'F'
                THEN ROW_NUMBER() OVER (
                         PARTITION BY CASE WHEN f.CZY_KLIENT = 'T'
                                            AND f.ZATRUDNIENIE IS NULL
                                            AND f.FLAGA_PUBLIC = 'N'
                                            AND NVL(f.TYP_NIP, 'NIP') IN ('NIP', 'GRUPA_VAT')
                                            AND NVL(f.TYP_PODMIOTU, '-') <> 'F'
                                           THEN 1 END
                         ORDER BY f.SALES_LTM DESC NULLS LAST, f.NIP)
           END                                                       AS RN_BEZ_ZATR
    FROM   flaga f
),
pietro AS (
    SELECT r.*,
           CASE
               WHEN r.ZATRUDNIENIE IS NULL  THEN NULL
               WHEN r.ZATRUDNIENIE < 10     THEN '0-9'
               WHEN r.ZATRUDNIENIE < 50     THEN '10-49'
               WHEN r.ZATRUDNIENIE < 250    THEN '50-249'
               WHEN r.ZATRUDNIENIE < 1000   THEN '250-999'
               ELSE                              '1000+'
           END                                                       AS KLASA_GUS,
           CASE
               WHEN NVL(r.TYP_NIP, 'NIP') IN ('ZAGRANICZNY', 'NIE_10_CYFR') THEN 98
               WHEN r.FLAGA_PUBLIC = 'T'                                     THEN 6
               WHEN r.ZATRUDNIENIE IS NOT NULL
                    THEN (SELECT MIN(pr.PIETRO_NR)
                          FROM   WORK_POLAND.T_ODY_PIRAMIDA_PROGI pr
                          WHERE  pr.PIETRO_NR BETWEEN 1 AND 5
                            AND  r.ZATRUDNIENIE >= pr.ZATR_OD
                            AND  r.ZATRUDNIENIE <= NVL(pr.ZATR_DO, r.ZATRUDNIENIE))
               WHEN r.CZY_KLIENT = 'N'                                       THEN 99
               WHEN r.TYP_PODMIOTU = 'F'                                     THEN 1
               WHEN r.RN_BEZ_ZATR > (SELECT TOP_N_RECZNIE FROM par)          THEN 1
               ELSE                                                               99
           END                                                       AS PIETRO_NR,
           CASE
               WHEN NVL(r.TYP_NIP, 'NIP') IN ('ZAGRANICZNY', 'NIE_10_CYFR') THEN 'ZAGRANICZNY'
               WHEN r.FLAGA_PUBLIC = 'T'                                     THEN 'PUBLIC'
               WHEN r.ZATRUDNIENIE IS NOT NULL                               THEN 'ZATRUDNIENIE'
               WHEN r.CZY_KLIENT = 'N'                                       THEN 'BRAK_ZATRUDNIENIA'
               WHEN r.TYP_PODMIOTU = 'F'                                     THEN 'SZACUNEK_OSOBA_FIZYCZNA'
               WHEN r.RN_BEZ_ZATR > (SELECT TOP_N_RECZNIE FROM par)          THEN 'SZACUNEK_MALA_SPRZEDAZ'
               ELSE                                                               'DO_UZUPELNIENIA'
           END                                                       AS PIETRO_ZRODLO
    FROM   ranking r
)
SELECT p.NIP, SUBSTR(p.NAZWA, 1, 1000), p.ZATRUDNIENIE, p.ZRZUT_DB_BAZA, p.DATA_BADANIA, p.ZRODLO_ZATR,
       p.GRUPA_KAPITALOWA, p.DZIAL_PKD, p.ZRODLO_PKD, p.FORMA_WLASNOSCI, p.SEKTOR,
       p.ZRODLO_SEKTORA, p.FLAGA_PUBLIC, p.STATUS_REJESTR, p.KLASA_GUS,
       p.PIETRO_NR, pr.PIETRO, p.PIETRO_ZRODLO, p.TYP_PODMIOTU, p.TYP_NIP, p.CZY_KLIENT
FROM   pietro p
LEFT JOIN WORK_POLAND.T_ODY_PIRAMIDA_PROGI pr
       ON pr.PIETRO_NR = p.PIETRO_NR;

COMMIT;


-- ---------------------------------------------------------------------
-- KONTROLA 1: rozklad na pietra - rynek (DB_BAZA) i nasi klienci
-- ---------------------------------------------------------------------
SELECT PIETRO_NR, PIETRO,
       COUNT(*)                                                         AS FIRMY_PROFIL,
       SUM(CASE WHEN CZY_KLIENT = 'T' THEN 1 ELSE 0 END)                AS W_TYM_KLIENCI,
       SUM(CASE WHEN STATUS_REJESTR IN ('ZAKONCZONA', 'ZAWIESZONA')
                THEN 1 ELSE 0 END)                                      AS ZAKONCZONE_ZAWIESZONE,
       SUM(CASE WHEN ZRODLO_ZATR = 'KOREKTA' THEN 1 ELSE 0 END)         AS Z_KOREKTA
FROM   WORK_POLAND.T_ODY_FIRMA_PROFIL
GROUP  BY PIETRO_NR, PIETRO
ORDER  BY PIETRO_NR;


-- ---------------------------------------------------------------------
-- KONTROLA 1b: NASI klienci wg zrodla pietra - ile piramidy to szacunek
-- i ile czeka na uzupelnienie (DO_UZUPELNIENIA -> lista B / C w 04)
-- ---------------------------------------------------------------------
SELECT p.PIETRO_ZRODLO, p.PIETRO,
       COUNT(*)                                                         AS KLIENCI,
       ROUND(RATIO_TO_REPORT(SUM(k.SALES_LTM)) OVER () * 100, 2)        AS PCT_SPRZEDAZY
FROM   WORK_POLAND.T_ODY_KLIENT_LTM k
JOIN   WORK_POLAND.T_ODY_FIRMA_PROFIL p ON p.NIP = k.NIP
GROUP  BY p.PIETRO_ZRODLO, p.PIETRO
ORDER  BY p.PIETRO_ZRODLO, p.PIETRO;


-- ---------------------------------------------------------------------
-- KONTROLA 2: forma wlasnosci -> sektor. Sprawdzic, czy kazda forma
-- trafila do wlasciwego sektora (Skarb Panstwa / panstwowe osoby prawne /
-- JST / mieszane z przewaga publicznej = publiczny). Bledy poprawiamy
-- w CASE w kroku 2.
-- ---------------------------------------------------------------------
SELECT FORMA_WLASNOSCI, SEKTOR, ZRODLO_SEKTORA,
       COUNT(*)                                                         AS FIRMY,
       SUM(CASE WHEN CZY_KLIENT = 'T' THEN 1 ELSE 0 END)                AS KLIENCI
FROM   WORK_POLAND.T_ODY_FIRMA_PROFIL
GROUP  BY FORMA_WLASNOSCI, SEKTOR, ZRODLO_SEKTORA
ORDER  BY FIRMY DESC;


-- ---------------------------------------------------------------------
-- KONTROLA 3: wartosci w Katalogu Podmiotow Publicznych (czy filtr
-- KATEGORIA_PODMIOTU = 'PUBLIC' i STATUS = 'ACTIVE' jest wlasciwy)
-- ---------------------------------------------------------------------
SELECT KATEGORIA_PODMIOTU, STATUS,
       COUNT(*)            AS PODMIOTY,
       COUNT(NIP)          AS Z_NIP,
       COUNT(DISTINCT NIP) AS NIP_UNIKALNE
FROM   WORK_POLAND.T_KATALOG_PODMIOTOW_PUBLICZNYCH
GROUP  BY KATEGORIA_PODMIOTU, STATUS
ORDER  BY PODMIOTY DESC;


-- ---------------------------------------------------------------------
-- KONTROLA 4: flaga Public u naszych klientow vs przypisanie w sprzedazy
-- (typ i region glownego SOLDTO). Klienci regionu PUBLIC z flaga 'N'
-- i klienci z flaga 'T' poza regionem PUBLIC -> do przegladu (KONTROLA 5).
-- ---------------------------------------------------------------------
SELECT p.FLAGA_PUBLIC,
       NVL(k.SALES_FORCE_TYPE_CODE, '-')                                AS SALES_FORCE_TYPE,
       NVL(k.SALES_FORCE_REGION, '-')                                   AS SALES_FORCE_REGION,
       COUNT(*)                                                         AS KLIENCI,
       ROUND(SUM(k.SALES_LTM))                                          AS SALES_LTM
FROM   WORK_POLAND.T_ODY_KLIENT_LTM k
JOIN   WORK_POLAND.T_ODY_FIRMA_PROFIL p ON p.NIP = k.NIP
GROUP  BY p.FLAGA_PUBLIC, NVL(k.SALES_FORCE_TYPE_CODE, '-'), NVL(k.SALES_FORCE_REGION, '-')
ORDER  BY SALES_LTM DESC;


-- ---------------------------------------------------------------------
-- KONTROLA 5: klienci z regionu sprzedazy "PUBLIC", ktorzy NIE dostali
-- flagi Public (top 200 wg sprzedazy). Jesli to instytucje publiczne
-- -> poprawic regule albo wpisac korekte FLAGA_PUBLIC = 'T'.
-- ---------------------------------------------------------------------
SELECT k.NIP, p.NAZWA, p.DZIAL_PKD, p.SEKTOR, p.FORMA_WLASNOSCI,
       k.SALES_FORCE_REGION, ROUND(k.SALES_LTM) AS SALES_LTM
FROM   WORK_POLAND.T_ODY_KLIENT_LTM k
JOIN   WORK_POLAND.T_ODY_FIRMA_PROFIL p ON p.NIP = k.NIP
WHERE  UPPER(k.SALES_FORCE_REGION) LIKE '%PUBLI%'
  AND  p.FLAGA_PUBLIC = 'N'
ORDER  BY k.SALES_LTM DESC
FETCH FIRST 200 ROWS ONLY;


-- ---------------------------------------------------------------------
-- KONTROLA 6: pokrycie naszych klientow zatrudnieniem (poza Public)
-- ---------------------------------------------------------------------
SELECT CASE WHEN p.ZATRUDNIENIE IS NOT NULL THEN 'Z_ZATRUDNIENIEM'
            ELSE 'BEZ_ZATRUDNIENIA' END                                 AS GRUPA,
       COUNT(*)                                                         AS KLIENCI,
       ROUND(SUM(k.SALES_LTM))                                          AS SALES_LTM,
       ROUND(RATIO_TO_REPORT(SUM(k.SALES_LTM)) OVER () * 100, 1)        AS PCT_SALES
FROM   WORK_POLAND.T_ODY_KLIENT_LTM k
JOIN   WORK_POLAND.T_ODY_FIRMA_PROFIL p ON p.NIP = k.NIP
WHERE  p.FLAGA_PUBLIC = 'N'
GROUP  BY CASE WHEN p.ZATRUDNIENIE IS NOT NULL THEN 'Z_ZATRUDNIENIEM'
               ELSE 'BEZ_ZATRUDNIENIA' END;


-- ---------------------------------------------------------------------
-- KONTROLA 7: z ktorego zrzutu DB_BAZA jest zatrudnienie (aktualnosc danych).
-- D17: duze firmy sa glownie w zrzucie 01.01.2022 - zatrudnienie sprzed
-- ok. 4 lat; w 04 weryfikujemy je ze sprawozdaniami w eKRS.
-- (ROK_ZATRUDNIENIA nie mowi o aktualnosci - D06, nie uzywamy.)
-- ---------------------------------------------------------------------
SELECT NVL(ZRZUT_DB_BAZA, '(brak)')                                     AS ZRZUT_DB_BAZA,
       COUNT(*)                                                         AS FIRMY,
       SUM(CASE WHEN CZY_KLIENT = 'T' THEN 1 ELSE 0 END)                AS KLIENCI,
       SUM(CASE WHEN ZATRUDNIENIE >= 1000 THEN 1 ELSE 0 END)            AS FIRMY_1000_PLUS
FROM   WORK_POLAND.T_ODY_FIRMA_PROFIL
WHERE  ZRODLO_ZATR = 'DB_BAZA'
GROUP  BY NVL(ZRZUT_DB_BAZA, '(brak)')
ORDER  BY FIRMY DESC;
