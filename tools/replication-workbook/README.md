# Replication Workbook (Snowsight Notebook)

This folder contains Snowflake Notebooks you can import into Snowsight:

- `Enterprise Edition.ipynb` - **Enterprise/Standard**: basic redundancy with replication groups (read-only replicas; no promotion)
- `Business_Critical_Edition.ipynb` - **Business Critical**: business continuity with failover groups (promotion/runbook)

## Which guide should I use?

- **Basic redundancy (read-only replicas)**: use `Enterprise Edition.ipynb`
- **Business continuity (promotion / failover)**: use `Business_Critical_Edition.ipynb`

## Prerequisites

- You can sign in to Snowsight for your Snowflake account.
- Your active role can create notebooks in the target database and schema (and has `USAGE` on the warehouse you plan to use).

## Download the notebook to your machine

If you already have this repository checked out locally, you already have the notebook file in this folder.

Otherwise, download it from GitHub:

1. Open the notebook file in GitHub:
   - `tools/replication-workbook/Enterprise Edition.ipynb`, or
   - `tools/replication-workbook/Business_Critical_Edition.ipynb`
2. Download the file to your computer (the exact UI varies; "Download raw file" is common).

Alternative: Download the repository as a ZIP (GitHub: Code -> Download ZIP), unzip it, then find:

- `tools/replication-workbook/Enterprise Edition.ipynb`
- `tools/replication-workbook/Business_Critical_Edition.ipynb`

## Upload/import into Snowsight

1. Sign in to Snowsight.
2. In the left navigation, go to **Projects → Notebooks**.
3. Click **+ Notebook** and select **Import .ipynb file**.
4. Choose the `.ipynb` file from your computer.
5. Name the notebook and choose a **Database** and **Schema** for where the notebook object will live.
6. Choose a **warehouse** for queries and (if prompted) notebook execution, then click **Create**.

## Notes / common issues

- **Missing Python packages after import**: If the notebook imports packages that aren’t available by default in Snowflake Notebooks, add them via the notebook’s package management UI before running.
- **Permission errors**: Switch to a role with the needed privileges (create notebook in schema, usage on warehouse), then re-try the import.

## References

- [Getting started with Snowflake Notebooks](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks)
