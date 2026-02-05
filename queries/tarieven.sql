/*
===============================================================================
Titel       : Declaratietarieven export (product, debiteur, AGB en tarief-eenheid)
Doel        : Levert een overzicht van declaratie-tarieven met bijbehorende
             product-/legitimatiecodes, debiteurgegevens, AGB-code en tariefinfo
             (waarde, eenheid en geldigheidsperiode).
Auteur      : Chantal van Son (Odion)
===============================================================================

Korte uitleg van de logica
- Selecteert tariefregels uit declaration_tariffs en verrijkt met product- en financieringsinformatie.
- Verrijkt met debiteurtype, UZOVI-code en debiteurnummer via de debiteurkoppeling.
- Zet tarief-eenheden (NL omschrijving) om naar Engelstalige exportwaarden met een CASE-mapping.

Aandachtspunten
- De CASE-mapping op lst_export_units.description is afhankelijk van de exacte (Nederlandse) omschrijvingen; afwijkende of nieuwe waarden vallen terug op de originele description.
- priceInCents komt uit dt.tariffValue; interpretatie (centen vs. euro’s) is afhankelijk van de broninrichting.
- Er is geen filtering op datum/actieve tarieven; alle records uit declaration_tariffs worden meegenomen.
*/


SELECT
    -- product & legitimatiecodes
    ft.id AS [Importcode legitimatie],
    p.code AS [productCode of importcode],
    p.vektiscode,

    -- debiteur info
    lst_d.description AS debtorType,
    u.code AS debtorUzoviCode,
    d.debtorNumber AS debiteurnummer,

    --agb
    dt.careProviderCode AS agbCode,

    -- tarief: value
    dt.tariffValue AS priceInCents,

    -- tarief: unit - omzetten naar engels 
    CASE
        WHEN lst_eu.description = 'dagdeel' THEN 'DAY4HOURS'
        WHEN lst_eu.description = 'dag' THEN 'DAY8HOURS'
        WHEN lst_eu.description = '12 uren' THEN 'DAY12HOURS'
        WHEN lst_eu.description = '24 uren' THEN 'DAY24HOURS'
        WHEN lst_eu.description = 'uur' THEN 'HOUR'
        WHEN lst_eu.description = 'vijf minuten' THEN 'FIVEMINUTE'
        WHEN lst_eu.description = 'minuut' THEN 'MINUTE'
        WHEN lst_eu.description = 'kilometer' THEN 'KILOMETERS'
        WHEN lst_eu.description = 'stuk' THEN 'PIECE'
        WHEN lst_eu.description = 'week' THEN 'WEEK'
        WHEN lst_eu.description = 'maand' THEN 'MONTH'
        WHEN lst_eu.description = 'periode' THEN 'PERIOD'
        WHEN lst_eu.description = 'jaar' THEN 'YEAR'
        WHEN lst_eu.description = 'half jaar' THEN 'HALFYEAR'
        WHEN lst_eu.description = 'kwartaal' THEN 'QUARTER'
        WHEN lst_eu.description = 'kwartier' THEN 'FIFTEEN_MINUTES'
        WHEN lst_eu.description = 'euro' THEN 'EURO'
        ELSE lst_eu.description
    END AS priceUnit,

    -- tarief: datum
    dt.beginDate AS begindatum,
    dt.endDate AS eindDatum
FROM declaration_tariffs dt

    -- product & legitimatie informatie
    LEFT JOIN products p
    ON p.objectId=dt.productObjectId
    LEFT JOIN finance_types ft
    ON ft.objectId=p.financeTypeObjectId

    -- tarief-eenheid
    LEFT JOIN lst_export_units lst_eu
    ON lst_eu.code=dt.tariffUnit

    -- debiteuren (check op begin met 0)
    LEFT JOIN debtors d
    ON d.objectId=dt.debtorObjectId
    LEFT JOIN lst_debtor_types lst_d
    ON lst_d.code=d.type
    LEFT JOIN uzovis u
    ON u.objectId=d.uzoviObjectId;
