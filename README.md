# schema_generator

Mix task to generate boilerplate functions on Ecto Schemas

## Installation

Add :schema_generator as a dependency to your project's `mix.exs`:
```
defp deps do
  [
    {:schema_generator, "~> 0.3", only: [:dev]}
  ]
end
```

Add the `:test` scope if you want to run the CI check during a CI process.

## Use

SchemaGenerator is a command line library used to generate common functions
present on ecto schemas. Currently this is scoped to joining associations,
querying by fields, and a sort function that takes the field and `_asc` or `_desc`
as a string parameter.

The reason for the generator approach is simple: writing boilerplate isn't fun.
A macro approach could do the same thing without code but the slow compilation 
and more active recompilation has a pretty negative affect on developer productivity.

Running the command is pretty simple:

```
mix ecto.gen.queries path/to/schema.ex
```

This will generate composable query functions for any non-virtual fields and associations 
defined by the schema. A directory path can also be provided, which will generate queries for 
any valid ecto schema files located in the directories.
Skipping a subset of queries is possible with the options:

```
--skip-fields  - skips generating functions for the fields
--skip-assocs  - skips generating functions for the assocs
--skip-sort    - skips generating functions for sorting by fields
```

The lib also attempts to generate a query field for the primary key. If the @primary_key attribute
is present, it will use that. If a field has the primary_key attribute, it will skip generating one,
and if neither are present, it will use `id`, which is overridable by using a `--primary-key #{field}`
option when using the CLI.

Additional options are allowed for easy of use and for running a check in CI.
```
--quiet        - suppresses the logs
--ci           - runs the generation as a noop and fails / alerts if changes would be made
```

If you want to remove the generated query functions, just run:

```
mix ecto.rm.queries path/to/schema.ex
```

This will remove any generated functions between the versioned control flow module attributes,
indicated by the `@schema_gen_tag` attribute. The initial attribute will have a version hash used
to determine if the generated functions have changed and should replace the previous generation.
Any code written between the tags will be removed if the schema changes unless it is tagged with a custom
tag (`@tag :sg_override`), so caution is required.

## Overrides

Since most of these functions are named based on fields, if the function that would be generated already
exists the generator will simply skip over it. The exception is the `sort/2` function, that accepts a
composable query and a string for pattern matching. Since this only covers a simple subset of the possibilities
for sorting, the library allows writing custom sort functions. These functions must be tagged with a module
attribute: `@tag :sg_override`. Any sort function tagged this way will be grouped with the other sort functions,
and if the sorting argument matches one that would be generated, it will skip the generation. Any other function
tagged with `@tag :sg_override` will be ignored, and any generated functions that would be skipped are still
skipped.

### Warning
This library assumes that the files compile properly. Unexpected behavior may occur if the file is an
invalid ecto schema. It also assumes that Ecto.Query functions are imported in the file, and compilation 
failures may occur if functions are generated without the import. The library doesn't add an import because
of the potential that a custom `__using__` module is already in place, and that contains all the proper imports 
already. It's also recommended to run the formatter after generating functions. An earlier version ran the 
formatter as a part of the process but it had some unexpected effects from running on a stringified version
of the modules.

Running the CLI should be idempotent, but keeping a version pre-generation in source control is recommended.
