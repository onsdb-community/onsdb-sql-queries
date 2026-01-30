/*
===============================================================================
Titel  : Apothekers met meest recente adres- en contactgegevens
Doel   : Geeft een lijst van alle zorgaanbieders in de categorie 'Apothekers'
         inclusief hun meest recente (geldige) adresgegevens en contactinfo.
Auteur : Chantal van Son (Odion)
===============================================================================

Korte uitleg van de logica
- Per apotheker wordt het meest recente adres geselecteerd (op basis van createdAt).
- Alleen adressen die vandaag geldig zijn en een ingevulde straat hebben, tellen mee.
- Apothekers zonder geldig adres blijven zichtbaar (adresvelden zijn dan NULL).
*/

WITH
    addr
    AS
    (
        SELECT
            cpa.careProviderObjectId,
            a.*,
            ROW_NUMBER() OVER (
            PARTITION BY cpa.careProviderObjectId
            ORDER BY a.createdAt DESC
        ) AS rn
        FROM care_provider_addresses cpa
            JOIN addresses a
            ON a.objectId = cpa.addressObjectId
        WHERE NULLIF(TRIM(a.street), '') IS NOT NULL
            AND a.beginDate <= GETDATE()
            AND (a.endDate >= GETDATE() OR a.endDate IS NULL)
    )
SELECT
    cp.fullName AS naam,
    a.street AS straatnaam,
    a.homeNumber AS huisnummer,
    a.homeNumberExtension AS huisnummer_toevoeging,
    a.zipcode AS postcode,
    a.city AS gemeente,
    a.telephoneNumber AS telefoonnummer,
    a.email
FROM care_providers cp
    JOIN care_provider_categories cpc
    ON cpc.objectId = cp.organisationCategoryId
        AND cpc.name = 'Apothekers'
    LEFT JOIN addr a
    ON a.careProviderObjectId = cp.objectId
        AND a.rn = 1;
