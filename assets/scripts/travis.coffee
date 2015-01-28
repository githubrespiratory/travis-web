require 'ext/jquery'
require 'ext/ember/namespace'
require 'ext/ember/computed'
require 'app'

window.ENV ||= {}
window.ENV.RAISE_ON_DEPRECATION = true

Storage = Em.Object.extend
  init: ->
    @set('storage', {})
  key: (key) ->
    "__#{key.replace('.', '__')}"
  getItem: (k) ->
    return @get("storage.#{@key(k)}")
  setItem: (k,v) ->
    @set("storage.#{@key(k)}", v)
  removeItem: (k) ->
    @setItem(k, null)
  clear: ->
    @set('storage', {})

window.Travis = TravisApplication.create(
  LOG_ACTIVE_GENERATION: true,
  LOG_MODULE_RESOLVER: true,
  LOG_TRANSITIONS: true,
  LOG_TRANSITIONS_INTERNAL: true,
  LOG_VIEW_LOOKUPS: true
)

Travis.deferReadiness()

pages_endpoint   = $('meta[rel="travis.pages_endpoint"]').attr('href')
billing_endpoint = $('meta[rel="travis.billing_endpoint"]').attr('href')
customer_io_site_id = $('meta[name="travis.customer_io_site_id"]').attr('value')
setupCustomerio(customer_io_site_id) if customer_io_site_id

enterprise = $('meta[name="travis.enterprise"]').attr('value') == 'true'

# for now I set pro to true also for enterprise, but it should be changed
# to allow more granular config later
pro = $('meta[name="travis.pro"]').attr('value') == 'true' || enterprise

$.extend Travis,
  run: ->
    Travis.advanceReadiness() # bc, remove once merged to master

  config:
    syncingPageRedirectionTime: 5000
    api_endpoint:    $('meta[rel="travis.api_endpoint"]').attr('href')
    source_endpoint: $('meta[rel="travis.source_endpoint"]').attr('href')
    pusher_key:      $('meta[name="travis.pusher_key"]').attr('value')
    pusher_host:     $('meta[name="travis.pusher_host"]').attr('value')
    ga_code:         $('meta[name="travis.ga_code"]').attr('value')
    code_climate: $('meta[name="travis.code_climate"]').attr('value')
    ssh_key_enabled: $('meta[name="travis.ssh_key_enabled"]').attr('value') == 'true'
    code_climate_url: $('meta[name="travis.code_climate_url"]').attr('value')
    caches_enabled: $('meta[name="travis.caches_enabled"]').attr('value') == 'true'
    show_repos_hint: 'private'
    avatar_default_url: 'https://travis-ci.org/images/ui/default-avatar.png'
    pusher_log_fallback:  $('meta[name="travis.pusher_log_fallback"]').attr('value') == 'true'
    pro: pro
    enterprise: enterprise
    sidebar_support_box: pro && !enterprise

    pages_endpoint: pages_endpoint || billing_endpoint
    billing_endpoint: billing_endpoint

    url_legal:   "#{billing_endpoint}/pages/legal"
    url_imprint: "#{billing_endpoint}/pages/imprint"
    url_security: "#{billing_endpoint}/pages/security"
    url_terms:   "#{billing_endpoint}/pages/terms"
    customer_io_site_id: customer_io_site_id

  CONFIG_KEYS_MAP: {
    go:          'Go'
    rvm:         'Ruby'
    gemfile:     'Gemfile'
    env:         'ENV'
    jdk:         'JDK'
    otp_release: 'OTP Release'
    php:         'PHP'
    node_js:     'Node.js'
    perl:        'Perl'
    python:      'Python'
    scala:       'Scala'
    compiler:    'Compiler'
    ghc:         'GHC'
    os:          'OS'
    ruby:        'Ruby'
    xcode_sdk:   'Xcode SDK'
    xcode_scheme:'Xcode Scheme'
    d:           'D'
    julia:       'Julia'
    csharp:      'C#'
    dart:        'Dart'
  }

  QUEUES: [
    { name: 'linux',   display: 'Linux' }
    { name: 'mac_osx', display: 'Mac and OSX' }
  ]

  INTERVALS: { times: -1, updateTimes: 1000 }

