from python:3.13.1

RUN adduser --uid 65500 --group bloatserver --system --home /home/bloatserver

COPY --chown=bloatserver:bloatserver src /home/bloatserver

RUN pip install --no-cache-dir -r /home/bloatserver/requirements.txt

WORKDIR /home/bloatserver
USER bloatserver
EXPOSE 8080

ENTRYPOINT python app.py
