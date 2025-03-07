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
    field(:name1, :string)
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

  Module.register_attribute(__MODULE__, :schema_gen_tag, accumulate: true)
  @schema_gen_tag "f+ZT8MJbpduGXvs+8/AeYw=="

  # Anything between the schema_gen_tag module attributes is generated
  # Any changes between the tags will be discarded on subsequent runs
  @spec with_office(Ecto.Queryable.t(), Keyword.t()) :: Ecto.Queryable.t()
  def with_office(query, opts \\ []) do
    join_type = Keyword.get(opts, :join, :left)
    single_preload = Keyword.get(opts, :single_preload, true)

    base_query =
      join(query, join_type, [user: schema_record], assoc(schema_record, :office), as: :office)

    if single_preload do
      preload(base_query, [office: record], office: record)
    else
      preload(base_query, [:office])
    end
  end

  @spec with_posts(Ecto.Queryable.t(), Keyword.t()) :: Ecto.Queryable.t()
  def with_posts(query, opts \\ []) do
    join_type = Keyword.get(opts, :join, :left)
    single_preload = Keyword.get(opts, :single_preload, true)

    base_query =
      join(query, join_type, [user: schema_record], assoc(schema_record, :posts), as: :posts)

    if single_preload do
      preload(base_query, [posts: record], posts: record)
    else
      preload(base_query, [:posts])
    end
  end

  @spec by_guid(Ecto.Queryable.t(), any) :: Ecto.Queryable.t()
  def by_guid(query, query_by) when is_list(query_by) do
    from(record in query, where: record.guid in ^query_by)
  end

  def by_guid(query, nil) do
    from(record in query, where: is_nil(record.guid))
  end

  def by_guid(query, query_by) do
    from(record in query, where: record.guid == ^query_by)
  end

  @spec by_name(Ecto.Queryable.t(), any) :: Ecto.Queryable.t()
  def by_name(query, query_by) when is_list(query_by) do
    from(record in query, where: record.name in ^query_by)
  end

  def by_name(query, nil) do
    from(record in query, where: is_nil(record.name))
  end

  def by_name(query, query_by) do
    from(record in query, where: record.name == ^query_by)
  end

  @spec by_age(Ecto.Queryable.t(), any) :: Ecto.Queryable.t()
  def by_age(query, query_by) when is_list(query_by) do
    from(record in query, where: record.age in ^query_by)
  end

  def by_age(query, nil) do
    from(record in query, where: is_nil(record.age))
  end

  def by_age(query, query_by) do
    from(record in query, where: record.age == ^query_by)
  end

  @spec by_password(Ecto.Queryable.t(), any) :: Ecto.Queryable.t()
  def by_password(query, query_by) when is_list(query_by) do
    from(record in query, where: record.password in ^query_by)
  end

  def by_password(query, nil) do
    from(record in query, where: is_nil(record.password))
  end

  def by_password(query, query_by) do
    from(record in query, where: record.password == ^query_by)
  end

  @spec by_accepted_terms?(Ecto.Queryable.t(), any) :: Ecto.Queryable.t()
  def by_accepted_terms?(query, query_by) when is_list(query_by) do
    from(record in query, where: record.accepted_terms? in ^query_by)
  end

  def by_accepted_terms?(query, nil) do
    from(record in query, where: is_nil(record.accepted_terms?))
  end

  def by_accepted_terms?(query, query_by) do
    from(record in query, where: record.accepted_terms? == ^query_by)
  end

  @spec by_country(Ecto.Queryable.t(), any) :: Ecto.Queryable.t()
  def by_country(query, query_by) when is_list(query_by) do
    from(record in query, where: record.country in ^query_by)
  end

  def by_country(query, nil) do
    from(record in query, where: is_nil(record.country))
  end

  def by_country(query, query_by) do
    from(record in query, where: record.country == ^query_by)
  end

  @spec by_office_id(Ecto.Queryable.t(), any) :: Ecto.Queryable.t()
  def by_office_id(query, query_by) when is_list(query_by) do
    from(record in query, where: record.office_id in ^query_by)
  end

  def by_office_id(query, nil) do
    from(record in query, where: is_nil(record.office_id))
  end

  def by_office_id(query, query_by) do
    from(record in query, where: record.office_id == ^query_by)
  end

  @spec by_updated_at(Ecto.Queryable.t(), any) :: Ecto.Queryable.t()
  def by_updated_at(query, query_by) when is_list(query_by) do
    from(record in query, where: record.updated_at in ^query_by)
  end

  def by_updated_at(query, nil) do
    from(record in query, where: is_nil(record.updated_at))
  end

  def by_updated_at(query, query_by) do
    from(record in query, where: record.updated_at == ^query_by)
  end

  @spec by_inserted_at(Ecto.Queryable.t(), any) :: Ecto.Queryable.t()
  def by_inserted_at(query, query_by) when is_list(query_by) do
    from(record in query, where: record.inserted_at in ^query_by)
  end

  def by_inserted_at(query, nil) do
    from(record in query, where: is_nil(record.inserted_at))
  end

  def by_inserted_at(query, query_by) do
    from(record in query, where: record.inserted_at == ^query_by)
  end

  @spec sort(Ecto.Queryable.t(), String.t() | nil) :: Ecto.Queryable.t()
  def sort(query, nil), do: query

  def sort(query, "name_asc") do
    order_by(query, [user: schema_record], asc: schema_record.name)
  end

  def sort(query, "age_desc") do
    order_by(query, [user: schema_record], desc: schema_record.age)
  end

  def sort(query, "age_asc") do
    order_by(query, [user: schema_record], asc: schema_record.age)
  end

  def sort(query, "password_desc") do
    order_by(query, [user: schema_record], desc: schema_record.password)
  end

  def sort(query, "password_asc") do
    order_by(query, [user: schema_record], asc: schema_record.password)
  end

  def sort(query, "accepted_terms?_desc") do
    order_by(query, [user: schema_record], desc: schema_record.accepted_terms?)
  end

  def sort(query, "accepted_terms?_asc") do
    order_by(query, [user: schema_record], asc: schema_record.accepted_terms?)
  end

  def sort(query, "country_desc") do
    order_by(query, [user: schema_record], desc: schema_record.country)
  end

  def sort(query, "country_asc") do
    order_by(query, [user: schema_record], asc: schema_record.country)
  end

  def sort(query, "office_id_desc") do
    order_by(query, [user: schema_record], desc: schema_record.office_id)
  end

  def sort(query, "office_id_asc") do
    order_by(query, [user: schema_record], asc: schema_record.office_id)
  end

  def sort(query, "inserted_at_desc") do
    order_by(query, [user: schema_record], desc: schema_record.inserted_at)
  end

  def sort(query, "inserted_at_asc") do
    order_by(query, [user: schema_record], asc: schema_record.inserted_at)
  end

  def sort(query, "updated_at_desc") do
    order_by(query, [user: schema_record], desc: schema_record.updated_at)
  end

  def sort(query, "updated_at_asc") do
    order_by(query, [user: schema_record], asc: schema_record.updated_at)
  end

  @tag :sg_override
  def sort(query, "name_desc") do
    # this function is kept and replaces the generated one
    order_by(query, [user: u], desc: u.name)
  end

  @tag :sg_override
  def sort(query, filter) when filter in ["a", "b"] do
    # this function is kept but the args aren't matched to anything
    order_by(query, [user: u], desc: u.name)
  end

  @spec generated_schema_version() :: String.t()
  def generated_schema_version, do: @schema_gen_tag
  @schema_gen_tag "f+ZT8MJbpduGXvs+8/AeYw=="
end
