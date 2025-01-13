import flask
import gevent.pywsgi as gevent
import packaging.version as version

import deltas

from github.GithubException import UnknownObjectException


app = flask.Flask(__name__)

@app.route('/<owner>/<repo>/bloat')
def compute_bloat(owner, repo):
    # this has no logging and only minimal error handling. both would be
    # required for a produciton application. omitted here for expediency
    try:
        rb = deltas.RepoBloat(owner, repo)
    except UnknownObjectException:
        return {
            'error': {'code': 404, 'message': 'Invalid owner or repo'}
        }, 404

    start = flask.request.args.get('start', None)
    # handle case of empty 'start' param, ie 'start='
    if start == '':
        start = None

    stop = flask.request.args.get('end', None)
    # handle case of empty 'end' param, ie 'end='
    if stop == '':
        stop = None

    if start and start.startswith('v'):
        start = start[1:]

    if stop and stop.startswith('v'):
        stop = stop[1:]

    if start:
        try:
            start_version = version.Version(start)
        except version.InvalidVersion:
            return {
                'error': {'code': 400, 'message': 'Invalid start version'}
            }, 400

    if stop:
        try:
            stop_version = version.Version(stop)
        except version.InvalidVersion:
            return {
                'error': {'code': 400, 'message': 'Invalid stop version'}
            }, 400

    if start and stop:
        if start_version >= stop_version:
            return {
                'error': {'code': 400, 'message': 'Start version >= stop version'}
            }, 400

    try:
        return {
            'deltas': rb.get_bloat(start=start, stop=stop)
        }
    except Exception:
        return {
            'error': {'code': 500, 'message': 'Internal server error'}
        }, 500


if __name__ == '__main__':
    server_address = ('', 8080)
    httpd = gevent.WSGIServer(server_address, app)
    httpd.serve_forever()
