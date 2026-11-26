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
--                albo forma wlasnosci REGON 1xx (Skarb Panstwa, panstwowe osoby
--                prawne, JST) / mieszana z przewaga publicznej
-- FLAGA_PUBLIC : wariant B = SEKTOR PUBLICZNY i dzial 84-88 / 90-93
--                (administracja, edukacja, zdrowie, pomoc spoleczna, kultura);
--                korekta reczna ma pierwszenstwo
-- PIETRO       : Public -> 6; brak zatrudnienia -> 99; reszta wg T_ODY_PIRAMIDA_PROGI
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
     ROK_ZATRUDNIENIA  VARCHAR2(10),
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
     CZY_KLIENT        CHAR(1),
     DATA_WCZYTANIA    DATE           DEFAULT SYSDATE');
-- ZRODLO_ZATR   : DB_BAZA / KOREKTA
-- SEKTOR        : PUBLICZNY / PRYWATNY / NIEZNANY
-- STATUS_REJESTR: AKTYWNA / ZAWIESZONA / ZAKONCZONA / BRAK (NIP-u nie ma w T_CEIDG_GUS)


-- ---------------------------------------------------------------------
-- KROK 2. Zasilenie
-- ---------------------------------------------------------------------
-- TRUNCATE TABLE WORK_POLAND.T_ODY_FIRMA_PROFIL;

INSERT INTO WORK_POLAND.T_ODY_FIRMA_PROFIL
    (NIP, NAZWA, ZATRUDNIENIE, ROK_ZATRUDNIENIA, ZRODLO_ZATR, GRUPA_KAPITALOWA,
     DZIAL_PKD, ZRODLO_PKD, FORMA_WLASNOSCI, SEKTOR, ZRODLO_SEKTORA, FLAGA_PUBLIC,
     STATUS_REJESTR, KLASA_GUS, PIETRO_NR, PIETRO, CZY_KLIENT)
WITH db AS (                                    -- DB_BAZA: 1 wiersz na NIP
    SELECT REGEXP_REPLACE(d.NIP, '[^0-9]', '')                       AS NIP,
           -- ostatni rok, w ktorym zatrudnienie jest wypelnione
           MAX(d.ZATRUDNIENIE) KEEP (DENSE_RANK LAST ORDER BY
               CASE WHEN d.ZATRUDNIENIE IS NOT NULL THEN 1 ELSE 0 END,
               d.ROK_ZATRUDNIENIA NULLS FIRST)                       AS ZATRUDNIENIE,
           MAX(SUBSTR(d.ROK_ZATRUDNIENIA, 1, 10)) KEEP (DENSE_RANK LAST ORDER BY
               CASE WHEN d.ZATRUDNIENIE IS NOT NULL THEN 1 ELSE 0 END,
               d.ROK_ZATRUDNIENIA NULLS FIRST)                       AS ROK_ZATRUDNIENIA,
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
    SELECT NIP FROM WORK_POLAND.T_ODY_KLIENT_LTM
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
           CASE WHEN ko.ZATRUDNIENIE IS NULL THEN db.ROK_ZATRUDNIENIA END AS ROK_ZATRUDNIENIA,
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
               WHEN REGEXP_LIKE(cg.FORMA_WLASNOSCI, '^ *1')              THEN 'PUBLICZNY'  -- 111 / 112 / 113
               WHEN UPPER(cg.FORMA_WLASNOSCI) LIKE '%PRZEWAG%PUBLICZN%'  THEN 'PUBLICZNY'  -- mieszana, przewaga publ.
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
pietro AS (
    SELECT f.*,
           CASE
               WHEN f.ZATRUDNIENIE IS NULL  THEN NULL
               WHEN f.ZATRUDNIENIE < 10     THEN '0-9'
               WHEN f.ZATRUDNIENIE < 50     THEN '10-49'
               WHEN f.ZATRUDNIENIE < 250    THEN '50-249'
               WHEN f.ZATRUDNIENIE < 1000   THEN '250-999'
               ELSE                              '1000+'
           END                                                       AS KLASA_GUS,
           CASE
               WHEN f.FLAGA_PUBLIC = 'T'    THEN 6
               WHEN f.ZATRUDNIENIE IS NULL  THEN 99
               ELSE (SELECT MIN(pr.PIETRO_NR)
                     FROM   WORK_POLAND.T_ODY_PIRAMIDA_PROGI pr
                     WHERE  pr.PIETRO_NR BETWEEN 1 AND 5
                       AND  f.ZATRUDNIENIE >= pr.ZATR_OD
                       AND  f.ZATRUDNIENIE <= NVL(pr.ZATR_DO, f.ZATRUDNIENIE))
           END                                                       AS PIETRO_NR
    FROM   flaga f
)
SELECT p.NIP, SUBSTR(p.NAZWA, 1, 1000), p.ZATRUDNIENIE, p.ROK_ZATRUDNIENIA, p.ZRODLO_ZATR,
       p.GRUPA_KAPITALOWA, p.DZIAL_PKD, p.ZRODLO_PKD, p.FORMA_WLASNOSCI, p.SEKTOR,
       p.ZRODLO_SEKTORA, p.FLAGA_PUBLIC, p.STATUS_REJESTR, p.KLASA_GUS,
       p.PIETRO_NR, pr.PIETRO, p.CZY_KLIENT
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
-- KONTROLA 2: forma wlasnosci -> sektor. Sprawdzic, czy kazda forma
-- trafila do wlasciwego sektora (1xx = publiczny, 2xx = prywatny,
-- mieszane wg przewagi). Bledy poprawiamy w CASE w kroku 2.
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
-- KONTROLA 7: z ktorego roku jest zatrudnienie w DB_BAZA
-- (stare dane = ryzyko zlego pietra; ew. filtr roku w 05)
-- ---------------------------------------------------------------------
SELECT ROK_ZATRUDNIENIA,
       COUNT(*)                                                         AS FIRMY,
       SUM(CASE WHEN CZY_KLIENT = 'T' THEN 1 ELSE 0 END)                AS KLIENCI
FROM   WORK_POLAND.T_ODY_FIRMA_PROFIL
WHERE  ZRODLO_ZATR = 'DB_BAZA'
GROUP  BY ROK_ZATRUDNIENIA
ORDER  BY ROK_ZATRUDNIENIA DESC;
