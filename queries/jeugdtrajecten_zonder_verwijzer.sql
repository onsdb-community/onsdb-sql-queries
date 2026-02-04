/*
===============================================================================
Titel       : Jeugdhulptrajecten zonder verwijzer
Doel        : Geeft een overzicht van jeugdhulptrajecten die (deels) actief zijn
             in de opgegeven periode en waarbij de verwijzer is vastgelegd als
             'Geen verwijzer', inclusief cliëntnummer en hulpvorm.
Auteur      : Chantal van Son (Odion)
===============================================================================

Korte uitleg van de logica
- Selecteert jeugdhulptrajecten uit cbsbj_jeugdhulps in gespecificeerde periode.
- Verrijkt per traject met omschrijving van hulpvorm, verwijzer en cliëntnummer.

Aandachtspunten
- Pas @einddatum en @startdatum aan voor gewenste periode.
- Pas @verwijzer aan voor gewenste verwijzer categorie.

*/


DECLARE @startdatum DATE = '2025-07-01';
DECLARE @einddatum  DATE = '2026-12-31';
DECLARE @verwijzer NVARCHAR(100) = 'Geen verwijzer';

SELECT
    j.clientObjectId,
    c.identificationNo AS clientnummer,
    h.description as hulpvorm,
    v.description as verwijzer,
    j.datumAanvang,
    j.datumBeeindiging
FROM cbsbj_jeugdhulps j
    LEFT JOIN cbsbj_hulpvormen h ON h.code = j.hulpvorm
    LEFT JOIN cbsbj_verwijzers v ON v.code = j.verwijzer
    LEFT JOIN clients c ON c.objectId=j.clientObjectId
WHERE j.datumAanvang <= @einddatum
    AND (j.datumBeeindiging >= @startdatum OR j.datumBeeindiging IS NULL)
    AND v.description =  @verwijzer;
