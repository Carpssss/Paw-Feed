FROM rocker/shiny:latest

# Install System Dependencies (Postgres & Security)
RUN apt-get update && apt-get install -y \
    libssl-dev \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install R Packages
RUN R -e "install.packages(c('shiny', 'shinyjs', 'DBI', 'RPostgres', 'pool'), repos='https://cran.rstudio.com/')"

# --- CACHE BUSTER ---
# Changing this line forces Render to re-copy your app files
ENV REFRESHED_AT=2026-01-14

# Clear old app and copy NEW app
RUN rm -rf /srv/shiny-server/*
COPY . /srv/shiny-server/
RUN chown -R shiny:shiny /srv/shiny-server/

# Run as shiny user
USER shiny
EXPOSE 3838
CMD ["/usr/bin/shiny-server"]
