defmodule MixTestInteractive.Settings do
  @moduledoc """
  Interactive mode settings.

  Keeps track of the current settings of `MixTestInteractive.InteractiveMode`, making changes
  in response to user commands.
  """

  use TypedStruct

  alias MixTestInteractive.PatternFilter
  alias MixTestInteractive.TestFiles

  @default_list_all_files &TestFiles.list/0

  typedstruct do
    field :failed?, boolean(), default: false
    field :initial_cli_args, [String.t()], default: []
    field :list_all_files, (-> [String.t()]), default: @default_list_all_files
    field :patterns, [String.t()], default: []
    field :stale?, boolean(), default: false
    field :watching?, boolean(), default: true
  end

  @doc """
  Assemble command-line arguments to pass to `mix test`.

  Includes arguments originally passed to `mix test.interactive` when it was started
  as well as arguments based on the current interactive mode settings.
  """
  @spec cli_args(t()) :: {:ok, [String.t()]} | {:error, :no_matching_files}
  def cli_args(%__MODULE__{initial_cli_args: initial_args} = settings) do
    with {:ok, args} <- args_from_settings(settings) do
      {:ok, initial_args ++ args}
    end
  end

  @doc """
  Toggle file-watching mode on or off.
  """
  @spec toggle_watch_mode(t()) :: t()
  def toggle_watch_mode(settings) do
    %{settings | watching?: !settings.watching?}
  end

  @doc """
  Provide a list of file-name filter patterns.

  Only test filenames matching one or more patterns will be run.
  """
  @spec only_patterns(t(), [String.t()]) :: t()
  def only_patterns(settings, patterns) do
    settings
    |> all_tests()
    |> Map.put(:patterns, patterns)
  end

  @doc """
  Update settings to only run failing tests.

  Corresponds to `mix test --failed`.
  """
  @spec only_failed(t()) :: t()
  def only_failed(settings) do
    settings
    |> all_tests()
    |> Map.put(:failed?, true)
  end

  @doc """
  Update settings to only run "stale" tests.

  Corresponds to `mix test --stale`.
  """
  @spec only_stale(t()) :: t()
  def only_stale(settings) do
    settings
    |> all_tests()
    |> Map.put(:stale?, true)
  end

  @doc """
  Update settings to run all tests, removing any flags or filter patterns.
  """
  @spec all_tests(t()) :: t()
  def all_tests(settings) do
    %{settings | failed?: false, patterns: [], stale?: false}
  end

  @doc false
  def list_files_with(settings, list_fn) do
    %{settings | list_all_files: list_fn}
  end

  @doc """
  Return a text summary of the current interactive mode settings.
  """
  @spec summary(t()) :: String.t()
  def summary(settings) do
    cond do
      settings.failed? ->
        "Ran only failed tests"

      settings.stale? ->
        "Ran only stale tests"

      !Enum.empty?(settings.patterns) ->
        "Ran all test files matching #{Enum.join(settings.patterns, ", ")}"

      true ->
        "Ran all tests"
    end
  end

  defp args_from_settings(%__MODULE__{failed?: true}) do
    {:ok, ["--failed"]}
  end

  defp args_from_settings(%__MODULE__{stale?: true}) do
    {:ok, ["--stale"]}
  end

  defp args_from_settings(%__MODULE__{patterns: patterns} = settings) when length(patterns) > 0 do
    case PatternFilter.matches(settings.list_all_files.(), patterns) do
      [] -> {:error, :no_matching_files}
      files -> {:ok, files}
    end
  end

  defp args_from_settings(_config), do: {:ok, []}
end
