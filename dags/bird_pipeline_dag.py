from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime
import requests
import pandas as pd
import duckdb

BRONZE_COLUMNS = [
    'species', 
    'decimalLatitude', 
    'decimalLongitude', 
    'eventDate', 
    'month', 
    'year', 
    'individualCount',
    'locality', 
    'family', 
    'order', 
    'basisOfRecord'
]

# Ingest bronze
def fetch_gbif_data():
    url = "https://api.gbif.org/v1/occurrence/search"
    params = {
        "classKey": 212,
        "countryCode": "PL",
        "stateProvince": "Dolnoslaskie",
        "year": 2024,
        "limit": 300
    }
    
    response = requests.get(url, params=params)
    data = response.json()
    
    records = data["results"]
    df = pd.DataFrame(records)
    df = df[BRONZE_COLUMNS]
    df.to_parquet("/tmp/pipeline_data/bronze_birds.parquet", index=False)
    
    print(f"{len(df)} records downloaded.")

# Transform silver
def clean_data():
    conn = duckdb.connect("/tmp/pipeline_data/birds.db")
    
    conn.execute("""
        CREATE OR REPLACE TABLE silver_birds AS
        SELECT 
            species,
            decimalLatitude,
            decimalLongitude,
            eventDate,
            month,
            year,
            COALESCE(individualCount, 1) AS individualCount,
            locality,
            family,
            "order",
            basisOfRecord
        FROM read_parquet('/tmp/pipeline_data/bronze_birds.parquet')
        WHERE species IS NOT NULL
        AND decimalLatitude IS NOT NULL
        AND decimalLongitude IS NOT NULL
    """)
    
    result = conn.execute("SELECT COUNT(*) FROM silver_birds").fetchone()
    print(f"After cleaning: {result[0]} records")
    
    conn.close()

# Load gold
def load_duckdb():
    conn = duckdb.connect("/tmp/pipeline_data/birds.db")
    
    conn.execute("""
        CREATE OR REPLACE TABLE gold_birds AS
        SELECT 
            species,
            month,
            year,
            decimalLatitude,
            decimalLongitude,
            individualCount,
            locality
        FROM silver_birds
    """)
    
    result = conn.execute("SELECT COUNT(*) FROM gold_birds").fetchone()
    print(f"Gold layer: {result[0]} records saved to DuckDB")
    
    conn.close()

with DAG(
    dag_id="bird_pipeline",
    start_date=datetime(2026, 3, 17),
    schedule="@daily",
    catchup=False
) as dag:

    task1 = PythonOperator(
        task_id="ingest_bronze",
        python_callable=fetch_gbif_data
    )

    task2 = PythonOperator(
        task_id="transform_silver",
        python_callable=clean_data
    )

    task3 = PythonOperator(
        task_id="load_gold",
        python_callable=load_duckdb
    )

    task1 >> task2 >> task3