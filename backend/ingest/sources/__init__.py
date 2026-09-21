"""Transport adapters. One module per (chain, transport): each defines a
module-level ``SOURCE`` implementing ``ingest.contract.Source``. The CLI
loads them by name: ``--source <module-name>``. Kept empty of adapters on
purpose — see README.md for the contract an adapter must fulfil."""
