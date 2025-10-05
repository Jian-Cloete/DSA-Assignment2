FROM ballerina/ballerina:2201.12.9

WORKDIR /app

# Copy the service files
COPY Ballerina.toml .
COPY main.bal .

# Build the service
RUN bal build

EXPOSE 9090

# Run the service
CMD ["bal", "run"]

