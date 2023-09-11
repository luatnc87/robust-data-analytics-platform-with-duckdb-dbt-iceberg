# Building a robust yet simple data analytics platform with DuckDB, dbt, Iceberg, and Superset
Modern analytics platforms require robust data storage, transformation, and management tools. DuckDB provides a simple, high-performance, columnar analytical database. DBT simplifies data transformation and modeling, and Iceberg offers scalable data lake management capabilities. Combining these tools can create a powerful and flexible analytics platform.

![architecture.png](images%2Farchitecture.png)

# Understanding the tools
## DuckDB
DuckDB is an in-memory, columnar analytical database that stands out for its speed, efficiency, and compatibility with SQL standard. Here is a more in-deepth look at its features:
- **High-performance Analytics**: DuckDB is optimized for analytical queries, making it an ideal choice for data warehousing and analytics workloads. It's in-memory storage and columnar data layout significantly boost query performance.
- **SQL Compatibility**: DuckDB supports SQL, making it accessible to analysts and data professionals who are ready familiar with SQL syntax. This compatibility allows you to leverage your existing SQL knowledge and tools.
- **Integration with BI Tools**: DuckDB integrates seamlessly with popular business intelligence (BI) tools like Tableau, Power BI, and Looker. This compatibility ensures that you can visualize and report on your data effectively.

## DBT
dbt, which stands for Data Build Tool, is a command-line tool that revolutionizes the way data transformations and modeling are done. Here's a deeper dive into dbt's capabilities:
- **Modular Data Transformations**: dbt uses SQL and YAML files to define data transformations and models. This modular approach allows you to break down complex transformations into smaller, more manageable pieces, enhancing mantainability and version control.
- **Data Testing**: dbt facilitates data testing by allowing you to define expectations about your data. It helps ensure data quality by automatically running tests against your transformed data.
- **Version Control**: dbt projects can be version controlled with tools like Git, enabling collaboration among data professionals while keeping a history of changes.
- **Incremental Builds**: dbt supports incremental builds, meaning it only processes data that has changed since the last run. This feature saves time and resources when working with large datasets.
- **Orchestration**: While dbt focuses on data transformations and modeling, it can be integrated with orchestration tools like Apache Airflow or dbt Cloud to create automated data pipelines.

## Iceberg
Iceberg is a table format designed for managing data lakes, offering several key features to ensure data quality and scalability:
- **Schema Evoluation**: One of Iceberg's standout features is its support for schema evolution. You can add, delete, or modify columns in your datasets without breaking existing queries or data integrity. This makes it suitable for rapidly evolving data lakes.
- **ACID Transformations**: Iceberg provides ACID (Atomicity, Consistency, Isolation, Durability) transactions, ensuring data consistency and reliability in multi-user and multi-write environments.
- **Time-Travel Capabilities**: Iceberg allows you to query historical versions of your data, making it possible to recover from data errors or analyze changes over time.
- **Optimized File Storage**: Iceberg optimizes file storage by using techniques like metadata management, partitioning, and file pruning. This results in efficient data storage and retrieval.
- **Connectivity**: Iceberg supports various storage connectors, including Apache Hadoop HDFS, Amazon S3, and Azure Data Lake Storage, making it versatile and compatible with different data lake platforms.

> NOTE: *Iceberg is not currently utilized in this showcase, but it will be added soon.*
## Apache Superset
Apache Superset is a modern, open-source BI tool that enables data exploration, visualization, and interactive dashboards. It connects to various data sources and is designed to empower users to explore data and create dynamic reports.
- **Data Visualization**: Apache Superset allows users to create interactive visualizations, including charts, graphs, and geographic maps, to explore and understand data.
- **Dashboard Creation**: Users can build dynamic dashboards by combining multiple visualizations and applying filters for real-time data exploration.
- **Connectivity**: Apache Superset can connect to various data sources, including SQL databases, data lakes, and cloud storage, making it adaptable to diverse data ecosystems.
- **Security**: It offers robust security features, including role-based access control and integration with authentication providers, ensuring data is accessed securely.
- **Community and Extensibility**: As an open-source project, Apache Superset benefits from a vibrant community that contributes plugins, connectors, and additional features, enhancing its capabilities.
- **SQL Support**: Superset supports SQL queries, allowing users to execute custom queries and create complex calculated fields.

# Setting up DuckDB, dbt, Superset with Docker Compose
## Setting up DuckDB
DuckDB will be installed as a library with dbt and Superset in the next session.

## Setting up dbt
Firstly, We need to install *dbt-core* and *dbt-duckdb* libraries, then init a dbt project.
```bash
# create a virtual environment
cd dbt
python -m venv .env
source .env/bin/activate

# install libraries: dbt-core and dbt-duckdb
pip install -r requirements.txt

# check version
dbt --version
```

