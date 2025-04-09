### Key Points
CarparkAvailability API uses a 1-minute scheduler for live updates.
Used an online JS script for SVY21 (Singapore coordinate system) -> WGS84 (global coordinate system) conversion.
Used an online reference to calculate the distance between two GeoJSON points.
Applied validation on user input at the initial stage to avoid unnecessary steps.
Fetched the API's data as a next step to check if the API is working before loading the dataset to avoid unnecessary memory load.