sessionStorage = (->
  storage = null
  try
    # firefox will not throw error on access for sessionStorage var,
    # you need to actually get something from session
    sessionStorage.getItem('foo')
    storage = sessionStorage
  catch err
    storage = Storage.create()

  storage
)()

storage = (->
  storage = null
  try
    storage = window.localStorage || throw('no storage')
  catch err
    storage = Storage.create()

  storage
)()

Travis.initializer
  name: 'storage'

  initialize: (container, application) ->
    application.register 'storage:main', storage, { instantiate: false }
    application.register 'sessionStorage:main', sessionStorage, { instantiate: false }

    application.inject('auth', 'storage', 'storage:main')
    application.inject('auth', 'sessionStorage', 'sessionStorage:main')

    # I still use Travis.storage in some places which are not that easy to
    # refactor
    application.storage = storage
    application.sessionStorage = sessionStorage

Travis.initializer
  name: 'googleAnalytics'

  initialize: (container) ->
    if Travis.config.ga_code
      window._gaq = []
      _gaq.push(['_setAccount', Travis.config.ga_code])

      ga = document.createElement('script')
      ga.type = 'text/javascript'
      ga.async = true
      ga.src = 'https://ssl.google-analytics.com/ga.js'
      s = document.getElementsByTagName('script')[0]
      s.parentNode.insertBefore(ga, s)

Travis.initializer
  name: 'inject-config'

  initialize: (container, application) ->
    application.register 'config:main', Travis.config, { instantiate: false }

    application.inject('controller', 'config', 'config:main')
    application.inject('route', 'config', 'config:main')
    application.inject('auth', 'config', 'config:main')

Travis.initializer
  name: 'inject-pusher'

  initialize: (container, application) ->
    application.register 'pusher:main', Travis.pusher, { instantiate: false }

    application.inject('route', 'pusher', 'pusher:main')

    Travis.pusher.store = container.lookup('store:main')

stylesheetsManager = Ember.Object.create
  enable: (id) ->
    $("##{id}").removeAttr('disabled')

  disable: (id) ->
    $("##{id}").attr('disabled', 'disabled')

Travis.initializer
  name: 'inject-stylesheets-manager'

  initialize: (container, application) ->
    application.register 'stylesheetsManager:main', stylesheetsManager, { instantiate: false }

    application.inject('route', 'stylesheetsManager', 'stylesheetsManager:main')

Travis.Router.reopen
  didTransition: ->
    @_super.apply @, arguments

    if Travis.config.ga_code
      _gaq.push ['_trackPageview', location.pathname]

Ember.LinkView.reopen
  loadingClass: 'loading_link'

if charm_key = $('meta[name="travis.charm_key"]').attr('value')
  @__CHARM =
    key: $('meta[name="travis.charm_key"]').attr('value')
    url: "https://charmscout.herokuapp.com/feedback"

  $('head').append $('<script src="https://charmscout.herokuapp.com/charmeur.js?v=2" async defer></script>')

require 'travis/ajax'

Travis.ajax.pro = Travis.config.pro

require 'adapters/application'
require 'serializers/application'
require 'serializers/repo'
require 'serializers/job'
require 'serializers/build'
require 'serializers/account'
require 'serializers/request'
require 'serializers/env-var'
require 'adapters/env-var'
require 'adapters/ssh-key'
require 'transforms/object'
require 'store'
#require 'travis/adapter'
#require 'travis/adapters/env-vars'
#require 'travis/adapters/ssh-key'
require 'routes'
require 'auth'
require 'controllers'
require 'helpers'
require 'models'
require 'pusher'
require 'slider'
require 'tailing'
require 'templates'
require 'views'
require 'components'

require 'travis/instrumentation'

Travis.setup()
