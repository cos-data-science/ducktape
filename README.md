# ducktape

A pipeline for simplifying your work with the OSF database backups using a motley assortment of tools and programs.  `ducktape` leaves you with a local DuckDB database (along with the underlying data tables as individual parquet files) ready for exploration and analysis.  No Docker or hacking at the `osf_shell` in the command line required!

## Requirements

1. A properly staged PostgreSQL backup for local use
2. `duckdb` installed and configured for command-line use

## Usage

- Define location parameters in the "CONFIG" section of `run.sh` as needed.
- Verify and modify any runtime parameters in `run.sh` as needed.  These parameters control which parts of the pipeline get run and are defined near the top of the script with the `RUN_` prefix.  Any `RUN_` parameter set to `1` will be executed, while those set to `0` will be skipped.
- To run the entire pipeline, assign all `RUN_` parameters to 1.

To invoke the pipeline, run `./run.sh` from the project root directory in a terminal:

```
youruser@yourhost ~/ducktales $ ./run.sh
```