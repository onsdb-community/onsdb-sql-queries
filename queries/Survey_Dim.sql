/*==============================================================================
  Titel:  Survey_Dim
  Doel:   Deze query bouwt één overzichtsregel per ingevulde vragenlijst (survey_result) met daarbij de relevante 
          basisinformatie gegevens (ID vragenlijst, Datum begonnen en datum voltooid, Status, etc.), gegevens cliënt
		  en medewerker, kostenplaats op moment van invullen, status, etc. 
  Auteur: Martin-Hugo van Groenestijn (Vivent en Peter van Bussel (Laverhof)
=================================================================================

Korte uitleg en logica: 
		Zie comments in de query

Aandachtspunten:
		De grootste aandachtspunten zijn de tijdsgeldigheid van kostenplaatsen, datumparsing in de CTE, 
		mogelijke vermenigvuldiging van rijen door survey_answer‑joins, en het OR‑filter op @vragenlijst
		— dat alles heeft direct impact op performance en datakwaliteit.
        — Door deze query te koppelen aan de query Survey_Fact waarin alle vragen en antwoorden staan kan een 
		  volledig rapport worden gemaakt van de surveys 
*/

-- Parameter to filter surveys by title using LIKE patterns.
-- Example values:
--   '%1.2%'             → single pattern
--   '%1.2%,%Incident%'  → multiple patterns, comma-separated

DECLARE @vragenlijst VARCHAR(250) = '%1.2%';


/* =============================================================================================
   CTE_datum
   Doel:
     - Zoekt binnen alle antwoorden van de vragenlijst naar vragen waarvan de vraagtekst 'Datum'
       bevat (bijv. 'Datum incident', 'Datum melding').
     - Neemt de antwoordtekst, probeert deze te parsen (om te zetten) als datum volgens Nederlands gebruik.
     - Zet die datum om in een uniform formaat 'yyyyMMdd'.
   Belangrijk:
     - Als geen datum ingevuld is → TRY_PARSE wordt NULL → datum blijft NULL.
     - Dit creëert per survey_result maximaal één regel met een datum-afgeleide waarde.
============================================================================================= */
WITH CTE_datum AS
(
    SELECT
        CAST(sr.objectid AS varchar(99)) AS objectid,      -- Survey result ID gebruikt voor join
        FORMAT(
            TRY_PARSE(CAST(sa.text AS varchar(99)) AS date USING 'nl-NL'),  -- Parse datum in NL-stijl
            'yyyyMMdd'                                                      -- Uniform date als string
        ) AS datum
    FROM survey_results sr
    LEFT JOIN survey_answers sa 
        ON sa.surveyResultObjectId = sr.objectid            -- Antwoorden die bij deze survey horen
    LEFT JOIN survey_questions sq 
        ON sa.questionObjectId = sq.objectid                -- Vraag-teksten ophalen
    WHERE sq.text LIKE '%Datum%'                            -- Filter: vragen waarin 'Datum' voorkomt
      AND sa.text IS NOT NULL                               -- Alleen antwoorden met inhoud
),

/* =============================================================================================
   CTE_tijdstip
   Doel:
     - Haalt de antwoordtekst op van de vraag 'Tijdstip incident'.
     - Wordt als plain text meegenomen; geen parsing.
   Opmerking:
     - De vraagtekst bevat HTML-escaped ampersands (&amp;).
============================================================================================= */
CTE_tijdstip AS
(
    SELECT
        CAST(sr.objectid AS varchar(99)) AS objectid,   -- Zelfde sleutel als CTE_datum
        sa.text AS tijdstip                             -- Tijdstip als tekst
    FROM survey_results sr
    LEFT JOIN survey_answers sa 
        ON sa.surveyResultObjectId = sr.objectid
    LEFT JOIN survey_questions sq 
        ON sa.questionObjectId = sq.objectid
    WHERE sq.text LIKE '&amp;Tijdstip incident&amp;'     -- Exact match voor HTML-escaped label
      AND sa.text IS NOT NULL
)


