/*
===============================================================================
Titel       : Vertrouwelijke documenten met labels en deskundigheid
Doel        : Geeft een overzicht van documenten die als vertrouwelijk zijn
             gemarkeerd, inclusief cliëntnummer, status, labels (tags) en
             gekoppelde deskundigheidsgroep/-profiel.
Auteur      : Chantal van Son (Odion)
===============================================================================

Korte uitleg van de logica
- Selecteert documenten uit documents en filtert op confidential = 1.
- Verrijkt per document met status (lst_document_statuses) en cliëntnummer (clients).
- Verrijkt met gekoppelde deskundigheden en deskundigheidsgroepen.
- Verrijkt met labels (tags).

Aandachtspunten
- Door meerdere LEFT JOINs op groepen/profielen/tags kan één document meerdere keren terugkomen (1-n relaties); gebruik evt. DISTINCT/aggregatie als één rij per document gewenst is.

*/


SELECT
    d.objectId,
    d.employeeObjectId,
    d.description as document_beschrijving,
    d.filename as document_naam,
    s.description as status,
    d.clientObjectId,
    c.identificationNo as clientnummer,
    d.message as melding,
    d.confidential as vertrouwelijk,
    d.createdAt as aangemaakt_op,
    d.updatedAt as bewerkt_op,
    eg.name as deskundigheidsgroep,
    ep.description as deskundigheidsprofiel,
    ep.visible as deskundigheidsprofiel_zichtbaar,
    t.name as document_label
FROM documents d

    -- deskundigheidsgroepen
    LEFT JOIN document_expertise_groups deg ON deg.documentObjectId=d.objectId
    LEFT JOIN expertise_groups eg ON eg.objectId=deg.expertiseGroupObjectId
        AND eg.beginDate <= GETDATE()
        AND (eg.endDate IS NULL OR eg.endDate > GETDATE())

    -- deskundigheden
    LEFT JOIN document_rights dr ON dr.documentObjectId=d.objectId
    LEFT JOIN expertise_profiles ep ON ep.objectId=dr.educationObjectId

    -- tags
    LEFT JOIN document_tags dt ON dt.documentObjectId=d.objectId
    LEFT JOIN tags t ON t.objectId=dt.tagObjectId

    -- status
    LEFT JOIN lst_document_statuses s ON s.code=d.status

    -- client
    LEFT JOIN clients c ON c.objectId=d.clientObjectId

WHERE confidential=1;
