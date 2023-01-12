USE GlobalPollution
GO

--=================CHECK IMPORTED DATA===============================

SELECT * FROM GlobalPollution..WasteComposition
SELECT * FROM GlobalPollution..WasteCollection
SELECT * FROM GlobalPollution..WasteTreatment
SELECT * FROM GlobalPollution..SpecialWaste
SELECT * FROM GlobalPollution..OtherInfo

SELECT COUNT(*) FROM GlobalPollution..WasteComposition
SELECT COUNT(*) FROM GlobalPollution..WasteCollection
SELECT COUNT(*) FROM GlobalPollution..WasteTreatment
SELECT COUNT(*) FROM GlobalPollution..SpecialWaste
SELECT COUNT(*) FROM GlobalPollution..OtherInfo

SELECT COUNT(distinct(region_id)) FROM GlobalPollution..WasteComposition

--=================== EXPLORING DATA ================================

--average food organic waste  percent region wise
SELECT a.region_id, ROUND(AVG(CAST(a.composition_food_organic_waste_percent as float)), 2) as avg_comp_food_organic_waste_pct
FROM
(SELECT region_id, composition_food_organic_waste_percent  FROM GlobalPollution..WasteComposition
WHERE composition_food_organic_waste_percent ! = 'NA')  a
GROUP BY a.region_id
ORDER BY avg_comp_food_organic_waste_pct DESC

-- total msw(nunicipal solid waste) generated per year globally
SELECT SUM(CAST(total_msw_total_msw_generated_tons_year as float)) Total_msw_generated_perYear_globally
FROM GlobalPollution..SpecialWaste
WHERE total_msw_total_msw_generated_tons_year != 'NA'

-- average msw(municipal solid waste) per person per country
ALTER Table dbo.WasteComposition
ALTER Column population_population_number_of_people int;

SELECT d.country_name, 
Round((Convert(float, d.total_msw_total_msw_generated_tons_year)/d.population_population_number_of_people)*100, 2) avg_msw_perPerson_perCountry
FROM
(SELECT b.country_name, b.population_population_number_of_people, 
c.total_msw_total_msw_generated_tons_year
FROM GlobalPollution..WasteComposition b
JOIN GlobalPollution..SpecialWaste c
ON b.country_name = c.country_name)  d
WHERE d.country_name not in ('Sint Maarten (Dutch part)', 'Turks and Caicos Islands', 'NA')
ORDER BY avg_msw_perPerson_perCountry DESC

--top 3 countries which have highest compost waste treatment percent
SELECT TOP 3 country_name, Round(Convert(float,waste_treatment_compost_percent), 2) top3_high_compost_waste_treatment_pct
FROM GlobalPollution..WasteTreatment
WHERE waste_treatment_compost_percent != 'NA'
ORDER BY top3_high_compost_waste_treatment_pct DESC;

--bottom 3 countries which have lowest compost waste treatment percent
SELECT TOP 3 country_name, Round(Convert(float,waste_treatment_compost_percent), 2) bottom3_low_compost_waste_treatment_pct
FROM GlobalPollution..WasteTreatment
WHERE waste_treatment_compost_percent != 'NA'
ORDER BY bottom3_low_compost_waste_treatment_pct ASC;

--top3 and bottom3 countries which generate highest and lowest  e-waste (tons) per year in one output

DROP table if exists #topcountry_eWaste
CREATE TABLE #topcountry_eWaste
(region nvarchar(255),
topcountry_eWaste_ton_year int
)
INSERT INTO #topcountry_eWaste
SELECT region_id, AVG(Convert(float, special_waste_e_waste_tons_year)) avg_e_waste
FROM GlobalPollution..SpecialWaste
WHERE special_waste_e_waste_tons_year != 'NA'
Group by region_id
ORDER BY avg_e_waste DESC

SELECT top 3 *
FROM #topcountry_eWaste
ORDER BY #topcountry_eWaste.topcountry_eWaste_ton_year DESC

DROP table if exists #bottomcountry_eWaste
CREATE TABLE #bottomcountry_eWaste
(region nvarchar(255),
bottomcountry_eWaste_ton_year int
)
INSERT INTO #bottomcountry_eWaste
SELECT region_id, AVG(Convert(float, special_waste_e_waste_tons_year)) avg_e_waste
FROM GlobalPollution..SpecialWaste
WHERE special_waste_e_waste_tons_year != 'NA'
Group by region_id
ORDER BY avg_e_waste ASC

SELECT top 3 *
FROM #bottomcountry_eWaste
ORDER BY #bottomcountry_eWaste.bottomcountry_eWaste_ton_year ASC

