/*
===============================================================================
Titel       : Afspraken met meerdere cliënten (actief) per locatie
Doel        : Geeft een overzicht van agenda-afspraken met > 1 cliënt, inclusief
             locatie(naam) en basisafspraakgegevens, beperkt tot (nog) actieve
             afspraken.
Auteur      : Chantal van Son (Odion)
===============================================================================

Korte uitleg van de logica
- Bouwt per afspraak (event) één unieke locatiekoppeling op via uitnodigingen naar locaties.
- Telt per afspraak het aantal unieke cliënten via uitnodigingen en selecteert alleen afspraken met > 1 cliënt.
- Haalt afspraakdetails op uit agenda_events en verrijkt met locatienaam.

Aandachtspunten
- Filtert op afspraken met > 1 cliënt (HAVING + WHERE); dit is dubbel maar consistent bedoeld als harde selectie.
- Actieve selectie: e.validTo is NULL of ligt op/na GETDATE(); geplande/lopende afspraken blijven staan, verlopen afspraken vallen weg.
- LEFT JOIN op locatie, maar door de join op location_invites worden feitelijk alleen events met een locatie meegenomen.

*/

WITH
    -- één rij per (event, locatie)
    location_invites
    AS
    (
        SELECT DISTINCT
            i.eventObjectId         AS eventObjectId,
            ol.externalObjectId     AS locationExternalObjectId
        FROM agenda_invitations i
            JOIN onsagenda_locations ol
            ON ol.objectId = i.inviteeObjectId
    ),
    -- aantal cliënten per afspraak (alleen afspraken met > 1 cliënt)
    client_counts
    AS
    (
        SELECT
            i.eventObjectId                 AS eventObjectId,
            COUNT(DISTINCT oc.objectId)     AS aantal_clienten
        FROM agenda_invitations i
            JOIN onsagenda_clients oc
            ON oc.objectId = i.inviteeObjectId
        GROUP BY i.eventObjectId
        HAVING COUNT(DISTINCT oc.objectId) > 1
    )
SELECT
    e.objectId                      AS eventObjectId,
    li.locationExternalObjectId     AS locationObjectId,
    l.name                          AS locatie,
    e.name                          AS afspraaktitel,
    e.comment						AS commentaar,
    e.createdAt                     AS afspraak_aangemaakt,
    e.validFrom                     AS afspraak_start,
    e.validTo                       AS afspraak_einde,
    e.clientPresent                 AS client_aanwezig,
    cc.aantal_clienten              AS aantal_clienten
FROM agenda_events e
    LEFT JOIN location_invites li
    ON li.eventObjectId = e.objectId -- alleen events met locatie
    LEFT JOIN client_counts cc
    ON cc.eventObjectId = e.objectId -- alleen events met > 1 cliënt
    LEFT JOIN locations l
    ON l.objectId = li.locationExternalObjectId
WHERE aantal_clienten > 1
    AND (e.validTo IS NULL OR e.validTo >= GETDATE())
ORDER BY
    e.validFrom,
    e.objectId;
