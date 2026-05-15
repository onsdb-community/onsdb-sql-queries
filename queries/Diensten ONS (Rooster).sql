/*
===============================================================================
Titel       : Diensten ONS (Rooster)
Doel        : Inzicht in geplande diensten waarop een medewerker is toegewezen
Auteur      : Eduard Voorham (Aafje)
===============================================================================

Korte uitleg van de logica
- De basis van de query is de tabel moves_shift_assignments, waarin de toewijzingen van medewerkers aan diensten worden vastgelegd.
- De start- en einddatum dienen ingesteld te worden, pas dit aan bovenaan het script (regels beginnend met DECLARE)

Aandachtspunten
- De query is gebaseerd op ONS Plannen & roosteren. In ONS Administratie kunnen tijden achteraf worden aangepast. 
  De geroosterde uren sluiten dus niet 100% aan met de uiteindelijk geregistreerde uren (in presence_logs).
- Dummy-medewerkers zijn uitgesloten
- Verwijderde of vervangen diensten zijn uitgesloten

*/

DECLARE @startdatum as DATE = '2026-01-01'
DECLARE @einddatum as DATE = '2026-02-28'

SELECT              
	  msa.objectid as msa_objectid
	, msa.timeline_shift_id
	, ms.description as dienst
	, CAST(msa.date as date) as datum_dienst
	, concat(e.identificationNo,' ',e.firstName,' ',e.name) as medewerker
	, concat(t.identificationNo,' ',t.name) as team_medewerker
	, ep.description as deskundigheid_medewerker
	, ct.name as contracttype_medewerker
	, concat(mu.code,' ',mu.name) as planbord
	, case 
		when mu.external_id is null then concat(mup.code,' ',mup.name) 
		else concat(mu.code,' ',mu.name) 
		end as kostenplaats
	, mep.name as deskundigheid_dienst
	, left(msa.start_time,5) as start_time
	, left(msa.stop_time,5) as stop_time
	, left(msa.start_break_time,5) as start_break_time
	, left(msa.stop_break_time,5) as stop_break_time
	, (case	-- Tijd van start tot stop
			when msa.stop_time<msa.start_time
			then
				((DATEDIFF(MINUTE,msa.start_time,'00:00:00') / 60.00) + 24)
				+ (DATEDIFF(MINUTE,'00:00:00',msa.stop_time) / 60.00)
			else datediff(minute,msa.start_time,msa.stop_time) / 60.00
			end) 
		-
	  (case -- Pauze-tijd
			when msa.start_break_time is null then 0
			else
				case
				when msa.start_breaK_time > msa.stop_break_time 
				then datediff(minute,msa.start_break_time,msa.stop_break_time)/60.00 + 24
				else datediff(minute,msa.start_break_time,msa.stop_break_time)/60.00
				end
	  end) as dienstduur
FROM moves_shift_assignments msa
LEFT JOIN moves_units mu on mu.objectid = msa.unit_id
LEFT JOIN moves_units mup on mup.objectid = mu.parent_unit_id
LEFT JOIN moves_shifts ms on ms.timeline_id = msa.timeline_shift_id 
    AND msa.date between ms.valid_from 
	AND isnull(dateadd(d,-1,ms.valid_to),'2099-12-31') -- -1 dag t.o.v. valid_to, omdat de nieuwe versie op dezelfde dag begint
LEFT JOIN moves_expertise_profiles mep on mep.objectid = ms.expertise_profile_id
LEFT JOIN moves_employees me on me.objectid = msa.employee_id
LEFT JOIN employees e on me.external_id = e.objectid
LEFT JOIN team_assignments ta on ta.employeeobjectid = e.objectid 
	AND msa.date between ta.begindate AND isnull(ta.enddate,'2099-12-31')
LEFT JOIN teams t on t.objectid = ta.teamobjectid
LEFT JOIN expertise_profile_assignments epa on epa.employeeObjectId = e.objectid 
	AND epa.startTime <= msa.date 
	AND (epa.endTime is null or epa.endTime >= msa.date)
LEFT JOIN expertise_profiles ep on ep.objectid = epa.expertiseprofileobjectid
LEFT JOIN contracts c on c.employeeObjectId = e.objectId 
	AND msa.date between c.beginDate AND isnull(c.endDate, msa.date)
LEFT JOIN contract_types ct on ct.objectId = c.contractTypeObjectId
WHERE
	msa.discarded_at is null
	AND me.dummy <> 1
	AND msa.date <= @einddatum
	AND msa.date >= @startdatum