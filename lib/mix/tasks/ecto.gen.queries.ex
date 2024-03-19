defmodule Mix.Tasks.Ecto.Gen.Queries do
  @moduledoc """
  Task for running a generator to write query functions. All query functions are designed to be composable,
  as in a query is required as the first argument. The task takes command line options to control
  generating functions to only what is necessary. If a function already exists with the same name
  as a generated function, it will be skipped.

  ## Command line options
    * `--skip_fields` - won't generate field based query functions, aka by_field(query, field)

    * `--skip_assocs` - won't generate assoc based query functions, aka with_assoc(query)

    * `--skip_sort` - won't generate field sorting query functions, aka sort(query, "field_asc")

    * `--primary_key` - allows overriding the default primary key function generation when the pk isn't found in the file
  """
  use Mix.Task

  @preferred_cli_env :dev
  @shortdoc "Writes by_*, with_*, and sort functions based on the schema struct"
  @switches [
    skip_fields: :boolean,
    skip_assocs: :boolean,
    skip_sort: :boolean,
    quiet: :boolean,
    primary_key: :string
  ]
  @primary_key_default "id"

  defmodule SchemaMeta do
    defstruct primary_key: nil, functions: [], version: nil
  end

  @impl true
  def run(args) do
    defaults = [
      skip_fields: false,
      skip_assocs: false,
      skip_sort: false,
      quiet: false,
      primary_key: @primary_key_default
    ]

    {options, path} = OptionParser.parse!(args, strict: @switches)
    opts_with_defaults = defaults |> Keyword.merge(options) |> Enum.into(%{})

    generate(path, opts_with_defaults)
  end

  def generate(path_or_files, options) when is_list(path_or_files) do
    Enum.each(path_or_files, &generate(&1, options))
  end

  def generate(path_or_file, options) do
    if File.dir?(path_or_file) do
      with {:ok, files} <- File.ls(path_or_file) do
        Enum.each(files, fn file -> generate(path_or_file <> "/" <> file, options) end)
      end
    else
      case check_filename(path_or_file) do
        :ok -> generate_query_functions(path_or_file, options)
        {:error, reason} -> log(:red, :skipping, "because #{path_or_file} is #{reason}", options)
      end
    end
  end

  defp check_filename(filename) do
    cond do
      not String.ends_with?(filename, ".ex") ->
        {:error, "not a valid elixir file"}

      not File.exists?(filename) ->
        {:error, "not a file"}

      true ->
        :ok
    end
  end

  def generate_query_functions(filename, options) do
    log(:green, :generating, "schema functions for #{filename}", options)

    filestring = File.read!(filename)

    generated_regex =
      ~r/Module.register_attribute(__MODULE__, :schema_gen_tag, accumulate: true)?[\s\S]*\@schema_gen_tag\s.*\n/

    cleaned_filestring =
      case Regex.split(generated_regex, filestring) do
        [start, finish] ->
          start <> finish

        _ ->
          filestring
      end

    {_, version} =
      Macro.prewalk(Sourceror.parse_string!(filestring), nil, fn
        {:@, _meta1,
         [
           {:schema_gen_tag, _meta2, [{:__block__, _block_meta, [version]}]}
         ]} = ast,
        _acc ->
          {ast, version}

        other, acc ->
          {other, acc}
      end)

    with {:defmodule, module_meta,
          [
            {:__aliases__, alias_meta, module},
            [{{:__block__, _do_block_meta, [:do]}, {:__block__, _block_meta, module_children}}]
          ]} = ast <- Sourceror.parse_string!(cleaned_filestring) do
      {_, schema_meta} =
        Macro.prewalk(ast, %SchemaMeta{version: version}, fn
          {:@, _meta1, [{:primary_key, _meta2, [{:__block__, _meta3, [primary_key]}]}]} = ast,
          acc ->
            acc = if primary_key, do: Map.replace(acc, :primary_key, primary_key), else: acc
            {ast, acc}

          {:def, _meta1, [{:when, _meta2, [{fun_name, _, _} | _]} | _]} = ast,
          %{functions: functions} = acc ->
            {ast, Map.replace(acc, :functions, [fun_name | functions])}

          {:def, _meta1, [{fun_name, _meta2, _children} | _]} = ast,
          %{functions: functions} = acc ->
            {ast, Map.replace(acc, :functions, [fun_name | functions])}

          other, acc ->
            {other, acc}
        end)

      uniq_functions_schema_meta = Map.update!(schema_meta, :functions, &Enum.uniq/1)

      {_ast, generated_ast} =
        Macro.prewalk(ast, [], fn
          {:schema, _meta,
           [
             {:__block__, _block_meta, [schema_name]},
             [{{:__block__, _do_block_meta, [:do]}, _} | _]
           ]} = schema_block,
          _acc ->
            function_gen(schema_block, schema_name, uniq_functions_schema_meta, options)

          other, acc ->
            {other, acc}
        end)

      generated_ast = List.flatten(generated_ast)

      if generated_ast == [] do
        log(:red, :skipping, "because #{filename} has no generated functions", options)
      else
        old_version = schema_meta.version
        version = :md5 |> :crypto.hash(Sourceror.to_string(generated_ast)) |> Base.encode64()

        if old_version == version do
          log(:red, :skipping, "because #{filename} has no schema version changes", options)
        else
          new_ast =
            {:defmodule, module_meta,
             [
               {:__aliases__, alias_meta, module},
               [
                 do:
                   {:__block__, [],
                    List.flatten([
                      module_children
                      | [
                          leading_tag(version),
                          generated_ast,
                          generate_version_function(),
                          trailing_tag(version)
                        ]
                    ])}
               ]
             ]}

          case Macro.validate(new_ast) do
            :ok ->
              string = Sourceror.to_string(new_ast)

              File.write!(filename, string)

            error ->
              log(
                :red,
                :skipping,
                "because #{filename} has generated invalid ast: #{inspect(error)}",
                options
              )
          end
        end
      end
    else
      _ -> log(:red, :skipping, "because #{filename} is not readable", options)
    end
  end

  defp function_gen(schema_block, string_schema, schema_meta, options) do
    atom_schema = string_schema |> Inflex.singularize() |> String.to_atom()

    {_, field_meta} =
      Macro.prewalk(schema_block, %{fields: [], primary_key: nil}, fn
        {:field, _meta, [{:__block__, _block_meta, [field]}, _type_block, options_block]} =
            original,
        %{fields: fields} = acc ->
          if field_is_virtual?(options_block) do
            {original, acc}
          else
            acc =
              if field_is_primary_key?(options_block),
                do: Map.replace(acc, :primary_key, field),
                else: acc

            {original, Map.replace(acc, :fields, [field | fields])}
          end

        {:field, _meta, [{:__block__, _block_meta, [field]} | _]} = original,
        %{fields: fields} = acc ->
          {original, Map.replace(acc, :fields, [field | fields])}

        {:belongs_to, _meta,
         [
           {:__block__, _assoc_block_meta, [_assoc]},
           {:__aliases__, _alias_meta, _alias},
           options_block
         ]} = original,
        %{fields: fields} = acc ->
          foreign_key = find_foreign_key(options_block)
          {original, Map.replace(acc, :fields, [foreign_key | fields])}

        other, acc ->
          {other, acc}
      end)

    sort_functions =
      generate_sort_queries(field_meta.fields, atom_schema, schema_meta.functions, options)

    primary_key_function =
      if is_nil(field_meta.primary_key),
        do: generate_primary_key_query(schema_meta.primary_key, schema_meta.functions, options),
        else: []

    Macro.prewalk(schema_block, [primary_key_function | sort_functions], fn
      {:field, _meta, [{:__block__, _block_meta, [field]}, _type_block, options_block]} = original,
      acc ->
        if field_is_virtual?(options_block) do
          {original, acc}
        else
          {original, [generate_by_query(field, schema_meta.functions, options) | acc]}
        end

      {:field, _meta, [{:__block__, _block_meta, [field]} | _]} = original, acc ->
        {original, [generate_by_query(field, schema_meta.functions, options) | acc]}

      {:belongs_to, _meta,
       [
         {:__block__, _assoc_block_meta, [assoc]},
         {:__aliases__, _alias_meta, _alias},
         options_block
       ]} = original,
      acc ->
        foreign_key = find_foreign_key(options_block)

        {original,
         [
           generate_with_query(atom_schema, assoc, schema_meta.functions, options),
           generate_by_query(foreign_key, schema_meta.functions, options) | acc
         ]}

      {:has_many, _meta, [{:__block__, _block_meta, [assoc]} | _other]} = original, acc ->
        {original,
         [generate_with_query(atom_schema, assoc, schema_meta.functions, options) | acc]}

      {:has_one, _meta, [{:__block__, _block_meta, [assoc]} | _other]} = original, acc ->
        {original,
         [generate_with_query(atom_schema, assoc, schema_meta.functions, options) | acc]}

      {:many_to_many, _meta, [{:__block__, _block_meta, [assoc]} | _other]} = original, acc ->
        {original,
         [generate_with_query(atom_schema, assoc, schema_meta.functions, options) | acc]}

      other, acc ->
        {other, acc}
    end)
  end

  defp find_foreign_key(options_block) do
    Enum.reduce_while(options_block, nil, fn
      {{:__block__, _block_meta1, [:foreign_key]}, {:__block__, _block_meta2, [foreign_key]}},
      _ ->
        {:halt, foreign_key}

      _, acc ->
        {:cont, acc}
    end)
  end

  defp field_is_virtual?(options_block) do
    Enum.reduce_while(options_block, false, fn
      {{:__block__, _block_meta1, [:virtual]}, {:__block__, _block_meta2, [true]}}, _ ->
        {:halt, true}

      _, acc ->
        {:cont, acc}
    end)
  end

  defp field_is_primary_key?(options_block) do
    Enum.reduce_while(options_block, false, fn
      {{:__block__, _block_meta1, [:primary_key]}, {:__block__, _block_meta2, [true]}}, _ ->
        {:halt, true}

      _, acc ->
        {:cont, acc}
    end)
  end

  defp generate_primary_key_query(_primary_key, _functions, %{skip_fields: true}), do: []

  defp generate_primary_key_query(nil, functions, %{primary_key: primary_key} = options) do
    atomized_key = String.to_atom(primary_key)
    generate_by_query(atomized_key, functions, options)
  end

  defp generate_primary_key_query(primary_key, functions, options) do
    atomized_key = String.to_atom(primary_key)
    generate_by_query(atomized_key, functions, options)
  end

  defp generate_by_query(_field, _functions, %{skip_fields: true}), do: []

  defp generate_by_query(field, functions, _) do
    if Enum.member?(functions, :"by_#{field}") do
      []
    else
      [
        {:@, [],
         [
           {:spec, [],
            [
              {:"::", [],
               [
                 {:"by_#{field}", [],
                  [
                    {{:., [], [{:__aliases__, [], [:Ecto, :Queryable]}, :t]}, [], []},
                    {:any, [], nil}
                  ]},
                 {{:., [], [{:__aliases__, [], [:Ecto, :Queryable]}, :t]}, [], []}
               ]}
            ]}
         ]},
        {:def, [],
         [
           {:when, [],
            [
              {:"by_#{field}", [], [{:query, [], nil}, {:query_by, [], nil}]},
              {:is_list, [], [{:query_by, [], nil}]}
            ]},
           [
             do:
               {:from, [],
                [
                  {:in, [], [{:record, [], nil}, {:query, [], nil}]},
                  [
                    where:
                      {:in, [],
                       [
                         {{:., [], [{:record, [], nil}, field]}, [no_parens: true], []},
                         {:^, [], [{:query_by, [], nil}]}
                       ]}
                  ]
                ]}
           ]
         ]},
        {:def, [],
         [
           {:"by_#{field}", [], [{:query, [], nil}, nil]},
           [
             do:
               {:from, [],
                [
                  {:in, [], [{:record, [], nil}, {:query, [], nil}]},
                  [
                    where:
                      {:is_nil, [],
                       [
                         {{:., [], [{:record, [], nil}, field]}, [no_parens: true], []}
                       ]}
                  ]
                ]}
           ]
         ]},
        {:def, [],
         [
           {:"by_#{field}", [], [{:query, [], nil}, {:query_by, [], nil}]},
           [
             do:
               {:from, [],
                [
                  {:in, [], [{:record, [], nil}, {:query, [], nil}]},
                  [
                    where:
                      {:==, [],
                       [
                         {{:., [], [{:record, [], nil}, field]}, [no_parens: true], []},
                         {:^, [], [{:query_by, [], nil}]}
                       ]}
                  ]
                ]}
           ]
         ]}
      ]
    end
  end

  defp generate_sort_queries([], _schema, _functions, _opts), do: []
  defp generate_sort_queries(_fields, _schema, _functions, %{skip_sort: true}), do: []

  defp generate_sort_queries(fields, schema, functions, _opts) do
    if Enum.member?(functions, :sort) do
      []
    else
      [
        {:@, [],
         [
           {:spec, [],
            [
              {:"::", [],
               [
                 {:sort, [],
                  [
                    {{:., [], [{:__aliases__, [], [:Ecto, :Queryable]}, :t]}, [], []},
                    {:|, [], [{{:., [], [{:__aliases__, [], [:String]}, :t]}, [], []}, nil]}
                  ]},
                 {{:., [], [{:__aliases__, [], [:Ecto, :Queryable]}, :t]}, [], []}
               ]}
            ]}
         ]},
        {:def, [],
         [
           {:sort, [], [{:query, [], nil}, {:__block__, [], [nil]}]},
           [
             {{:__block__, [format: :keyword], [:do]}, {:query, [], nil}}
           ]
         ]},
        Enum.flat_map(fields, fn field ->
          [
            {:def, [],
             [
               {:sort, [], [{:query, [], nil}, "#{field}_asc"]},
               [
                 do:
                   {:order_by, [],
                    [
                      {:query, [], nil},
                      [{schema, {:schema_record, [], nil}}],
                      [asc: {{:., [], [{:schema_record, [], nil}, field]}, [no_parens: true], []}]
                    ]}
               ]
             ]},
            {:def, [],
             [
               {:sort, [], [{:query, [], nil}, "#{field}_desc"]},
               [
                 do:
                   {:order_by, [],
                    [
                      {:query, [], nil},
                      [{schema, {:schema_record, [], nil}}],
                      [
                        desc:
                          {{:., [], [{:schema_record, [], nil}, field]}, [no_parens: true], []}
                      ]
                    ]}
               ]
             ]}
          ]
        end)
      ]
    end
  end

  defp generate_with_query(_schema, _assoc, _functions, %{skip_assocs: true}), do: []

  defp generate_with_query(schema, assoc, functions, _opts) do
    if Enum.member?(functions, :"with_#{assoc}") do
      []
    else
      [
        {:@, [],
         [
           {:spec, [],
            [
              {:"::", [],
               [
                 {:"with_#{assoc}", [],
                  [
                    {{:., [], [{:__aliases__, [], [:Ecto, :Queryable]}, :t]}, [], []},
                    {{:., [], [{:__aliases__, [], [:Keyword]}, :t]}, [], []}
                  ]},
                 {{:., [], [{:__aliases__, [], [:Ecto, :Queryable]}, :t]}, [], []}
               ]}
            ]}
         ]},
        {:def, [],
         [
           {:"with_#{assoc}", [],
            [
              {:query, [], nil},
              {:\\, [], [{:opts, [], nil}, []]}
            ]},
           [
             do:
               {:__block__, [],
                [
                  {:=, [],
                   [
                     {:join_type, [], nil},
                     {{:., [], [{:__aliases__, [], [:Keyword]}, :get]}, [],
                      [{:opts, [], nil}, :join, :left]}
                   ]},
                  {:=, [],
                   [
                     {:single_preload, [], nil},
                     {{:., [], [{:__aliases__, [], [:Keyword]}, :get]}, [],
                      [{:opts, [], nil}, :single_preload, true]}
                   ]},
                  {:=, [],
                   [
                     {:base_query, [], nil},
                     {:join, [],
                      [
                        {:query, [], nil},
                        {:join_type, [], nil},
                        [{schema, {:schema_record, [], nil}}],
                        {:assoc, [], [{:schema_record, [], nil}, assoc]},
                        [as: assoc]
                      ]}
                   ]},
                  {:if, [],
                   [
                     {:single_preload, [], nil},
                     [
                       do:
                         {:preload, [],
                          [
                            {:base_query, [], nil},
                            [{assoc, {:record, [], nil}}],
                            [{assoc, {:record, [], nil}}]
                          ]},
                       else: {:preload, [], [{:base_query, [], nil}, [assoc]]}
                     ]
                   ]}
                ]}
           ]
         ]}
      ]
    end
  end

  defp generate_version_function do
    [
      {:@, [],
       [
         {:spec, [],
          [
            {:"::", [],
             [
               {:generated_schema_version, [], []},
               {{:., [],
                 [
                   {:__aliases__, [], [:String]},
                   :t
                 ]}, [], []}
             ]}
          ]}
       ]},
      {:def, [],
       [
         {:generated_schema_version, [], nil},
         [
           {{:__block__, [format: :keyword], [:do]},
            {{:., [], [List, :first]}, [],
             [
               {:@, [],
                [
                  {:schema_gen_tag, [], nil}
                ]}
             ]}}
         ]
       ]}
    ]
  end

  defp leading_tag(version) do
    [
      {{:., [],
        [
          {:__aliases__, [], [:Module]},
          :register_attribute
        ]}, [],
       [
         {:__MODULE__, [], nil},
         {:__block__, [], [:schema_gen_tag]},
         [
           {{:__block__, [format: :keyword], [:accumulate]}, {:__block__, [], [true]}}
         ]
       ]},
      {:@,
       [
         trailing_comments: [
           %{
             text: "# Anything between the schema_gen_tag module attributes is generated",
             line: nil,
             previous_eol_count: 1,
             column: nil,
             next_eol_count: 1
           },
           %{
             text: "# Any changes between the tags will be discarded on subsequent runs",
             line: nil,
             previous_eol_count: 1,
             column: nil,
             next_eol_count: 2
           }
         ],
         end_of_expression: [newlines: 0]
       ],
       [
         {:schema_gen_tag, [end_of_expression: [newlines: 0]], [{:__block__, [], [version]}]}
       ]}
    ]
  end

  defp trailing_tag(version) do
    {:@, [], [{:schema_gen_tag, [], [{:__block__, [], [version]}]}]}
  end

  defp log(color, command, message, opts) do
    unless opts.quiet do
      Mix.shell().info([color, "* #{command} ", :reset, message])
    end
  end
end
