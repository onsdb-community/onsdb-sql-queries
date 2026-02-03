------------------------------------------------------------------------------------------
-- Clienten zonder eerste relatie / contactpersoon                                      --
--                                                                                      --
------------------------------------------------------------------------------------------



/*  
    @einddatum  – cutoff date for active care allocations  
    @ccFilter   – flexible filter for cost center identification numbers  
                  Supports:
                    ''                → no filtering  
                    '2100'            → single number  
                    '2100,2105,2110'  → list of numbers  
                    '2000-2200'       → numeric range  
*/
DECLARE @einddatum varchar(250);
DECLARE @ccFilter varchar(250) = '';   -- example value


/*  
    CTE: table_alle  
    Collects all clients with their cost center and location information  
    Only MAIN locations and active allocations are included  
*/
WITH table_alle AS
(
    SELECT
        ca.clientObjectId AS ca_clientObjectId,
        c.identificationNo AS c_nummer,
        c.name AS c_name,
        cc.identificationNo AS cc_identificationNo,
        cc.name AS cc_name
    FROM care_allocations ca
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
        (ca.dateEnd > @einddatum OR ca.dateEnd IS NULL)

        /* Only MAIN location assignments */
        AND la.locationType = 'MAIN'
        AND la.endDate IS NULL

        /* Only cost centers in the 2000–2999 range */
        AND TRY_CAST(cc.identificationNo AS INT) BETWEEN 2000 AND 2999

        /*  
            Flexible filtering for cc.identificationNo  
            - empty → no filter  
            - list → STRING_SPLIT  
            - range → PARSENAME trick  
        */
        AND (
                @ccFilter IS NULL
                OR @ccFilter = ''

                /* List of numbers (no dash present) */
                OR (
                    @ccFilter NOT LIKE '%-%'
                    AND cc.identificationNo IN (
                        SELECT value FROM STRING_SPLIT(@ccFilter, ',')
                    )
                )

                /* Range X-Y */
                OR (
                    @ccFilter LIKE '%-%'
                    AND TRY_CAST(cc.identificationNo AS INT) BETWEEN
                        TRY_CAST(PARSENAME(REPLACE(@ccFilter, '-', '.'), 2) AS INT)
                        AND TRY_CAST(PARSENAME(REPLACE(@ccFilter, '-', '.'), 1) AS INT)
                )
            )
)


/*  
    Final selection:  
    - Only clients without a primary contact person  
    - Grouping ensures unique rows  
*/
SELECT 
    ta.ca_clientObjectId AS clientId,
    ta.c_nummer AS clientNummer,
    ta.c_name AS clientnaam,
    ta.cc_identificationNo AS kostenplaats,
    ta.cc_name AS afdeling
FROM table_alle ta
WHERE NOT EXISTS (
    SELECT 1
    FROM relations r
    INNER JOIN nexus_client_contact_relation_types nccrt
        ON r.clientContactRelationTypeId = nccrt.objectId
    WHERE r.clientObjectId = ta.ca_clientObjectId
      AND nccrt.name = 'Eerste relatie / contactpersoon'
)
GROUP BY 
    ta.ca_clientObjectId,
    ta.c_nummer,
    ta.c_name,
    ta.cc_identificationNo,
    ta.cc_name
ORDER BY ta.ca_clientObjectId;
