## Bloat server

Compute delta in artifact size between consecutive package releases on Github.

### Example usage

Start the associated docker container with the following command:
```
docker run -p 8080:8080 kstephens/bloatserver
```

The server will be listening on port 8080. To send a request to the server
(depending on the port mapping specified in the docker run command):
```
curl localhost:8080/apache/airflow/bloat?start=v2.8.3&end=v2.9.2
```
