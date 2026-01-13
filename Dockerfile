FROM rocker/shiny:latest

# Removed libsodium-dev
RUN apt-get update && apt-get install -y \
    libssl-dev \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Removed 'sodium' from install list
RUN R -e "install.packages(c('shiny', 'shinyjs', 'DBI', 'RPostgres', 'pool'), repos='https://cran.rstudio.com/')"

RUN rm -rf /srv/shiny-server/*
COPY . /srv/shiny-server/
RUN chown -R shiny:shiny /srv/shiny-server/

USER shiny
EXPOSE 3838
CMD ["/usr/bin/shiny-server"]
