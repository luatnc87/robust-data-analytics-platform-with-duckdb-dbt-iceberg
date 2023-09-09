{{ config(materialized='table') }}

select *
from {{ source('stackoverflow_survey_source', 'surveys')}}