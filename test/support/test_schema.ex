defmodule SchemaGenerator.TestSchema do
  @moduledoc """
    Schema to use for testing generation
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  Module.register_attribute(__MODULE__, :default_country, persist: true)

  @default_country "USA"
  @required [:name, :password]
  @optional [:age, :accepted_terms?]
  @type t :: %__MODULE__{}

  schema "users" do
    field(:name, :string)
    field(:age, :integer, default: 0)
    field(:password, :string, redact: true)
    field(:birth_year, :integer, virtual: true)
    field(:accepted_terms?, :boolean, default: false)
    field(:country, :string, default: @default_country)
    belongs_to(:office, Office, foreign_key: :office_id)
    has_many(:posts, Post)

    timestamps()
  end

  # A comment for testing comments
  # make sure it stays
  @spec changeset(__MODULE__.t(), map()) :: Ecto.Changeset.t()
  def changeset(user \\ %__MODULE__{}, attrs \\ %{}) do
    user
    |> cast(attrs, @optional ++ @required)
    |> cast_assoc(:posts)
  end
end
