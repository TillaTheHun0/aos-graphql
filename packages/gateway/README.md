# Arweave GraphQL Gateway

An implementation of the Arweave GraphQL Gateway, to be ran within [ao](https://ao.arweave.dev), with OOTB integration for [`aos`](https://github.com/permaweb/aos)

<!-- toc -->

- [Prerequisites](#prerequisites)
- [Usage](#usage)

<!-- tocstop -->

## Prerequisites

You will need to have `aos` and it's built-in primitives ie. `json`, `bint`

> If using persistence based on `sqlite`, you will need `sqlite` and associate lua bindings. As a convenience, these are copied as `libs` from [here](../../ao_libs)

TODO: add flag to optionally include `sqlite` libs as part of build in `CMake`

You will need to have the [Lua GraphQL Runtime Implementation available](../runtime)
You will also need to have [Lua GraphQL Server Implementation available](../server/)

## Usage

TODO