/* =============================================================================================
   HOOFDQUERY
   Doel:
     - Combineert survey metadata, cliënt, medewerker, kostenplaatsen en scores
       tot één record per ingevulde vragenlijst (survey_result).
============================================================================================= */
SELECT
    /* ----------- Identificatievelden ----------- */
    sr.objectid AS Ingevulde_Vragenlijst,                -- Unieke ID ingevulde vragenlijst
    c.objectId AS ClientID,                              -- Client ID
	c.identificationNo AS Clientnummer,                  -- Cliëntnummer
	CONCAT_WS(' ', c.initials, c.name) AS Clientnaam,     -- Clientnaam
    e.objectId As MedewerkerID,                          -- Medewerker ID
	e.identificationNo AS Medewerkernummer,              -- Medewerkernummer
	CONCAT_WS(' ', e.initials, e.name) AS Medewerkernaam,-- Medewerkernaam

    /* ----------- Kostenplaats medewerker ----------- */
    CONCAT_WS(' ', cc_mdw.identificationNo, cc_mdw.name)
        AS Kostenplaats_Mdw,                             -- Kostenplaats medewerker ISO+Naam

    /* ----------- Kostenplaats cliënt ----------- */
    CONCAT_WS(' ', cc_c.identificationNo, cc_c.name)
        AS Kostenplaats_Client,                          -- Kostenplaats cliënt ISO+Naam

    /* ----------- Datum van invullen (systeem) ----------- */
    CONVERT(char(8), COALESCE(sr.completedat, sr.createdat), 112)
        AS Ingevuld_datum,                               -- yyyymmdd, snelle conversie

    /* ----------- Antwoorddatum (voor nu systeem) ----------- */
    CONVERT(char(8), COALESCE(sr.completedat, sr.createdat), 112)
        AS Antwoord_datum,                               -- Je kunt desgewenst CTE_datum gebruiken

    /* ----------- Status voltooid ----------- */
    CASE WHEN sr.completedat IS NULL THEN '0' ELSE '1' END
        AS VragenlijstVoltooid,                          -- 1 = klaar, 0 = nog open

    /* ----------- Survey metadata ----------- */
    s.title AS Vragenlijst,                              -- Naam / titel van de vragenlijst
    CAST(s.description AS varchar(99)) AS Toelichting_Titel,  -- Beschrijving
    SUM(sad.score) AS TotaalScore,                       -- Totale score van antwoorden
    CASE WHEN s.active = 1 THEN 'Ja' ELSE 'Nee' END 
        AS Vragenlijst_In_Gebruik,                       -- Actieve survey?
    CASE WHEN s.useStrictEditAuthorization = 1 THEN 'Ja' ELSE 'Nee' END
        AS DeskundigheidRelevantVoorGebruik,             -- AutZ toegewezen?
    CASE WHEN s.useWorkflow = 1 THEN 'Ja' ELSE 'Nee' END
        AS BevatProcesstapBespreken,                    -- Heeft workflow-stap?

    /* ----------- Tijdlijn ----------- */
    CONVERT(char(8), sr.createdat, 112)
        AS InvullenBegonnenOp,
    CONVERT(char(8), sr.completedat, 112)
        AS InvullenCompleetOp,

    /* ----------- Status mapping ----------- */
    CASE sr.status
        WHEN 0 THEN 'Nieuw'
        WHEN 1 THEN 'Concept'
        WHEN 2 THEN 'Bespreken'
        WHEN 3 THEN 'Actueel'
        WHEN 4 THEN 'Gearchiveerd'
        ELSE 'Onbekend'
    END AS Status

/* =============================================================================================
   JOIN-STRUCTUUR
   - Volgorde: survey → answers → cliënt/medewerker → kostenplaatsen medewerker → kostenplaats cliënt
   - Tijdsgeldigheid (validity windows) zorgt dat de juiste kostenplaats gekozen wordt op het moment
     van invullen.
============================================================================================= */
FROM survey_results sr

-- Survey metadata
LEFT JOIN surveys s 
    ON s.objectid = sr.surveyobjectid

-- Antwoorden + scoreberekening
LEFT JOIN survey_answers sa 
    ON sa.surveyResultObjectId = sr.objectid
LEFT JOIN survey_answer_definitions sad 
    ON sad.objectid = sa.answerdefinitionobjectid

