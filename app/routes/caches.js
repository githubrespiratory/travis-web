import TravisRoute from 'travis/routes/basic';
import { service } from 'ember-decorators/service';

export default TravisRoute.extend({
  @service ajax: service(),

  needsAuth: true,

  setupController(/* controller*/) {
    this._super(...arguments);
    return this.controllerFor('repo').activate('caches');
  },

  model() {
    const repo = this.modelFor('repo');
    const url = `/repo/${repo.get('id')}/caches`;

    return this.get('ajax').getV3(url).then((data) => consolidateCaches(repo, data));
  },
});

function consolidateCaches(repo, data) {
  let consolidatedCaches = {};
  let pushes = [], pullRequests = [];

  data['caches'].forEach((cacheData) => {
    let branch = cacheData.branch;
    let consolidatedCache = consolidatedCaches[branch];

    if (consolidatedCache) {
      consolidatedCache.size += cacheData.size;

      if (consolidatedCache.last_modified < cacheData.last_modified) {
        consolidatedCache.last_modified = cacheData.last_modified;
      }
    } else {
      consolidatedCaches[branch] = cacheData;

      if (/PR./.test(branch)) {
        cacheData.type = 'pull_request';
        pullRequests.push(cacheData);
      } else {
        cacheData.type = 'push';
        pushes.push(cacheData);
      }
    }
  });

  return {
    repo,
    pushes,
    pullRequests,
  };
}
