/*
===============================================================================
Titel       : Recent gewijzigde bewindvoerders
Doel        : Geeft een overzicht van cliëntrelaties van het type
             'Bewindvoerder' die recent zijn aangemaakt of bijgewerkt.
Auteur      : Chantal van Son (Odion)
===============================================================================

Korte uitleg van de logica
- Selecteert relaties gekoppeld aan cliënten via clientObjectId.
- Verrijkt de relatie met cliëntnummer en omschrijving van het relatietype.
- Filtert op relatie 'Bewindvoerder' en op updatedAt vanaf begin vorige maand.

Aandachtspunten
- Voor andere relatietypen, pas filter aan.
- De datumfilter gebruikt updatedAt; ook oudere relaties met recente wijzigingen
  worden meegenomen.
*/

SELECT
    r.clientObjectId,
    c.identificationNo,
    lst.description AS relationType,
    r.firstName,
    r.birthName,
    r.initials,
    r.birthNamePrefix,
    r.name,
    r.prefix,
    r.organization,
    r.comments,
    r.createdAt,
    r.updatedAt
FROM relations r
    LEFT JOIN clients c ON c.objectId = r.clientObjectId
    LEFT JOIN lst_wlz_cod472s lst ON lst.code = r.type
WHERE lst.description = 'Bewindvoerder'
    -- alleen die zijn geupdated vanaf begin vorige maand tot nu
    AND r.updatedAt >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 1, 0)
ORDER BY updatedAt ASC;
