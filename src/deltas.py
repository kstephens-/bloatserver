import re

import github
import packaging.version as version


class RepoBloat(object):

    def __init__(self, owner, repo):

        self.owner = owner
        self.repo_name = repo

        self.github = github.Github(per_page=100)
        self.repo = self.github.get_repo(f'{owner}/{repo}')

        self._asset_size = {}

    def get_bloat(self, start=None, stop=None):
        releases = self.get_releases(start=start, stop=stop)
        return self.get_asset_deltas(releases)

    def get_releases(self, start=None, stop=None):
        """ list releases in reverse chronological order. this will perform better
            when dealing with more recent releases since finding those would
            require fewer reqeusts
        """
        releases = self.repo.get_releases()
        relevant_releases = []

        begin = version.Version(stop) if stop is not None else stop
        end = version.Version(start) if start is not None else start

        record = False if begin is not None else True

        for release in releases:
            try:
                # this will filter helm chart release versions
                release_version = version.Version(release.tag_name)
            except version.InvalidVersion:
                continue

            if not record and release_version == begin:
                # when we find the end tag, start appending releases to the
                # relevant releases
                record = True

            if record:
                relevant_releases.append(release)

            if end is not None and release_version < end:
                # incude the release before the start release. this will allow
                # computing the initial delta. stop searching once this is found
                break
        return relevant_releases

    def get_asset_deltas(self, releases):
        """ compute deltas for each pair of releases
        """
        deltas = []

        # compute release deltas in pairwise fashion
        for i in range(len(releases)-1):
            release = releases[i]
            previous_release = releases[i+1]

            deltas.append({
                'tag': release.tag_name,
                'previous_tag': previous_release.tag_name,
                'delta': self.compute_asset_delta(release, previous_release)
            })
        return deltas

    def compute_asset_delta(self, release, previous_release):
        """ find the delta for a pair of releases
        """
        # seems to be some potential discrepency between the example
        # output and the prompt.
        # the prompt asks for % change, which I would have thought would be
        # computed as: ((release_size - previous_release_size) / previous_release_size) * 100
        # but the example output seems to be computed as:
        # 1 + ((release_size - previous_release_size) / previous_release_size)
        # implementing based on the example output
        release_size = self.get_asset_size(release)
        previous_release_size = self.get_asset_size(previous_release)

        difference = release_size - previous_release_size
        return 1 + (difference / previous_release_size)

    def get_asset_size(self, release):
        """ get the size for an asset and cache for the next computation
        """
        # for the general case, we're making the assumption that release
        # asset names follow the same pattern as the apache/airflow example
        # Note: this is totally untested on other repos
        asset_format = f'{self.owner}[_-]{self.repo_name}-{release.tag_name}\\.tar\\.gz'
        size = 0

        if release.tag_name in self._asset_size:
            size = self._asset_size[release.tag_name]
        else:
            for asset in release.assets:
                if re.match(asset_format, asset.name):
                    size = asset.size
                    self._asset_size[release.tag_name] = size
                    break
        return size


if __name__ == '__main__':

    # development test case
    rb = RepoBloat('apache', 'airflow')
    releases = rb.get_releases(start='2.8.3', stop='2.9.2')
    deltas = rb.get_asset_deltas(releases)
    print(deltas)
