# Run as: iex --dot-iex path/to/notebook.exs

# Title: Car Parking Problem

Mix.install([
  {:httpoison, "~> 1.8"},
  {:jason, "~> 1.2"},
  {:nimble_csv, "~> 1.2"}
])

# ── Section ──

NimbleCSV.define(CSVParser, separator: ",", escape: "\"")

{:ok, csv_content} = "/home/livebook/.local/share/livebook/autosaved/2025_04_09/05_06_2ssw/files/HDBCarparkInformation.csv"
|> File.read()

csv_content
|> CSVParser.parse_string()
|> Enum.map(fn [car_park_no, address, x_coord, y_coord | _] ->
  %{car_park_no: car_park_no, address: address, x_coord: x_coord, y_coord: y_coord}
end)

defmodule Carpark do
  defstruct [
    :number,
    :address,
    :location,
    :total_lots,
    :available_lots,
    :distance
  ]
end

# source: https://github.com/cgcai/SVY21/blob/master/Javascript/svy21.js
defmodule SVY21 do
  @a 6378137.0
  @f 1 / 298.257223563

  @o_lat_deg 1.366666
  @o_lon_deg 103.833333
  @o_n 38744.572
  @o_e 28001.642
  @k 1.0

  @b @a * (1 - @f)
  @e2 (2 * @f) - (@f * @f)
  @e4 @e2 * @e2
  @e6 @e4 * @e2

  @a0 1 - (@e2 / 4) - (3 * @e4 / 64) - (5 * @e6 / 256)
  @a2 (3.0 / 8.0) * (@e2 + (@e4 / 4) + (15 * @e6 / 128))
  @a4 (15.0 / 256.0) * (@e4 + (3 * @e6 / 4))
  @a6 35 * @e6 / 3072

  @deg_to_rad :math.pi() / 180
  @rad_to_deg 180 / :math.pi()

  def compute_lat_lon(northing, easting) do
    n_prime = northing - @o_n
    m_o = calc_m(@o_lat_deg)
    m_prime = m_o + (n_prime / @k)

    n = (@a - @b) / (@a + @b)
    n2 = n * n
    n3 = n2 * n
    n4 = n2 * n2

    g = @a * (1 - n) * (1 - n2) * (1 + (9 * n2 / 4) + (225 * n4 / 64)) * @deg_to_rad
    sigma = (m_prime * :math.pi()) / (180.0 * g)

    lat_prime = 
      sigma +
      (((3 * n / 2) - (27 * n3 / 32)) * :math.sin(2 * sigma)) +
      (((21 * n2 / 16) - (55 * n4 / 32)) * :math.sin(4 * sigma)) +
      ((151 * n3 / 96) * :math.sin(6 * sigma)) +
      ((1097 * n4 / 512) * :math.sin(8 * sigma))

    sin_lat = :math.sin(lat_prime)
    sin2_lat = sin_lat * sin_lat

    rho = calc_rho(sin2_lat)
    v = calc_v(sin2_lat)
    psi = v / rho
    psi2 = psi * psi
    psi3 = psi2 * psi
    psi4 = psi3 * psi

    t = :math.tan(lat_prime)
    t2 = t * t
    t4 = t2 * t2
    t6 = t4 * t2

    e_prime = easting - @o_e
    x = e_prime / (@k * v)
    x2 = x * x
    x3 = x2 * x
    x5 = x3 * x2
    x7 = x5 * x2

    # Compute Latitude
    lat_term1 = t / (@k * rho) * ((e_prime * x) / 2)
    lat_term2 = t / (@k * rho) * ((e_prime * x3) / 24) * ((-4 * psi2) + (9 * psi) * (1 - t2) + (12 * t2))
    lat_term3 = t / (@k * rho) * ((e_prime * x5) / 720) *
       ((8 * psi4) * (11 - 24 * t2) -
       (12 * psi3) * (21 - 71 * t2) +
       (15 * psi2) * (15 - 98 * t2 + 15 * t4) +
       (180 * psi) * (5 * t2 - 3 * t4) +
       360 * t4)
    lat_term4 = t / (@k * rho) * ((e_prime * x7) / 40320) * (1385 - 3633 * t2 + 4095 * t4 + 1575 * t6)

    lat_rad = lat_prime - lat_term1 + lat_term2 - lat_term3 + lat_term4
    lat_deg = lat_rad * @rad_to_deg

    # Compute Longitude
    sec_lat = 1.0 / :math.cos(lat_rad)
    lon_term1 = x * sec_lat
    lon_term2 = ((x3 * sec_lat) / 6) * (psi + 2 * t2)
    lon_term3 = ((x5 * sec_lat) / 120) *
       (((-4 * psi3) * (1 - 6 * t2)) +
       (psi2 * (9 - 68 * t2)) +
       (72 * psi * t2) +
       (24 * t4))
    lon_term4 = ((x7 * sec_lat) / 5040) * (61 + 662 * t2 + 1320 * t4 + 720 * t6)

    lon_rad = @o_lon_deg * @deg_to_rad + lon_term1 - lon_term2 + lon_term3 - lon_term4
    lon_deg = lon_rad * @rad_to_deg

    {lat_deg, lon_deg}
  end

  defp calc_m(lat_deg) do
    lat_rad = lat_deg * @deg_to_rad
    @a * (
      (@a0 * lat_rad) -
      (@a2 * :math.sin(2 * lat_rad)) +
      (@a4 * :math.sin(4 * lat_rad)) -
      (@a6 * :math.sin(6 * lat_rad))
    )
  end

  defp calc_rho(sin2_lat) do
    num = @a * (1 - @e2)
    denom = :math.pow(1 - @e2 * sin2_lat, 1.5)
    num / denom
  end

  defp calc_v(sin2_lat) do
    poly = 1 - @e2 * sin2_lat
    @a / :math.sqrt(poly)
  end
