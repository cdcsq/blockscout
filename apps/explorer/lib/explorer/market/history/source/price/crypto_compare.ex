defmodule Explorer.Market.History.Source.Price.CryptoCompare do
  @moduledoc """
  Adapter for fetching market history from https://cryptocompare.com.

  The history is fetched for the configured coin. You can specify a
  different coin by changing the targeted coin.

      # In config.exs
      config :explorer, coin: "POA"

  """

  alias Explorer.Market.History.Source.Price, as: SourcePrice
  alias HTTPoison.Response

  @behaviour SourcePrice

  @typep unix_timestamp :: non_neg_integer()

  @impl SourcePrice
  def fetch_price_history(previous_days, secondary_coin?) do
    url = history_url(previous_days, secondary_coin?)
    headers = [{"Content-Type", "application/json"}]

    case HTTPoison.get(url, headers) do
      {:ok, %Response{body: body, status_code: 200}} ->
        result =
          body
          |> format_data(secondary_coin?)
          |> reject_zeros()

        {:ok, result}

      _ ->
        :error
    end
  end

  @spec base_url :: String.t()
  defp base_url do
    configured_url = Application.get_env(:explorer, __MODULE__, [])[:base_url]
    configured_url || "https://min-api.cryptocompare.com"
  end

  @spec date(unix_timestamp()) :: Date.t()
  def date(unix_timestamp) do
    unix_timestamp
    |> DateTime.from_unix!()
    |> DateTime.to_date()
  end

  @spec format_data(String.t(), boolean()) :: [SourcePrice.record()]
  defp format_data(data, secondary_coin?) do
    json = Jason.decode!(data)

    for item <- json["Data"] do
      %{
        closing_price: Decimal.new(to_string(item["close"])),
        date: date(item["time"]),
        opening_price: Decimal.new(to_string(item["open"])),
        secondary_coin: secondary_coin?
      }
    end
  end

  @spec history_url(non_neg_integer(), boolean()) :: String.t()
  defp history_url(previous_days, secondary_coin?) do
    fsym = if secondary_coin?, do: config(:secondary_coin_symbol), else: Explorer.coin()

    query_params = %{
      "fsym" => fsym,
      "limit" => previous_days,
      "tsym" => "USD"
    }

    "#{base_url()}/data/histoday?#{URI.encode_query(query_params)}"
  end

  defp reject_zeros(items) do
    Enum.reject(items, fn item ->
      Decimal.equal?(item.closing_price, 0) && Decimal.equal?(item.opening_price, 0)
    end)
  end

  @spec config(atom()) :: term
  defp config(key) do
    Application.get_env(:explorer, __MODULE__, [])[key]
  end
end
