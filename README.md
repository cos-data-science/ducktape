# ducktape

A pipeline for simplifying your work with the OSF database backups using a motley assortment of tools and programs.  `ducktape` leaves you with a local DuckDB database (along with the underlying data tables as individual parquet files) ready for exploration and analysis.  No Docker or hacking at the `osf_shell` in the command line required!

This simplicity does come at a cost (at least at present):  None of the ORM tools and data models contained within the `osf.io` codebase will work here.

## Requirements

1. A properly staged PostgreSQL backup for local use
2. `duckdb` installed and configured for command-line use
3. `.env` file with PostgreSQL connection parameters

## Usage

`./runparams.sh` defines variables that will be sourced globally within the project. Please read through the file and modify the parameters as necessary before running the pipeline.

`./run.sh` defines the pipeline.  The only parameters that should be modified are the switch variables defined near the top of the script.  These control which parts of the pipeline get run by assigning them either a value of `1` (active) or `0` (inactive).

- To run the entire pipeline, make sure these are all assigned to 1 (the default).

To invoke the pipeline, run `./run.sh` from the project root directory in a terminal:

```
youruser@yourhost ~/ducktales $ ./run.sh
```