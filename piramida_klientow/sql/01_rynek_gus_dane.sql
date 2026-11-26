SET DEFINE OFF;
-- =====================================================================
-- 01_rynek_gus_dane.sql   (PLIK GENEROWANY - nie edytowac recznie)
-- Generator: gus/szkielet_rynku_gus.py
-- Wariant Public: B_INSTYTUCJE
-- Dane rynku z GUS w klasach wielkosci GUS -> WORK_POLAND.T_ODY_RYNEK_GUS
-- (tabela z 00_setup.sql). Podzial na pietra piramidy: 05 + 06.
-- =====================================================================

-- TRUNCATE TABLE WORK_POLAND.T_ODY_RYNEK_GUS;   -- przy odswiezeniu

INSERT INTO WORK_POLAND.T_ODY_RYNEK_GUS (OKRES, ZRODLO, MIARA, GRUPA, KLASA_GUS, WARTOSC) VALUES ('2026-Q2', 'GUS: przedsiebiorstwa aktywne 2026-Q2, Tablica 2 (sekcje A-S bez O)', 'FIRMY_AKTYWNE', 'POZA_PUBLIC', '0-9', 2779281);
INSERT INTO WORK_POLAND.T_ODY_RYNEK_GUS (OKRES, ZRODLO, MIARA, GRUPA, KLASA_GUS, WARTOSC) VALUES ('2026-Q2', 'GUS: przedsiebiorstwa aktywne 2026-Q2, Tablica 2 (sekcje A-S bez O)', 'FIRMY_AKTYWNE', 'POZA_PUBLIC', '10-49', 95785);
INSERT INTO WORK_POLAND.T_ODY_RYNEK_GUS (OKRES, ZRODLO, MIARA, GRUPA, KLASA_GUS, WARTOSC) VALUES ('2026-Q2', 'GUS: przedsiebiorstwa aktywne 2026-Q2, Tablica 2 (sekcje A-S bez O)', 'FIRMY_AKTYWNE', 'POZA_PUBLIC', '50-249', 17245);
INSERT INTO WORK_POLAND.T_ODY_RYNEK_GUS (OKRES, ZRODLO, MIARA, GRUPA, KLASA_GUS, WARTOSC) VALUES ('2026-Q2', 'GUS: przedsiebiorstwa aktywne 2026-Q2, Tablica 2 (sekcje A-S bez O)', 'FIRMY_AKTYWNE', 'POZA_PUBLIC', '250+', 4170);
INSERT INTO WORK_POLAND.T_ODY_RYNEK_GUS (OKRES, ZRODLO, MIARA, GRUPA, KLASA_GUS, WARTOSC) VALUES ('2026-10', 'GUS REGON 2026-10, Tablica 1 (podmioty wg przewidywanej liczby pracujacych)', 'FIRMY_REGON', 'PUBLIC', '0-9', 29026);
INSERT INTO WORK_POLAND.T_ODY_RYNEK_GUS (OKRES, ZRODLO, MIARA, GRUPA, KLASA_GUS, WARTOSC) VALUES ('2026-06', 'GUS Pracujacy w gospodarce narodowej 2026-06, Tabl. 7 bez rolnikow indywidualnych, Public wg Tabl. 5, podzial na klasy = szacunek', 'PRACUJACY', 'PUBLIC', '0-9', 16838);
INSERT INTO WORK_POLAND.T_ODY_RYNEK_GUS (OKRES, ZRODLO, MIARA, GRUPA, KLASA_GUS, WARTOSC) VALUES ('2026-10', 'GUS REGON 2026-10, Tablica 1 (podmioty wg przewidywanej liczby pracujacych)', 'FIRMY_REGON', 'POZA_PUBLIC', '0-9', 5326492);
INSERT INTO WORK_POLAND.T_ODY_RYNEK_GUS (OKRES, ZRODLO, MIARA, GRUPA, KLASA_GUS, WARTOSC) VALUES ('2026-06', 'GUS Pracujacy w gospodarce narodowej 2026-06, Tabl. 7 bez rolnikow indywidualnych, Public wg Tabl. 5, podzial na klasy = szacunek', 'PRACUJACY', 'POZA_PUBLIC', '0-9', 3709518);
INSERT INTO WORK_POLAND.T_ODY_RYNEK_GUS (OKRES, ZRODLO, MIARA, GRUPA, KLASA_GUS, WARTOSC) VALUES ('2026-10', 'GUS REGON 2026-10, Tablica 1 (podmioty wg przewidywanej liczby pracujacych)', 'FIRMY_REGON', 'PUBLIC', '10-49', 22487);
INSERT INTO WORK_POLAND.T_ODY_RYNEK_GUS (OKRES, ZRODLO, MIARA, GRUPA, KLASA_GUS, WARTOSC) VALUES ('2026-06', 'GUS Pracujacy w gospodarce narodowej 2026-06, Tabl. 7 bez rolnikow indywidualnych, Public wg Tabl. 5, podzial na klasy = szacunek', 'PRACUJACY', 'PUBLIC', '10-49', 463867);
INSERT INTO WORK_POLAND.T_ODY_RYNEK_GUS (OKRES, ZRODLO, MIARA, GRUPA, KLASA_GUS, WARTOSC) VALUES ('2026-10', 'GUS REGON 2026-10, Tablica 1 (podmioty wg przewidywanej liczby pracujacych)', 'FIRMY_REGON', 'POZA_PUBLIC', '10-49', 103248);
INSERT INTO WORK_POLAND.T_ODY_RYNEK_GUS (OKRES, ZRODLO, MIARA, GRUPA, KLASA_GUS, WARTOSC) VALUES ('2026-06', 'GUS Pracujacy w gospodarce narodowej 2026-06, Tabl. 7 bez rolnikow indywidualnych, Public wg Tabl. 5, podzial na klasy = szacunek', 'PRACUJACY', 'POZA_PUBLIC', '10-49', 2115291);
INSERT INTO WORK_POLAND.T_ODY_RYNEK_GUS (OKRES, ZRODLO, MIARA, GRUPA, KLASA_GUS, WARTOSC) VALUES ('2026-10', 'GUS REGON 2026-10, Tablica 1 (podmioty wg przewidywanej liczby pracujacych)', 'FIRMY_REGON', 'PUBLIC', '50-249', 9663);
INSERT INTO WORK_POLAND.T_ODY_RYNEK_GUS (OKRES, ZRODLO, MIARA, GRUPA, KLASA_GUS, WARTOSC) VALUES ('2026-06', 'GUS Pracujacy w gospodarce narodowej 2026-06, Tabl. 7 bez rolnikow indywidualnych, Public wg Tabl. 5, podzial na klasy = szacunek', 'PRACUJACY', 'PUBLIC', '50-249', 1010290);
INSERT INTO WORK_POLAND.T_ODY_RYNEK_GUS (OKRES, ZRODLO, MIARA, GRUPA, KLASA_GUS, WARTOSC) VALUES ('2026-10', 'GUS REGON 2026-10, Tablica 1 (podmioty wg przewidywanej liczby pracujacych)', 'FIRMY_REGON', 'POZA_PUBLIC', '50-249', 16670);
INSERT INTO WORK_POLAND.T_ODY_RYNEK_GUS (OKRES, ZRODLO, MIARA, GRUPA, KLASA_GUS, WARTOSC) VALUES ('2026-06', 'GUS Pracujacy w gospodarce narodowej 2026-06, Tabl. 7 bez rolnikow indywidualnych, Public wg Tabl. 5, podzial na klasy = szacunek', 'PRACUJACY', 'POZA_PUBLIC', '50-249', 1878732);
INSERT INTO WORK_POLAND.T_ODY_RYNEK_GUS (OKRES, ZRODLO, MIARA, GRUPA, KLASA_GUS, WARTOSC) VALUES ('2026-10', 'GUS REGON 2026-10, Tablica 1 (podmioty wg przewidywanej liczby pracujacych)', 'FIRMY_REGON', 'PUBLIC', '250-999', 863);
INSERT INTO WORK_POLAND.T_ODY_RYNEK_GUS (OKRES, ZRODLO, MIARA, GRUPA, KLASA_GUS, WARTOSC) VALUES ('2026-06', 'GUS Pracujacy w gospodarce narodowej 2026-06, Tabl. 7 bez rolnikow indywidualnych, Public wg Tabl. 5, podzial na klasy = szacunek', 'PRACUJACY', 'PUBLIC', '250-999', 426549);
INSERT INTO WORK_POLAND.T_ODY_RYNEK_GUS (OKRES, ZRODLO, MIARA, GRUPA, KLASA_GUS, WARTOSC) VALUES ('2026-10', 'GUS REGON 2026-10, Tablica 1 (podmioty wg przewidywanej liczby pracujacych)', 'FIRMY_REGON', 'POZA_PUBLIC', '250-999', 2536);
INSERT INTO WORK_POLAND.T_ODY_RYNEK_GUS (OKRES, ZRODLO, MIARA, GRUPA, KLASA_GUS, WARTOSC) VALUES ('2026-06', 'GUS Pracujacy w gospodarce narodowej 2026-06, Tabl. 7 bez rolnikow indywidualnych, Public wg Tabl. 5, podzial na klasy = szacunek', 'PRACUJACY', 'POZA_PUBLIC', '250-999', 1655497);
INSERT INTO WORK_POLAND.T_ODY_RYNEK_GUS (OKRES, ZRODLO, MIARA, GRUPA, KLASA_GUS, WARTOSC) VALUES ('2026-10', 'GUS REGON 2026-10, Tablica 1 (podmioty wg przewidywanej liczby pracujacych)', 'FIRMY_REGON', 'PUBLIC', '1000+', 217);
INSERT INTO WORK_POLAND.T_ODY_RYNEK_GUS (OKRES, ZRODLO, MIARA, GRUPA, KLASA_GUS, WARTOSC) VALUES ('2026-06', 'GUS Pracujacy w gospodarce narodowej 2026-06, Tabl. 7 bez rolnikow indywidualnych, Public wg Tabl. 5, podzial na klasy = szacunek', 'PRACUJACY', 'PUBLIC', '1000+', 888218);
INSERT INTO WORK_POLAND.T_ODY_RYNEK_GUS (OKRES, ZRODLO, MIARA, GRUPA, KLASA_GUS, WARTOSC) VALUES ('2026-10', 'GUS REGON 2026-10, Tablica 1 (podmioty wg przewidywanej liczby pracujacych)', 'FIRMY_REGON', 'POZA_PUBLIC', '1000+', 521);
INSERT INTO WORK_POLAND.T_ODY_RYNEK_GUS (OKRES, ZRODLO, MIARA, GRUPA, KLASA_GUS, WARTOSC) VALUES ('2026-06', 'GUS Pracujacy w gospodarce narodowej 2026-06, Tabl. 7 bez rolnikow indywidualnych, Public wg Tabl. 5, podzial na klasy = szacunek', 'PRACUJACY', 'POZA_PUBLIC', '1000+', 1968204);

COMMIT;

-- KONTROLA: sumy per miara i grupa (porownac z README / dane/rynek_gus_do_halo.csv)
SELECT MIARA, GRUPA, OKRES, SUM(WARTOSC) AS WARTOSC, COUNT(*) AS LICZBA_KLAS
FROM   WORK_POLAND.T_ODY_RYNEK_GUS
GROUP  BY MIARA, GRUPA, OKRES
ORDER  BY MIARA, GRUPA;
