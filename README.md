# api-res-avm

REST API for querying predicted values from the CCAO's residential model.

## API documentation

See [the API docs](https://datascience.cookcountyassessor.com/api/res_avm/__docs__/)
for detailed instructions regarding request parameters and response
formats. Note that this URL is only accessible on the County VPN.

There are two main endpoints that the API exposes:

* **`POST /predict`**: Returns predictions for the default model, which
  should always be the CCAO's most recent final model
* **`POST /predict/<run_id>`**: Returns predictions for a specific model based
  on its run ID, which allows you to retrieve predictions using historical
  models

## Deployment

We deploy the API using a Docker Compose service exposed to a port on our server
that we reverse proxy via [our Nginx
service](https://github.com/ccao-data/service-nginx).

### Adding a new model

To add a new model, add it to [the `valid_runs` config object in
`api.R`](https://github.com/ccao-data/api-res-avm/blob/3ae93e4aef32671587c1eb816277d3d6d20ede3a/api.R#L34-L61).
This config objects controls the list of valid run IDs that users can append to
the `/predict` endpoint to return a prediction for a specific model. Then,
restart the Docker Compose service by running `docker compose restart` to load
the new version of the `api.R` module.

### Updating the default model

To update the default model that the API will use when no run ID is present in
the `/predict` endpoint, update the `.env` file in the root of the deployment
repo and change the value of the `AWS_S3_DEFAULT_MODEL_RUN_ID` env var to point
to the run ID of the new default model. Bring the service down by running
`docker compose down`, and then bring it back up by running
`docker compose up -d`. Note that it's important that we perform `down` and
then `up` in this case, because `docker compose restart` [does not reload
environment variables defined in the Docker Compose
config](https://docs.docker.com/reference/cli/docker/compose/restart/).

### Deploying code changes

Follow these steps to deploy new code changes to the production environment:

* Merge your PR to the main branch
* Wait for the [`docker-build`
  workflow](https://github.com/ccao-data/api-res-avm/actions/workflows/docker-build.yaml)
  to complete execution on the main branch, so that it pushes the most recent
  Docker image to the GitHub Docker registry
* SSH into the server as the Shiny user and navigate to the prod directory
* Confirm that the prod directory is on the main branch by running `git status`
* Pull the latest code changes from the main branch by running `git pull origin master`
* Pull the latest Docker image that the `docker-build` workflow built by running
  `docker pull ghcr.io/ccao-data/api-res-avm`
* Stop the running API service by running `docker compose down`
* Restart the API service with the new image by running `docker compose up -d`
* Watch the API logs with `docker compose logs -f` and wait until the service
  prints a log line confirming that the API is running
* Attempt to load [the API docs
  page](https://datascience.cookcountyassessor.com/api/res_avm/__docs__/) to
  confirm that the API service is running properly
