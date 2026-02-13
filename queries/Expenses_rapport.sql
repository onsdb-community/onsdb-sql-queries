/*==============================================================================
  Titel:  Expenses rapport
  Doel:   Overzicht van expenses binnen een periode met flexibele filtering op 
          expense-namen via meerdere LIKE-patronen.
  Auteur: Peter van Bussel (Laverhof)
=================================================================================

Korte uitleg van de logica 
   - De query haalt gegevens over onkostenvergoedingen van werknemers op voor een specifiek datumbereik.
   - Filtert deze op type op basis van flexibele trefwoordpatronen die door de gebruiker worden opgegeven. 
   - Aggregeert de totale gedeclareerde waarde per werknemer, per onkostentype en per kostenplaats.

Aandachtspunten
   - De begin? en einddatumfilters zorgen dat alleen relevante periodes worden meegenomen.
   - De query filtert op expensName. Dit is afhamkelijk van de inrichting door de organisatie.
*/

/* Declare date range parameters */

DECLARE @begindatum DATE = '2026-01-01';   -- Start date filter
DECLARE @einddatum DATE = '2026-01-31';    -- End date filter

/*
  Declare @expense as a comma-separated list of LIKE patterns.
  Examples:
     '%fiets%,%thuis%' ? filter on both patterns
     '%fiets%'         ? filter on one pattern
     NULL              ? no filtering on expense name
*/
DECLARE @expense VARCHAR(250) = '%fiets-lease%,%thuis%';  
-- SET @expense = NULL;  -- Uncomment to disable expense filtering


/* Main query */

SELECT 
     exp.employeeObjectId AS employeeId          -- Employee ID from expenses table
    ,empl.identificationNo AS employeeNo         -- Employee number
    ,empl.contractId AS contractNo               -- Contract number
    ,empl.Name AS employeeName                   -- Employee full name
    ,cc.identificationNo AS costscenterNo        -- Cost center number
    ,cc.name AS costcenter                       -- Cost center name
    ,et.objectId AS expenseType                  -- Expense type ID
    ,et.name AS expense                          -- Expense type name
    ,SUM(exp.amount) AS amount                   -- Total amount per grouping
FROM expenses exp

/* Join employees to link expense to employee details */
LEFT JOIN employees empl
    ON empl.objectId = exp.employeeObjectId

/* Join expense types to get the name and type of expense */
LEFT JOIN expense_types et
    ON et.objectId = exp.expenseTypeObjectId

/*  Join cost center assignments to find the cost center */
LEFT JOIN costcenter_assignments cca
    ON cca.clusterobjectid = exp.clusterObjectId

/*  Join cost centers to get cost center details */
LEFT JOIN costcenters cc
    ON cca.costcenterObjectid = cc.objectId

/*  WHERE clause: filters */
WHERE 1 = 1

/*  Filter on date range */
    AND CAST(exp.expenseDate AS DATE) BETWEEN @begindatum AND @einddatum

/*      Flexible multi-pattern filter using STRING_SPLIT:
        - If @expense IS NULL ? skip filtering
        - Otherwise ? match ANY pattern in the list
*/
    AND (
            @expense IS NULL
            OR EXISTS (
                SELECT 1
                FROM STRING_SPLIT(@expense, ',') s
                WHERE et.name LIKE s.value
            )
        )

/*  Grouping: ensures SUM(amount) is aggregated correctly */
GROUP BY
     exp.employeeObjectId 
    ,empl.identificationNo
    ,empl.contractId
    ,empl.Name
    ,et.objectId
    ,et.name
    ,cc.identificationNo
    ,cc.name;
