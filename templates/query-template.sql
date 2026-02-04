/*
===============================================================================
Titel       : korte, duidelijke titel
Doel        : wat levert deze query op en waarom bestaat hij?
Auteur      : naam (organisatie)
===============================================================================

Korte uitleg van de logica
- <bullet 1>
- <bullet 2>
- <bullet 3>

Aandachtspunten
- <bijvoorbeeld organisatiespecifieke filtering>

*/


SELECT
    -- voorbeeldkolommen
    t.kolom_1,
    t.kolom_2
FROM
    some_table t
WHERE
    t.kolom_1 IS NOT NULL
ORDER BY
    t.kolom_1;