Then we initialize a dbt project with the name *stackoverflowsurvey* and create a *profiles.yml* with the following content:
```yaml
stackoverflow:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: '/data/duckdb/stackoverflow.duckdb' # path to local DuckDB database file
```

Run the following commands to properly check configuration:
```bash
# We must specify the directory of the 'profiles.yml' file since we are not using the default location.
dbt debug --profiles-dir .
```

### Setting up Superset
Run following commands to set up the Superset service:
```bash
cd superset
# run docker compose command to start services of the Superset
# the libraries declared in 'requirements-local.txt' file will also be installed too
docker-compose up --detach
```

Visit *http://localhost:8088* to access the Superset UI. Enter **admin** as username and password. Choose **DuckDB** from the supported databases drop-down. Then set up a connection to DuckDB database.

<div align="center">
    <table >
        <tr>
            <td><img src="images/superset_duckdb_connection.png" /></td>
            <td><img src="images/superset_duckdb_connection_advanced_config.png" /></td>
        </tr>
    </table>
</div>

> **NOTE**: Provide path to a duckdb database on disk in the url, e.g., *duckdb:////Users/whoever/path/to/duck.db*.

We combine the DuckDB database path file exposed in *superset/docker/docker-compose.yml* file
```bash
x-superset-volumes:
  &superset-volumes
  - /data/duckdb:/app/duckdb
```
with the DuckDB database name defined in *dbt/stackoverflowsurvey/profiles.yml*.
```yaml
path: '/data/duckdb/stackoverflow.duckdb'
```
So, below, we have the final URI to establish a connection between Superset and DuckDB:
```bash
duckdb:///duckdb/stackoverflow.duckdb
```

With Superset, the engine needs to be configured to open DuckDB in “read-only” mode. Otherwise, only one query can run at a time (simultaneous queries will cause locks). This also prevents refreshing the Superset dashboard while the pipeline is running.

# Loading source
In this showcase, we are using the [Stack Overflow Annual Developer Survey](https://insights.stackoverflow.com/survey) data set. To simplify maters, we will focus solely on the [2023](https://cdn.stackoverflow.co/files/jo7n4k8s/production/49915bfd46d0902c3564fd9a06b509d08a20488c.zip/stack-overflow-developer-survey-2023.zip) data set, which needs to be manually downloaded and extracted into the *PROJECT_HOME/data* directory.

# Building models with dbt
## Defining data source
We declare the data source in *stackoverflowsurvey/models/source.yml* file with following content:
```yaml
sources:
  - name: stackoverflow_survey_source
    tables:
      - name: surveys
        meta:
          external_location: "read_csv('../../data/survey_results_public.csv', AUTO_DETECT=TRUE)" # automatically parser and detect schema
          formatter: oldstyle
```
## Building models
For demonstration purposes only, we have created a very simple model with the following content:
```sql
{{ config(materialized='table') }}

SELECT *
FROM {{ source('stackoverflow_survey_source', 'surveys')}}
```
# Connecting Superset
Once the dbt models are built, the data visualization can begin. An admin user must be created in superset in order to log in.

![superset_dashboard.png](images%2Fsuperset_dashboard.png)

# Conclusion
In this comprehensive guide, we've demonstrated how to construct a sophisticated analytics platform that leverages the combined power of DuckDB, DBT, Iceberg, and Apache Superset. This platform empowers organizations to seamlessly ingest, transform, manage, visualize, and analyze data to extract actionable insights.
Key Components:
- **DuckDB**: Our high-performance, SQL-compatible, in-memory database serves as the foundation for efficient data storage and retrieval, enabling lightning-fast analytical queries.
- **dbt**: DBT simplifies data transformation and modeling, allowing for the creation of modular, version-controlled data pipelines that enhance data quality and maintainability.
- **Iceberg**: Iceberg manages data lakes with ease, offering schema evolution, ACID transactions, and time-travel capabilities, ensuring data integrity and scalability in large-scale analytics environments.
- **Apache Superset**: Apache Superset enhances the platform by providing a modern, open-source BI tool for data exploration, visualization, and interactive dashboard creation. Its connectivity options, security features, and SQL support empower users to gain insights from data with ease.

Together, these tools create a powerful and flexible analytics platform, enabling organizations to navigate the data landscape with confidence, derive valuable insights, and make informed decisions. Whether you're dealing with structured or unstructured data, this platform equips you with the tools needed to turn raw data into actionable intelligence, driving business success and innovation.

## Supporting Links
* <a href="https://insights.stackoverflow.com/survey" target="_blank">Stack Overflow Annual Developer Survey</a>
* <a href="https://duckdb.org/2022/10/12/modern-data-stack-in-a-box.html" target="_blank">Modern Data Stack in a Box with DuckDB</a>
* <a href="https://github.com/jwills/dbt-duckdb" target="_blank">dbt adapter for DuckDB</a>






