-- Bird Pipeline — analytical SQL layer
-- Run against DuckDB (birds.db) after the bird_pipeline DAG has populated
-- silver_birds and gold_birds.


-- BASIC AGGREGATES:

-- Top 10 most observed species
SELECT
    species,
    COUNT(*) AS observations,
    SUM(individualCount) AS total_individuals
FROM gold_birds
GROUP BY species
ORDER BY observations DESC
LIMIT 10;


-- Seasonal patterns
SELECT
    month,
    COUNT(*) AS observations
FROM gold_birds
GROUP BY month
ORDER BY month;


-- Average flock size per species
SELECT
    species,
    ROUND(AVG(individualCount), 2) AS avg_flock_size
FROM gold_birds
GROUP BY species
ORDER BY avg_flock_size DESC
LIMIT 10;




-- REFERENCE TABLE (manually curated — not sourced from GBIF)

-- Maps bird family to a general habitat type, based on general
-- ornithological knowledge, to enable a multi-table JOIN. This is a
-- hand-built dimension table, not raw observational data.

CREATE OR REPLACE TABLE family_habitat (
    family       VARCHAR,
    habitat_type VARCHAR
);

INSERT INTO family_habitat VALUES 
    ('Anatidae', 'Wetland'), 
    ('Ardeidae', 'Wetland'), 
    ('Laridae', 'Wetland'), 
    ('Rallidae', 'Wetland'), 
    ('Gruidae', 'Wetland'), 
    ('Podicipedidae', 'Wetland'), 
    ('Phalacrocoracidae', 'Wetland'),
    ('Accipitridae', 'Open field / Forest'),
    ('Falconidae', 'Open field / Forest'),
    ('Emberizidae', 'Open field'),
    ('Laniidae', 'Open field'),
    ('Phasianidae', 'Open field'),
    ('Motacillidae', 'Open field / Wetland'),
    ('Corvidae', 'Urban / Forest'),
    ('Paridae', 'Forest / Urban'),
    ('Fringillidae', 'Forest'),
    ('Turdidae', 'Forest / Urban'),
    ('Sittidae', 'Forest'),
    ('Picidae', 'Forest'),
    ('Troglodytidae', 'Forest / Urban'),
    ('Regulidae', 'Forest'),
    ('Muscicapidae', 'Forest'),
    ('Aegithalidae', 'Forest'),
    ('Certhiidae', 'Forest'),
    ('Bombycillidae', 'Forest / Urban'),
    ('Columbidae', 'Urban'),
    ('Passeridae', 'Urban'),
    ('Sturnidae', 'Urban');



-- JOIN + GROUP BY + aggregates
-- Observation volume by habitat type and month.

SELECT
    fh.habitat_type,
    s.month,
    COUNT(*) AS observation_count,
    SUM(s.individualCount) AS total_individuals,
    COUNT(DISTINCT s.species) AS distinct_species
FROM silver_birds s
JOIN family_habitat fh ON s.family = fh.family
GROUP BY fh.habitat_type, s.month
ORDER BY fh.habitat_type, s.month;



-- CTE + window function: species ranking within each locality

-- Note: the sample only covers January 2024 (see README), so a
-- month-over-month comparison has no variance to measure against.
-- This ranks species by observation count within each locality instead.
SELECT
    species,
    locality,
    COUNT(*) AS obs_count,
    RANK() OVER (PARTITION BY locality ORDER BY COUNT(*) DESC) AS rank_in_locality
FROM silver_birds
GROUP BY species, locality
ORDER BY locality, rank_in_locality;


-- Subquery: species seen across more localities than average
SELECT
    species,
    COUNT(DISTINCT locality) AS locality_count
FROM silver_birds
GROUP BY species
HAVING COUNT(DISTINCT locality) > (
    SELECT AVG(locality_count)
    FROM (
        SELECT species, COUNT(DISTINCT locality) AS locality_count
        FROM silver_birds
        GROUP BY species
    )
)
ORDER BY locality_count DESC;



-- Data-quality check: duplicate detection
-- Same species + same date + same locality appearing more than once
-- likely indicates a duplicate GBIF record, not a distinct sighting.

SELECT
    species,
    eventDate,
    locality,
    COUNT(*) AS duplicate_count
FROM silver_birds
GROUP BY species, eventDate, locality
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;
