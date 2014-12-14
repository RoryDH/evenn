ev = angular.module('evenn')

ev.controller('MainCtrl', [
  '$scope'
  '$http'
  '$location'
  'Facebook'
  ($scope, $http, $location, Facebook) ->
    $scope.user = {}

    goingToPath = $location.url()
    $location.url('/loading')

    Facebook.getLoginStatus (response) ->
      if response.status is 'connected'
        Facebook.api('/me', (response) ->
          $scope.user.fb = response
          $location.url('/select')
          bindRedirector()
        )
      else
        $location.url('/login')
        bindRedirector()

    bindRedirector = ->
      $scope.$on('$locationChangeStart', (e) ->
        if $scope.user.fb
          if $location.url() isnt '/select' and not $scope.user.events
            $location.url('/select')
        else
          $location.url('/login') unless _.contains(['/login', '/loading'], $location.url())
    )
])

ev.controller('LoginCtrl', [
  '$scope'
  '$http'
  '$location'
  'Facebook'
  ($scope, $http, $location, Facebook) ->
    $scope.login = ->
      Facebook.login((response) ->
        $location.url('/select') if response.status is 'connected'
      , { scope: 'user_events' })
])

ev.controller('SelectEventsCtrl', [
  '$scope'
  '$location'
  '$timeout'
  'Facebook'
  'FbEvent'
  ($scope, $location, $timeout, Facebook, FbEvent) ->

    Facebook.api('/me/events/attending',
      limit: 100
    , (events) ->
      $scope.availableEvents = events.data
    )

    selectedEvents = -> _.filter($scope.availableEvents, 'selected')
    $scope.updateSelectedEventCount = ->
      $scope.selectedEventCount = selectedEvents().length

    $scope.analyseEvents = ->
      selectedEvents = selectedEvents()
      $scope.loadingMessage = "Loading #{selectedEvents.length} events..."
      loadedCount = 0

      async.reduce(selectedEvents, {}, (memo, event, cb) ->
        memo[event.id] = new FbEvent(event, ->
          loadedCount += 1
          $scope.loadingMessage = "Loaded #{loadedCount} of #{selectedEvents.length}"
          cb(null, memo)
        )
      , (err, events) ->
        console.log events
        $scope.user.events = events
        $scope.user.eventIds = Object.keys(events)
        $scope.loadingMessage = "Event download complete. Please wait..."
        $timeout( ->
          $location.url('/')
          $scope.user.eventsReady = true
        , 1000)
      )
])

ev.controller('EventsHomeCtrl', [
  '$scope'
  ($scope) ->
])

ev.controller('TableCtrl', [
  '$scope'
  '$routeParams'
  'UserStore'
  ($scope, $routeParams, UserStore) ->
    rsvpStatuses =
      attending: 700
      unsure: 600
      not_replied: 500
      declined: 400
    $scope.rsvpMeta =
      colors:
        attending: 'success'
        declined: 'danger'
        unsure: 'warning'
        not_replied: 'active'
      words:
        attending: 'Going'
        declined: 'Not going'
        unsure: 'Maybe'
        not_replied: 'Invited'
    $scope.highlightId = $routeParams.highlight

    $scope.attendees = _.values(UserStore.users)
    $scope.attendees
    $scope.getScore = (attendee) ->
      _.reduce($scope.user.eventIds, (result, eventId, index) ->
        rsvpScore = rsvpStatuses[attendee.events[eventId]]
        if rsvpScore
          result + rsvpScore + (index + 1)
        else
          result
      , 0)

      
])

ev.controller('VennCtrl', [
  '$scope'
  ($scope) ->
])

ev.controller('GenderRatiosCtrl', [
  '$scope'
  ($scope) ->
])