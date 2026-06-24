-- Top 10 most observed species
SELECT 
    species,
    COUNT(*) as observations,
    SUM(individualCount) as total_individuals
FROM gold_birds
GROUP BY species
ORDER BY observations DESC
LIMIT 10;

-- Seasonal patterns
SELECT 
    month,
    COUNT(*) as observations
FROM gold_birds
GROUP BY month
ORDER BY month;

-- Average flock size per species
SELECT 
    species,
    ROUND(AVG(individualCount), 2) as avg_flock_size
FROM gold_birds
GROUP BY species
ORDER BY avg_flock_size DESC
LIMIT 10;