-- combine top 3 and bottom 3 countries which generate e-waste in one table
SELECT * FROM(
SELECT top 3 *
FROM #topcountry_eWaste
ORDER BY #topcountry_eWaste.topcountry_eWaste_ton_year DESC) a
UNION
SELECT * FROM(
SELECT top 3 *
FROM #bottomcountry_eWaste
ORDER BY #bottomcountry_eWaste.bottomcountry_eWaste_ton_year ASC) b
ORDER BY a.topcountry_eWaste_ton_year DESC

--filter country starting or ending with certain letter 
SELECT country_name
FROM GlobalPollution..WasteComposition
WHERE LOWER(country_name) like '%o' 

SELECT distinct region_id
FROM GlobalPollution..WasteComposition
WHERE LOWER(region_id) like 'e%'

SELECT distinct country_name
FROM GlobalPollution..WasteComposition
WHERE LOWER(country_name) like 'e%' or LOWER(country_name) like 'f%'

SELECT country_name
FROM GlobalPollution..WasteCollection
WHERE LOWER(country_name) like 'a%' and LOWER(country_name) like '%a'

--ranking population by country
SELECT region_id, country_name, population_population_number_of_people,
RANK() OVER(PARTITION BY region_id ORDER BY population_population_number_of_people DESC) as rnk
FROM GlobalPollution..WasteComposition

-- total population that waste was collected and total population that waste was not collected by region
SELECT f. region_id, ROUND(SUM(f.population_waste_collected),2) total_population_waste_collected_by_region, 
ROUND(SUM(f.population_waste_not_collected),2) total_population_waste_not_collected_by_region
FROM
(SELECT e.region_id, e.country_name, e.gdp, e.population_population_number_of_people,
e.waste_collection_coverage_total_percent_of_population,
(CAST(e.population_population_number_of_people as float) * CAST(e.waste_collection_coverage_total_percent_of_population as float)/100) as population_waste_collected,
CONVERT(float, e.population_population_number_of_people) *
(1-CONVERT(float, e.waste_collection_coverage_total_percent_of_population)/100) as population_waste_not_collected
FROM
(SELECT c.region_id, c.country_name, c.gdp, c.population_population_number_of_people, 
d.waste_collection_coverage_total_percent_of_population
FROM GlobalPollution..WasteComposition c
JOIN GlobalPollution..WasteCollection d
ON c.country_name = d.country_name
where c.country_name != 'NA') e
WHERE e.waste_collection_coverage_total_percent_of_population != 'NA') f
GROUP BY f.region_id
ORDER BY total_population_waste_collected_by_region DESC

--rolling total msw generated by country by region 
SELECT g.region_id, g.country_name, SUM(CAST(h.total_msw_total_msw_generated_tons_year as float)) 
Over (PARTITION BY g.region_id ORDER BY g.region_id, g.country_name) as rolling_total_msw_ton_year
FROM GlobalPollution..WasteComposition g
JOIN GlobalPollution..SpecialWaste h
	ON g.region_id = h.region_id
	and g.country_name = h.country_name
WHERE g.country_name not in ('NA', 'Sint Maarten (Dutch part)', 'Turks and Caicos Islands')
ORDER BY g.region_id, g.country_name

--use CTE
WITH mswCTE (region_id, country_name, population_population_number_of_people, total_msw_total_msw_generated_tons_year, 
rolling_total_msw_ton_year, rolling_population)
as
(
SELECT g.region_id, g.country_name, g.population_population_number_of_people, h.total_msw_total_msw_generated_tons_year, 
SUM(CAST(h.total_msw_total_msw_generated_tons_year as float)) 
OVER (PARTITION BY g.region_id ORDER BY g.region_id, g.country_name) as rolling_total_msw_ton_year,
SUM(CONVERT(float, g.population_population_number_of_people)) 
OVER (PARTITION BY g.region_id ORDER BY g.region_id, g.country_name) as rolling_population
FROM GlobalPollution..WasteComposition g
JOIN GlobalPollution..SpecialWaste h
	ON g.region_id = h.region_id
	and g.country_name = h.country_name
WHERE g.country_name not in ('NA', 'Sint Maarten (Dutch part)', 'Turks and Caicos Islands')
)

SELECT *, (rolling_total_msw_ton_year/rolling_population) as  total_msw_generated_per_person
FROM mswCTE

--=============CREATE VIEW TO STORE DATA FOR VISUALIZATION===================================

DROP VIEW if exists GlobPollutionData
GO

CREATE VIEW GlobPollutionData 
AS
SELECT j.region_id, j.country_name, j.gdp, j.population_population_number_of_people, 
k.special_waste_e_waste_tons_year, k.total_msw_total_msw_generated_tons_year,
k.special_waste_hazardous_waste_tons_year, l.waste_collection_coverage_total_percent_of_population,
l.waste_collection_coverage_total_percent_of_waste, 
m.waste_treatment_recycling_percent, m.waste_treatment_compost_percent
FROM GlobalPollution..WasteComposition j
JOIN GlobalPollution..SpecialWaste k
ON j.country_name = k.country_name
JOIN GlobalPollution..WasteCollection l
ON j.country_name = l.country_name
JOIN GlobalPollution..WasteTreatment m
ON j.country_name = m.country_name
--WHERE j.country_name !='NA'
GO

SELECT * FROM GlobPollutionData

-- ==========CREATE STORED PROCEDURE===================================================

--create stored procedure with parameter
DROP PROCEDURE spSpecialWaste_totalMSW;
GO

CREATE PROCEDURE spSpecialWaste_totalMSW
@region_id varchar(50)
AS
SELECT j.region_id, j.country_name, j.population_population_number_of_people, j.gdp,
k.special_waste_e_waste_tons_year, k.total_msw_total_msw_generated_tons_year,
k.special_waste_hazardous_waste_tons_year
FROM GlobalPollution..WasteComposition j
JOIN GlobalPollution..SpecialWaste k
ON j.country_name = k.country_name
WHERE j.region_id = @region_id
GO

EXEC spSpecialWaste_totalMSW @region_id = 'NAC'

-- create stored procedure with output
DROP PROCEDURE spSpecialWaste_totalMSWoutput
GO

CREATE PROCEDURE spSpecialWaste_totalMSWoutput
(@country_name varchar(50), @total_msw_total_msw_generated_tons_year float output)
AS
BEGIN
SELECT @total_msw_total_msw_generated_tons_year=k.total_msw_total_msw_generated_tons_year 
FROM GlobalPollution..WasteComposition j
JOIN GlobalPollution..SpecialWaste k
ON j.country_name = k.country_name
WHERE j.country_name = @country_name
END
GO

DECLARE @total_msw_total_msw_generated_tons_year float
EXEC dbo.spSpecialWaste_totalMSWoutput 'United States',  @total_msw_total_msw_generated_tons_year output
SELECT @total_msw_total_msw_generated_tons_year 
