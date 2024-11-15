# schema_generator

Mix task to generate boilerplate functions on Ecto Schemas

## Installation

Add :schema_generator as a dependency to your project's `mix.exs`:
```
defp deps do
  [
    {:schema_generator, "~> 0.2", only: [:dev]}
  ]
end
```

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
--skip-fields - skips generating functions for the fields
--skip-assocs - skips generating functions for the assocs
--skip-sort - skips generating functions for sorting by fields
```

The lib also attempts to generate a query field for the primary key. If the @primary_key attribute
is present, it will use that. If a field has the primary_key attribute, it will skip generating one,
and if neither are present, it will use `id`, which is overridable by using a `--primary-key #{field}`
option when using the CLI.

If you want to remove the generated query functions, just run:

```
mix ecto.rm.queries path/to/schema.ex
```

This will remove any generated functions between the versioned control flow module attributes,
indicated by the `@schema_gen_tag` attribute. The initial attribute will have a version hash used
to determine if the generated functions have changed and should replace the previous generation.
Any code written between the tags will be removed if the schema changes, so caution is required.

### Warning
This library assumes that the files compile properly. Unexpected behavior may occur if the file is an
invalid ecto schema. It also assumed that Ecto.Query functions are imported in the file, and compilation 
failures may occur if functions are generated without the import. The library doesn't add an import because
of the potential that a custom `__using__` module is already in place, and that contains all the proper imports 
already. It's also recommended to run the formatter after generating functions. An earlier version ran the 
formatter as a part of the process but it had some unexpected effects from running on a stringified version
of the modules.

Running the CLI should be idempotent, but keeping a version pre-generation in source control is recommended.
