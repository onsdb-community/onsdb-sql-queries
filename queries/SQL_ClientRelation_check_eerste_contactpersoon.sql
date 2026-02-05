/*
=================================================================================
Titel       : Clienten zonder eerste relatie / contactpersoon
Doel        : Snel signaleren van cliënten zonder contactpersoon van bepaald type
Auteur      : Peter van Bussel (Laverhof)
================================================================================

Korte uitleg van de logica
- Selecteert cliënten met een actieve zorgtoewijzing na @einddatum en met een hoofdlocatie.
- Bepaald per cliënt de bijbehorende kostenplaats via de koppeling tusssen locaties en kostenplaatsen.
- Selecteert vervolgens alleen die cliënten die op @costcentre verblijven én GEEN relatie hebben van het type @relation.

Aandachtspunten
- De relatiecontrole moet worden gebaserd op de relatietype vastgelegde in nexus_client_contact_relation_types. Dit verschilt per organisatie, afhankelijk van de inrichting van contactpersonen.
- De query bevat organisatiespecifieke filters op kostenplaatsen (bijvoorbeeld numerieke reeksen). Pas deze filters aan op basis van de inrichting binnen de organisatie, of verwijder ze indien niet van toepassing.

 Er kan op kostenplaats, einddatum en relatietype worden gefilterd via flexibel filters (leeg, lijst of bereik). De query toont uitsluitend die cliënten die dan GEEN contactpersoon hebben op basis van de opgegeven criteria.  

    @enddate     - cutoff date for active care allocations
	              Supports:
                  +  ''                → no filtering  
                  +  '2025'            → single year  

    @costcentre  – flexible filter for costcentre identification numbers  
                   Supports:
                   + ''                → no filtering  
                   + '2100'            → single number  
                   + '2100,2105,2110'  → list of numbers  
                   + '2000-2200'       → numeric range  

	@relation   – flexible filter for nexus_client_contact_relation_types
				  Supports:
			      + NULL               → no filter
			      + ''                 → no filter
			      + one value (e.g. '%Eerste%')
			      + multiple values (comma-separated)
			      + wildcards inside each value
*/
DECLARE @enddate varchar(250) = '2025';
DECLARE @costcentre varchar(250) = '1000-3000';
DECLARE @relation varchar (250) = '%eerste%,%tweede%'; --null; --'%Wettelijk%'; --


/*  
    CTE: table_alle  
    Collects all clients with their cost center and location information  
    Only MAIN locations and active allocations are included  
*/
WITH table_alle AS
(
    SELECT
        ca.clientObjectId      AS clientId,
        c.identificationNo     AS clientNo,
        c.name                 AS clientName,
        cc.identificationNo    AS costcentreNo,
        cc.name                AS costcentreName
    FROM care_allocations as ca
    LEFT JOIN clients c
        ON c.objectId = ca.clientObjectId
    LEFT JOIN location_assignments la
        ON la.clientObjectId = ca.clientObjectId
    LEFT JOIN costcenter_assignments cca
        ON cca.unitobjectid = la.locationObjectId
    LEFT JOIN costcenters cc
        ON cc.objectId = cca.costcenterObjectid
    WHERE 
        /* Active care allocation */
        (ca.dateEnd > @enddate OR ca.dateEnd IS NULL)

        /* Only MAIN location assignments */
        AND la.locationType = 'MAIN'
        AND la.endDate IS NULL

        /*  
            Flexible filtering for cc.identificationNo  
            - empty → no filter  
            - list → STRING_SPLIT  
            - range → PARSENAME trick  
        */
        AND (
                @costcentre IS NULL
                OR @costcentre = ''

                /* List of numbers (no dash present) */
                OR (
                    @costcentre NOT LIKE '%-%'
                    AND cc.identificationNo IN (
                        SELECT value FROM STRING_SPLIT(@costcentre, ',')
                    )
                )

                /* Range X-Y */
                OR (
                    @costcentre LIKE '%-%'
                    AND TRY_CAST(cc.identificationNo AS INT) BETWEEN
                        TRY_CAST(PARSENAME(REPLACE(@costcentre, '-', '.'), 2) AS INT)
                        AND TRY_CAST(PARSENAME(REPLACE(@costcentre, '-', '.'), 1) AS INT)
                )
            )
)

/*  
    Final selection:  
    - Only clients without a primary contact person  
    - Grouping ensures unique rows  
*/
SELECT 
    ta.clientId          AS clientId,
    ta.clientNo          AS clientNo,
    ta.clientName        AS clientname,
    ta.costcentreNo      AS costcenterNo,
    ta.costcentreName    AS costcentreName
FROM table_alle ta
WHERE NOT EXISTS (
    SELECT 1
    FROM relations r
	INNER JOIN nexus_client_contact_relation_types AS nccrt 
		ON r.clientContactRelationTypeId = nccrt.objectId 
	WHERE r.clientObjectId = ta.clientId 
	 AND ( 
		 @relation IS NULL 
		 OR @relation = '' 
		 OR EXISTS ( 
			SELECT 1 FROM STRING_SPLIT(@relation, ',') AS rel 
			WHERE nccrt.name LIKE rel.value 
			)
		) 
	)

GROUP BY 
    ta.clientId,
    ta.clientNo,
    ta.clientName,
    ta.costcentreNo,
    ta.costcentreName
ORDER BY ta.clientId;