-- Cliënt en medewerker
LEFT JOIN clients c 
    ON c.objectid = sr.clientobjectid
LEFT JOIN employees e 
    ON e.objectid = sr.employeeobjectid


/* ======================= Kostenplaats medewerker ======================= */
LEFT JOIN team_assignments ta 
    ON ta.employeeobjectid = sr.employeeobjectid
   AND ta.begindate <= sr.createdat
   AND (ta.enddate IS NULL OR ta.enddate >= sr.createdat)

LEFT JOIN costcenter_assignments cca_mdw 
    ON cca_mdw.clusterobjectid = ta.teamobjectid
   AND cca_mdw.begindate <= ta.begindate
   AND (cca_mdw.enddate IS NULL OR cca_mdw.enddate >= ta.enddate)

LEFT JOIN costcenters cc_mdw 
    ON cc_mdw.objectid = cca_mdw.costcenterobjectid
   AND cc_mdw.begindate <= cca_mdw.begindate
   AND (cc_mdw.enddate IS NULL OR cc_mdw.enddate >= cca_mdw.enddate)


/* ======================= Kostenplaats cliënt ======================= */
LEFT JOIN location_assignments la 
    ON la.locationtype = 'main'
   AND la.clientobjectid = sr.clientobjectid
   AND la.begindate <= sr.createdat
   AND (la.enddate IS NULL OR la.enddate > sr.createdat)

LEFT JOIN costcenter_assignments cca_c 
    ON cca_c.unitobjectid = la.locationobjectid
   AND cca_c.begindate <= la.begindate
   AND (cca_c.enddate IS NULL OR cca_c.enddate >= la.enddate)

LEFT JOIN costcenters cc_c 
    ON cc_c.objectid = cca_c.costcenterobjectid
   AND cc_c.begindate <= cca_c.begindate
   AND (cc_c.enddate IS NULL OR cc_c.enddate >= cca_c.enddate)


/* ======================= Datum en tijdstip uit CTE's ======================= */
LEFT JOIN CTE_datum datum 
    ON datum.objectid = CAST(sr.objectid AS varchar(99))
LEFT JOIN CTE_tijdstip tijd 
    ON tijd.objectid = CAST(sr.objectid AS varchar(99))


/* =============================================================================================
   Filter op vragenlijsten
   - Ondersteunt meerdere patronen door STRING_SPLIT(@vragenlijst, ',').
   - Trim van whitespace voor betrouwbaarheid.
============================================================================================= */
WHERE
    @vragenlijst IS NULL
    OR EXISTS (
        SELECT 1
        FROM STRING_SPLIT(@vragenlijst, ',') a
        WHERE s.title LIKE LTRIM(RTRIM(a.value))
    )


/* =============================================================================================
   GROUP BY
   - Vereist omdat SUM(score) wordt gebruikt.
   - Alle niet-geaggregeerde SELECT velden worden gegroepeerd.
============================================================================================= */
GROUP BY
    sr.objectid,
	c.objectId,
    c.identificationNo,
	c.initials,
	c.name,
	e.objectId,
    e.identificationNo,
	e.initials,
	e.name,
    cc_mdw.identificationNo,
    cc_mdw.name,
    cc_c.identificationNo,
    cc_c.name,
    CONVERT(char(8), COALESCE(sr.completedat, sr.createdat), 112),
    CASE WHEN sr.completedat IS NULL THEN '0' ELSE '1' END,
    s.title,
    CAST(s.description AS varchar(99)),
    CASE WHEN s.active = 1 THEN 'Ja' ELSE 'Nee' END,
    CASE WHEN s.useStrictEditAuthorization = 1 THEN 'Ja' ELSE 'Nee' END,
    CASE WHEN s.useWorkflow = 1 THEN 'Ja' ELSE 'Nee' END,
    CONVERT(char(8), sr.createdat, 112),
    CONVERT(char(8), sr.completedat, 112),
    CASE sr.status
        WHEN 0 THEN 'Nieuw'
        WHEN 1 THEN 'Concept'
        WHEN 2 THEN 'Bespreken'
        WHEN 3 THEN 'Actueel'
        WHEN 4 THEN 'Gearchiveerd'
        ELSE 'Onbekend'
    END;