end

defmodule CarparkFinder do
  @min_lat -90.0
  @max_lat 90.0
  @min_lon -180.0
  @max_lon 180.0
  
  defp x_y_to_lat_lon(x, y), do: {y, x}

  defp validate_lat_lon(lat, lon) when is_number(lat) and is_number(lon) do
    cond do
      lat < @min_lat or lat > @max_lat ->
        {:error, "Latitude #{lat} is out of bounds (#{@min_lat}–#{@max_lat})"}

      lon < @min_lon or lon > @max_lon ->
        {:error, "Longitude #{lon} is out of bounds (#{@min_lon}–#{@max_lon})"}

      true ->
        :ok
    end
  end

  defp validate_lat_lon(_, _) do
    {:error, "Invalid input types: latitude and longitude must be numbers"}
  end

  # source: https://www.movable-type.co.uk/scripts/latlong.html
  defp haversine_distance(lat1, lon1, lat2, lon2) do
    earth_radius_km = 6_378.0
    to_rad = &(&1 * :math.pi() / 180)

    lat1_rad = to_rad.(lat1)
    lat2_rad = to_rad.(lat2)
    delta_lat = to_rad.(lat2 - lat1)
    delta_lon = to_rad.(lon2 - lon1)

    a =
      :math.sin(delta_lat / 2) ** 2 +
        :math.cos(lat1_rad) * :math.cos(lat2_rad) * :math.sin(delta_lon / 2) ** 2
    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))
    earth_radius_km * c
  end

  defp load_dataset(csv_path) do
    csv_path
    |> File.read!()
    |> CSVParser.parse_string(skip_headers: true)
    |> Enum.reduce([], fn
      [car_park_no, address, x_str, y_str | _rest], acc ->
        with {x, ""} <- Float.parse(x_str),
             {y, ""} <- Float.parse(y_str) do
          {lat_svy21, lon_svy21} = x_y_to_lat_lon(x, y)
          {lat, lon} = SVY21.compute_lat_lon(lat_svy21, lon_svy21)
          
          carpark = %Carpark{
            number: car_park_no,
            address: address,
            location: %{latitude: lat, longitude: lon}
          }

          [carpark | acc]
        else
          _ -> acc
        end

      _, acc ->
        acc
    end)
  end

  defp fetch_availability(url) do
    case HTTPoison.get(url) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %{status_code: code}} ->
        {:error, "Status #{code}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_availability_map(%{"items" => [%{"carpark_data" => data}]}) do
    Enum.reduce(data, %{}, fn %{"carpark_number" => num, "carpark_info" => [info | _]}, acc ->
      Map.put(acc, num, %{
        total_lots: info["total_lots"] |> String.to_integer(),
        available_lots: info["lots_available"] |> String.to_integer()
      })
    end)
  end

  defp find_nearest_with_availability(user_lat, user_lon, carparks_data, availability_map) do
    carparks_data
    |> Enum.map(fn %Carpark{} = carpark ->
      case Map.get(availability_map, carpark.number) do
        %{total_lots: total_lots, available_lots: available_lots} when available_lots > 0 ->
          distance = haversine_distance(user_lat, user_lon, carpark.location.latitude, carpark.location.longitude)
          %Carpark{carpark | total_lots: total_lots, available_lots: available_lots, distance: distance}

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.distance)
  end

  def find_available_nearby(user_lat, user_lon, datetime \\ nil) do
    datetime = datetime || DateTime.utc_now() |> DateTime.to_iso8601() # optional
    api_url = "#{"https://api.data.gov.sg/v1/transport/carpark-availability"}?date_time=#{URI.encode(datetime)}"
    csv_path = "/home/livebook/.local/share/livebook/autosaved/2025_04_09/05_06_2ssw/files/HDBCarparkInformation.csv"
    
    with :ok <- validate_lat_lon(user_lat, user_lon),
         {:ok, raw_data} <- fetch_availability(api_url) do
      carparks_data = load_dataset(csv_path)
      availability_map = get_availability_map(raw_data)
      find_nearest_with_availability(user_lat, user_lon, carparks_data, availability_map)
    else
      {:error, message} -> message
      error -> error
    end
  end
end


# 1.2648407, 103.8188719
user_lat = 1.350
user_lon = 103.870

CarparkFinder.find_available_nearby(user_lat, user_lon)

CarparkFinder.find_available_nearby("1.350", "103.870")

CarparkFinder.find_available_nearby(1999.350, 103.870)

CarparkFinder.find_available_nearby(1.350, 1030.870)
