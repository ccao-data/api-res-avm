# MINI TEMPLATE DOCKERFILE FOR CCAO APIS 

# Setup 
FROM rocker/r-ver:4.2.0
WORKDIR /api/
CMD ["Rscript", "api.R"]

# Install deps
ARG APT_DEPS="pkg-config libcurl4-openssl-dev libssl-dev libxml2-dev"
RUN apt-get update && apt-get install --no-install-recommends -y \
    $(echo $APT_DEPS) \
    && apt-get clean && apt-get autoremove --purge -y \
    && rm -rf /var/lib/apt/lists/* /tmp/*

COPY .Rprofile renv.lock .Renviron /api/
COPY renv/activate.R /api/renv/activate.R
RUN Rscript -e 'renv::settings$use.cache(FALSE); renv::restore()'

# Copy code
COPY . /api/
