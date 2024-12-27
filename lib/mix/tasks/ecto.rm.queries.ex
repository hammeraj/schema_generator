defmodule Mix.Tasks.Ecto.Rm.Queries do
  @moduledoc """
  Task for removing query functions generated by this library.
  Will remove any code or comments added between schema_gen_tag attributes

  ## Command line options
    N/A
  """
  use Mix.Task

  @preferred_cli_env :dev
  @shortdoc "Removes functions generated by SchemaGenerator"
  @switches [
    quiet: :boolean
  ]

  @impl true
  def run(args) do
    defaults = [
      quiet: false
    ]

    {options, path} = OptionParser.parse!(args, strict: @switches)
    opts_with_defaults = defaults |> Keyword.merge(options) |> Enum.into(%{})

    remove(path, opts_with_defaults)
  end

  def remove(path_or_files, options) when is_list(path_or_files) do
    Enum.each(path_or_files, &remove(&1, options))
  end

  def remove(path_or_file, options) do
    if File.dir?(path_or_file) do
      with {:ok, files} <- File.ls(path_or_file) do
        Enum.each(files, fn file -> remove(path_or_file <> "/" <> file, options) end)
      end
    else
      case check_filename(path_or_file) do
        :ok -> remove_query_functions(path_or_file, options)
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

  defp remove_query_functions(filename, options) do
    log(:green, :removing, "schema functions for #{filename}", options)

    filestring = File.read!(filename)

    generated_regex =
      ~r/Module.register_attribute(__MODULE__, :schema_gen_tag, accumulate: true)?[\s\S]*\@schema_gen_tag\s.*\n/

    new_filestring =
      case Regex.split(generated_regex, filestring) do
        [start, finish] ->
          start <> finish

        _ ->
          filestring
      end

    new_ast = Sourceror.parse_string!(new_filestring)

    case Macro.validate(new_ast) do
      :ok ->
        string = Sourceror.to_string(new_ast)

        File.write!(filename, string <> "\n")

      error ->
        log(
          :red,
          :skipping,
          "because #{filename} has generated invalid ast: #{inspect(error)}",
          options
        )
    end
  end

  defp log(color, command, message, opts) do
    unless opts.quiet do
      Mix.shell().info([color, "* #{command} ", :reset, message])
    end
  end
end
