defmodule SchemaGenerator.NonSchema do
  def a do
    "a"
  end

  def b do
    "b"
  end

  def ab do
    a() + b()
  end
end
