FROM rocker/shiny:latest

# 1. UPDATED: Removed libmysqlclient-dev, added libpq-dev (Required for Postgres)
RUN apt-get update && apt-get install -y \
    libssl-dev \
    libpq-dev \
    libsodium-dev \
    && rm -rf /var/lib/apt/lists/*

# 2. UPDATED: Removed 'RMariaDB', added 'RPostgres'
RUN R -e "install.packages(c('shiny', 'shinyjs', 'DBI', 'RPostgres', 'pool', 'sodium'), repos='https://cran.rstudio.com/')"

# 3. Clean, Copy, and Set Permissions (This part remains the same)
RUN rm -rf /srv/shiny-server/*
COPY . /srv/shiny-server/
RUN chown -R shiny:shiny /srv/shiny-server/

# 4. Important: Ensure Shiny runs as the user 'shiny'
USER shiny
EXPOSE 3838
CMD ["/usr/bin/shiny-server"]
