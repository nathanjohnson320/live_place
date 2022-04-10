defmodule Serialize do
  use Ecto.Type

  def type, do: :binary
  def cast(any), do: {:ok, any}
  def load(binary), do: {:ok, :erlang.binary_to_term(binary, [:safe])}
  def dump(term), do: {:ok, :erlang.term_to_binary(term)}
end
