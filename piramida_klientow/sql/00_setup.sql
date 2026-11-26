SET DEFINE OFF;
-- =====================================================================
-- 00_setup.sql
-- Piramida klientow / Strategia Odyssey
--
-- Tabele pomocnicze (JEDNORAZOWO):
--   WORK_POLAND.T_ODY_PIRAMIDA_PROGI  - pietra piramidy i progi zatrudnienia
--   WORK_POLAND.T_ODY_KOREKTA_FIRMY   - reczne korekty po weryfikacji
--                                       (zatrudnienie, flaga Public)
--   WORK_POLAND.T_ODY_RYNEK_GUS       - dane rynku z GUS w klasach GUS
--                                       (wypelnia 01_rynek_gus_dane.sql)
--
-- Tabele tworzymy procedura WORK_SCHEMA_CREATE_TABLE (DB_KNOWLEDGE sek. 12).
--
-- KOLEJNOSC CALEGO PROJEKTU:
--   00 setup -> 01 dane GUS -> 02 klienci LTM -> 03 profil firm
--   -> 04 lista 4001+ (weryfikacja, korekty, ew. ponownie 03)
--   -> 05 proporcje -> 06 piramida
-- =====================================================================


-- ---------------------------------------------------------------------
-- KROK 1. Pietra piramidy
--   1-5 : pietra wg zatrudnienia (bez Public)
--   6   : PUBLIC - jeden blok, wariant B (decyzja 2026-11-26):
--         sektor publiczny w dzialach PKD 84-88, 90-93 (administracja,
--         edukacja, zdrowie i pomoc spoleczna, kultura); spolki panstwowe
--         i komunalne z innych dzialow sa w pietrach 1-5 wg wielkosci
--   99  : NIEPRZYPISANE - nasi klienci bez zatrudnienia w DB_BAZA
-- ---------------------------------------------------------------------
CALL WORK_POLAND.WORK_SCHEMA_CREATE_TABLE ('T_ODY_PIRAMIDA_PROGI',
    'PIETRO_NR       NUMBER(2)      NOT NULL,
     PIETRO          VARCHAR2(20)   NOT NULL,
     ZATR_OD         NUMBER,
     ZATR_DO         NUMBER,
     DATA_WCZYTANIA  DATE           DEFAULT SYSDATE');

INSERT INTO WORK_POLAND.T_ODY_PIRAMIDA_PROGI (PIETRO_NR, PIETRO, ZATR_OD, ZATR_DO) VALUES ( 1, '0-40',          0,   40);
INSERT INTO WORK_POLAND.T_ODY_PIRAMIDA_PROGI (PIETRO_NR, PIETRO, ZATR_OD, ZATR_DO) VALUES ( 2, '41-200',       41,  200);
INSERT INTO WORK_POLAND.T_ODY_PIRAMIDA_PROGI (PIETRO_NR, PIETRO, ZATR_OD, ZATR_DO) VALUES ( 3, '201-500',     201,  500);
INSERT INTO WORK_POLAND.T_ODY_PIRAMIDA_PROGI (PIETRO_NR, PIETRO, ZATR_OD, ZATR_DO) VALUES ( 4, '501-4000',    501, 4000);
INSERT INTO WORK_POLAND.T_ODY_PIRAMIDA_PROGI (PIETRO_NR, PIETRO, ZATR_OD, ZATR_DO) VALUES ( 5, '4001+',      4001, NULL);
INSERT INTO WORK_POLAND.T_ODY_PIRAMIDA_PROGI (PIETRO_NR, PIETRO, ZATR_OD, ZATR_DO) VALUES ( 6, 'PUBLIC',     NULL, NULL);
INSERT INTO WORK_POLAND.T_ODY_PIRAMIDA_PROGI (PIETRO_NR, PIETRO, ZATR_OD, ZATR_DO) VALUES (99, 'NIEPRZYPISANE', NULL, NULL);
COMMIT;


-- ---------------------------------------------------------------------
-- KROK 2. Korekty reczne (po weryfikacji listy z 04_lista_4001.sql
-- albo po przegladzie flagi Public w 03). Pusta na starcie.
--   ZATRUDNIENIE : nadpisuje DB_BAZA (np. DB_BAZA podaje zatrudnienie
--                  calej grupy kapitalowej przy kazdej spolce)
--   FLAGA_PUBLIC : 'T' / 'N' nadpisuje wyliczona flage (NULL = bez zmian)
-- Przyklad:
--   INSERT INTO WORK_POLAND.T_ODY_KOREKTA_FIRMY (NIP, ZATRUDNIENIE, FLAGA_PUBLIC, UWAGI)
--   VALUES ('1234567890', 2500, NULL, 'DB_BAZA = zatrudnienie grupy; spolka ok. 2500 wg KRS 2025');
-- ---------------------------------------------------------------------
CALL WORK_POLAND.WORK_SCHEMA_CREATE_TABLE ('T_ODY_KOREKTA_FIRMY',
    'NIP             VARCHAR2(20)   NOT NULL,
     ZATRUDNIENIE    NUMBER,
     FLAGA_PUBLIC    CHAR(1),
     UWAGI           VARCHAR2(800),
     DATA_WCZYTANIA  DATE           DEFAULT SYSDATE');


-- ---------------------------------------------------------------------
-- KROK 3. Dane rynku z GUS (wypelnia 01_rynek_gus_dane.sql)
--   MIARA    : FIRMY_AKTYWNE (przedsiebiorstwa aktywne, glowna liczba firm
--                             na rynku dla pieter 1-5),
--              FIRMY_REGON   (REGON: kontrola pieter 1-5, glowna dla Public),
--              PRACUJACY     (pracujacy w gospodarce narodowej)
--   GRUPA    : POZA_PUBLIC / PUBLIC
--   KLASA_GUS: 0-9 / 10-49 / 50-249 / 250-999 / 1000+ / 250+
-- ---------------------------------------------------------------------
CALL WORK_POLAND.WORK_SCHEMA_CREATE_TABLE ('T_ODY_RYNEK_GUS',
    'OKRES           VARCHAR2(10)   NOT NULL,
     ZRODLO          VARCHAR2(400),
     MIARA           VARCHAR2(20)   NOT NULL,
     GRUPA           VARCHAR2(20)   NOT NULL,
     KLASA_GUS       VARCHAR2(10)   NOT NULL,
     WARTOSC         NUMBER         NOT NULL,
     DATA_WCZYTANIA  DATE           DEFAULT SYSDATE');


-- KONTROLA
SELECT * FROM WORK_POLAND.T_ODY_PIRAMIDA_PROGI ORDER BY PIETRO_NR;
