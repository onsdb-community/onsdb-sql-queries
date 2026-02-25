/*==============================================================================
  Titel:  Survey_Fact
  Doel:   De query levert een volledig en gestructureerd overzicht van alle vragen en antwoorden uit 
		  ingevulde vragenlijsten, inclusief volgorde, antwoordtype, scores en flexibele filtering op 
		  één of meerdere vragenlijst‑IDs. 
  Auteur: Martin-Hugo van Groenestijn (Vivent) en Peter van Bussel (Laverhof)
=================================================================================

Korte uitleg en logica: 
		- Haalt alle vragen en antwoorden op van ingevulde vragenlijsten.
		- Bepaalt de volgorde van vragen met ROW_NUMBER().
		- Verwerkt verschillende antwoordsoorten (meerkeuze, open, boolean).
		- Filtert op één of meerdere vragenlijst‑IDs, inclusief spaties en lege waarden.
		- Negeert antwoorden die effectief leeg of null zijn.
		- Gebruikt een CTE voor leesbaarheid en om duplicatie van CASE‑logica te vermijden.
		- Houdt scores en metadata zoals vraagtekst, type en bron bij.
		- Zie comments in de query

Aandachtspunten:
		- Antwoordlogica is complex: meerdere answer types → tekst, boolean, meerkeuze, fallback naar definitie.
	    - Filter op @vragenlijst is flexibel: ondersteunt NULL, lege string, één ID, meerdere ID’s, én verwijdert spaties.
	    - Volgorde van vragen wordt bepaald met ROW_NUMBER() op basis van VraagObjectId.
		- Door deze query te koppelen aan de query Survey_Dim kan een volledig rapport worden gemaakt
		  van de surveys met de basisinformatie en vragen en antwoorden. 


============================================================================================= */




/*==============================================================================
-- 1. Declare parameter
--    @vragenlijst can contain:
--      - NULL
--      - empty string ''
--      - a single value       → '14697'
--      - multiple values      → '14697,66811'
--      - values with spaces   → '14697, 66811 , 99999'
============================================================================================= */
DECLARE @vragenlijst VARCHAR(250) = '';


/*==============================================================================
-- 2. Normalize empty string to NULL
--    This ensures '' behaves the same as NULL.
============================================================================================= */
SET @vragenlijst = NULLIF(@vragenlijst, '');


/*==============================================================================
-- 3. CTE to clean up the main select logic
--    This step:
--      - centralizes joins
--      - loads all needed columns
--      - prepares base fields for later CASE logic
============================================================================================= */
WITH AnswerCTE AS (
    SELECT
        sr.objectid AS Ingevulde_Vragenlijst,
        sa.surveyresultobjectid,
        sa.text,
        sa.booleanAnswer,
        sq.objectId AS VraagObjectId,
        sq.text AS Vraag,
        sq.additionalInfo AS Aanvullende_Info_Bij_Vraag,
        sq.answertype,
        sad.definition AS Definitie,
        sad.score AS Score_Meerkeuze
    FROM survey_results sr
    LEFT JOIN survey_answers sa 
        ON sa.surveyresultobjectid = sr.objectid
    LEFT JOIN survey_answer_definitions sad 
        ON sad.objectid = sa.answerdefinitionobjectid
    LEFT JOIN survey_questions sq 
        ON sq.objectid = sa.questionobjectid
)

/*==============================================================================
-- 4. Final SELECT with computed fields
--    Includes:
--      - ROW_NUMBER for sorting questions
--      - Computed Antwoord
--      - Answer type labeling
--      - Filtering using cleaned @vragenlijst
============================================================================================= */
SELECT
    CAST(a.Ingevulde_Vragenlijst AS nvarchar(99)) AS Ingevulde_Vragenlijst,

    -- Create sequential order per completed questionnaire
    ROW_NUMBER() OVER (
        PARTITION BY a.surveyresultobjectid 
        ORDER BY a.VraagObjectId
    ) AS Sorteervolgorde_Vraag,

    a.Vraag,
    a.Aanvullende_Info_Bij_Vraag,

/*==============================================================================
    -- Compute Antwoord (only once!)
    -- Logic:
    --   1. Multiple‑choice with NULL text → use definition
    --   2. Boolean answers: TRUE → 'Ja'
    --   3. Otherwise return text
============================================================================================= */
    CASE  
        WHEN a.answertype IN (1,2) AND a.text IS NULL THEN a.Definitie
        WHEN a.booleanAnswer = 1 THEN 'Ja'
        ELSE a.text
    END AS Antwoord,

/*==============================================================================
    -- Categorize answer types
============================================================================================= */
    CASE  
        WHEN a.answertype IN (1,2) THEN 'Meerkeuze'
        ELSE 'Open/getal/datum/tijd'
    END AS Antwoord_Type,

    a.Score_Meerkeuze,
    'ONS' AS Bron

FROM AnswerCTE a

/*==============================================================================
-- 5. Remove NULL/empty answers from results
--    Same expression as in SELECT, but evaluated once here.
============================================================================================= */
WHERE  
    CASE  
        WHEN a.answertype IN (1,2) AND a.text IS NULL THEN a.Definitie
        WHEN a.booleanAnswer = 1 THEN 'Ja'
        ELSE a.text
    END IS NOT NULL


/*==============================================================================
-- 6. Filter on @vragenlijst
--
--    Behavior:
--      - When @vragenlijst is NULL → no filtering
--      - Supports:
--          '14697'
--          '14697,66811'
--          ' 14697 , 66811 '
--          '14697, , , 66811'
--
--    Implementation:
--      REPLACE removes all spaces
--      STRING_SPLIT tokenizes by comma
--      WHERE value <> '' removes empty tokens
============================================================================================= */
AND (
       @vragenlijst IS NULL
    OR a.Ingevulde_Vragenlijst IN (
          SELECT value
          FROM STRING_SPLIT(REPLACE(@vragenlijst, ' ', ''), ',')
          WHERE value <> ''
      )
);