/*
===============================================================================
Titel       : Zorgregels (geschreven uren van medewerkers)
Doel        : Geeft een overzicht van geregistreerde aanwezigheid/uren van
             medewerkers, inclusief uursoort, kostenplaats, pooltype en
             fiatteringsstatus.
Auteur      : Chantal van Son (Odion)
===============================================================================

Korte uitleg van de logica
- Selecteert urenregistraties uit presence_logs.
- Verrijkt met medewerkergegevens, uursoort (activiteit) en kostenplaats.
- Voegt pooltype toe via de koppeling tussen teams en lst_pool_types.

Aandachtspunten
- De periode wordt bepaald via @startdatum en @einddatum; pas deze aan voor de gewenste selectie.
*/

DECLARE @startdatum DATE = '2025-01-01';
DECLARE @einddatum  DATE = '2025-12-31';

SELECT
    pl.startDate AS startdatum,
    pl.endDate AS einddatum,
    e.identificationNo AS medewerkernummer,
    TRIM(CONCAT(e.lastName, ', ', e.initials, ' ', e.prefix)) AS employee_name,
    a.description AS uursoort_beschrijving,
    a.identificationNo AS uursoort_code,
    t.identificationNo AS kostenplaatsnummer,
    t.name AS kostenplaats_naam,
    lpt.description AS pool_type,
    pl.clientId AS client_id,
    pl.removed AS is_verwijderd,
    pl.registration AS is_urenregistratie,
    pl.payment AS is_voor_verloning,
    pl.verified AS is_gefiatteerd,
    pl.verifiedDate AS fiatteringsdatum
FROM presence_logs pl
    LEFT JOIN employees e
    ON e.objectId = pl.employeeId
    LEFT JOIN teams t
    ON t.objectId = pl.costClusterObjectId
    LEFT JOIN lst_pool_types lpt
    ON lpt.code = t.poolcluster
    LEFT JOIN activities a
    ON pl.activityObjectId = a.objectId
WHERE pl.startDate <= @einddatum
    AND (pl.endDate >= @startdatum OR pl.endDate IS NULL);
