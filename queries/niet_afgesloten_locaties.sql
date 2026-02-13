/*
=================================================================================
Titel       : Controle op actieve hoofdlocatie van cliënten uit zorg 
Doel        : Snel signaleren van cliënten uit zorg waarbij de locatie nog niet is beëindigen
Auteur      : Peter van Bussel (Laverhof)
================================================================================

Korte uitleg van de logica
   - Met ROW_NUMBER() worden alle zorg- en locatie‑toewijzingen per cliënt
     gerangschikt op einddatum, waarbij NULL wordt gezien als "nog actief".
	 Door ISNULL(dateEnd, '9999-12-31') wordt NULL gezien als de meest recente einddatum.
   - Alleen de records met rangnummer 1 (de meest recente) worden geselecteerd.
   - Deze worden gekoppeld aan cliënt- en locatiegegevens.
   - Alleen zorgtoewijzingen met een einddatum en locatie‑toewijzingen zonder
     einddatum worden meegenomen.

Aandachtspunten
   - De begin‑ en einddatumfilters zorgen dat alleen relevante periodes worden meegenomen.
   - De query filtert expliciet op locationType = 'MAIN'. Nevenlocaties worden niet meegenomen.
   - Eindfilters bepalen de uiteindelijke dataset
       + ca.dateEnd IS NOT NULL → alleen afgesloten zorgtoewijzingen.
	   + la.endDate IS NULL → alleen actieve hoofdlocaties.
	   + l.name NOT LIKE '%Wacht%' → Wachtlijstlocaties zij
  Deze combinatie bepaalt welke cliënten uiteindelijk zichtbaar zijn.

	@begin     - cutoff begin date for active care and location allocations
	             Supports:
                  +  ''                → no filtering  
                  +  '2025'            → single year  
	@eind     - cutoff end date for active care and location allocations
	            Supports:
                  +  ''                → no filtering  
                  +  '2025-12-31'      → single date
				  +  CAST(GETDATE() as DATE) → today
	@locatie  - locaties names excluded
				    Supports:
			           + NULL               → no filter
			           + ''                 → no filter
			           + one value (e.g. '%Wachtlijst%')
			           + multiple values (comma-separated)
			           + wildcards inside each value 
*/
DECLARE @begin DATE = '2000-01-01';
DECLARE @eind DATE = CAST(GETDATE() as DATE);
DECLARE @locatie NVARCHAR(200) = 'Wachtlijst';

/*
 CTE 1: LatestCare
 Selects ALL care_allocations but assigns a row number per client.
 The row with rn = 1 is the one with the latest dateEnd.
 NULL dateEnd is treated as '9999-12-31', meaning "still active".
*/
WITH LatestCare AS (
    SELECT
        ca.*,
        ROW_NUMBER() OVER (
            PARTITION BY ca.clientObjectId
            ORDER BY ISNULL(ca.dateEnd, '9999-12-31') DESC
        ) AS rn
    FROM care_allocations ca
    WHERE ca.dateBegin <= @eind
      AND ISNULL(ca.dateEnd, '9999-12-31') >= @begin
),

/*
 CTE 2: LatestLocation
 Same logic as LatestCare, but for MAIN location assignments.
 Ensures only the most recent MAIN location per client is kept.
*/
LatestLocation AS (
    SELECT
        la.*,
        ROW_NUMBER() OVER (
            PARTITION BY la.clientObjectId
            ORDER BY ISNULL(la.endDate, '9999-12-31') DESC
        ) AS rn
    FROM location_assignments la
    WHERE la.beginDate <= @eind
      AND ISNULL(la.endDate, '9999-12-31') >= @begin
      AND la.locationType = 'MAIN'
)

/*
 Final SELECT
 Joins the latest care allocation and latest MAIN location
 for each client, plus client and location details.
*/
SELECT 
    ca.clientObjectId AS clientId,
    c.identificationNo AS client_nummer,
    c.name AS name,
    c.dateOfBirth AS geboortedatum,
    c.deathDate AS overlijdensdatum,
    CAST(ca.dateBegin AS DATE) AS legitimatie_begin,
    CAST(ca.dateEnd AS DATE) AS legitimatie_eind,
    l.name AS locatie,
    CAST(la.beginDate AS DATE) AS locatie_begin,
    CAST(la.endDate AS DATE) AS locatie_eind
FROM LatestCare ca
JOIN LatestLocation la 
    ON la.clientObjectId = ca.clientObjectId
LEFT JOIN clients c 
    ON c.objectId = ca.clientObjectId
LEFT JOIN locations l 
    ON l.objectId = la.locationObjectId

/*
 Filters:
   ca.rn = 1 → only the latest care allocation
   la.rn = 1 → only the latest MAIN location
   ca.dateEnd IS NOT NULL → exclude active care allocations
   la.endDate IS NULL → include only active MAIN locations
*/
WHERE ca.rn = 1
  AND la.rn = 1
  AND ca.dateEnd IS NOT NULL
  AND la.endDate IS NULL
  AND NOT EXISTS ( 
	  SELECT 1
	  FROM string_split(@locatie, ',') AS x 
	  WHERE l.name LIKE '%' + LTRIM(RTRIM(x.value)) + '%' 
    )
ORDER BY ca.dateEnd ASC;
