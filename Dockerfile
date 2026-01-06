# Use a slim version of R
FROM rocker/shiny:latest

# Install system dependencies for MySQL and SSL
RUN apt-get update && apt-get install -y \
    libssl-dev \
    libmysqlclient-dev \
    && rm -rf /var/lib/apt/lists/*

# Install the R packages you need
RUN R -e "install.packages(c('shiny', 'shinyjs', 'DBI', 'RMySQL', 'pool', 'sodium'), repos='https://cran.rstudio.com/')"

# Copy your app code into the Docker image
COPY . /srv/shiny-server/

# Expose the port Shiny runs on
EXPOSE 3838

# Run the app
CMD ["/usr/bin/shiny-server"]