/*
===============================================================================
Titel       : Huidige locaties van clienten in zorg
Doel        : Geeft een overzicht van alle actieve locatiekoppelingen voor
              clienten die momenteel in zorg zijn.
Auteur      : Chantal van Son (Odion) / Claude (OnsDB Skill)
===============================================================================

Logica
- Selecteer clienten met een actieve zorgopname (care_allocations):
    dateBegin <= vandaag EN (dateEnd IS NULL OF dateEnd > vandaag)
- Koppel de actieve locatietoekenningen (location_assignments):
    beginDate <= vandaag EN (endDate IS NULL OF endDate >= vandaag)
- Koppel de locatiegegevens (locations) die momenteel geldig zijn
- Sluit overleden clienten uit

Aandachtspunten
- locationType kan zijn: MAIN, STANDARD, MEDICINE, GGZ of WAITING
  Voeg eventueel een filter toe op locationType = 'MAIN' of residence = 1
  om alleen de primaire verblijfslocatie te tonen
- endDate in location_assignments is 'tot en met' (inclusief)

*/


SELECT
    c.objectId              AS client_id,
    c.identificationNo      AS clientnummer,
    c.givenName             AS roepnaam,
    c.firstName             AS voornaam,
    c.lastName              AS achternaam,
    c.dateOfBirth           AS geboortedatum,

    l.objectId              AS locatie_id,
    l.name                  AS locatie_naam,
    l.identificationNo      AS locatie_nummer,
    l.intramuralLocation    AS intramuraal,

    la.locationType         AS toekenning_type,
    la.residence            AS verblijfslocatie,
    la.beginDate            AS locatie_begin,
    la.endDate              AS locatie_eind,

    ca.dateBegin            AS zorg_begin,
    ca.dateEnd              AS zorg_eind

FROM clients AS c

    INNER JOIN care_allocations AS ca
    ON  ca.clientObjectId = c.objectId
        AND ca.dateBegin       <= GETDATE()
        AND (ca.dateEnd IS NULL OR ca.dateEnd > GETDATE())

    INNER JOIN location_assignments AS la
    ON  la.clientObjectId  = c.objectId
        AND la.beginDate       <= CAST(GETDATE() AS date)
        AND (la.endDate IS NULL OR la.endDate >= CAST(GETDATE() AS date))

    INNER JOIN locations AS l
    ON  l.objectId         = la.locationObjectId
        AND l.beginDate        <= CAST(GETDATE() AS date)
        AND (l.endDate IS NULL OR l.endDate >= CAST(GETDATE() AS date))

WHERE
    c.deathDate IS NULL

ORDER BY
    l.name,
    c.lastName,
    c.firstName;
