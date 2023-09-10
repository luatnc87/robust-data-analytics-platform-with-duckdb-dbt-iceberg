{{ config(materialized='table') }}

SELECT *
FROM {{ source('stackoverflow_survey_source', 'surveys')}}