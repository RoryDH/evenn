ev = angular.module('evenn')

ev.service('genders', [
  '$http'
  ($http) ->
    # ['rory', 'sarah', 'alex'] => {'rory': 'm', 'sarah': 'f', 'alex': 'n'}
    getBulk: (names, cb) ->
      $http(
        method: 'POST'
        url: 'http://gender.rory.ie/bulk'
        data: { names: names }
      ).success((data) ->
        cb(data.names)
      )
])

ev.service('UserStore', [
  'genders'
  '$rootScope'
  (genders, $rootScope) ->
    class User
      constructor: (fbObj) ->
        @id = fbObj.id
        @name = fbObj.name
        @first_name = fbObj.first_name
        @link = fbObj.link
        @picture_url = fbObj.picture.data.url
        @events = {}

      addRsvp: (id, rsvp) ->
        @events[id] = rsvp

      getScore: ->
        return @_score unless @_score is undefined
        self = @
        @_score = _.reduce($rootScope.user.eventIds, (result, eventId, index) ->
          rsvpScore = $rootScope.rsvpMeta.points[self.events[eventId]]
          if rsvpScore
            i = Math.pow((index+2), 2)
            result + 10000 + (i*100) + (rsvpScore*i)
          else
            result
        , 0)
        @_score

    store =
      users: {}
      loadedGenders: false
      addUserObjByEvent: (eventId, userObj) ->
        userInstance = @users[userObj.id]
        unless userInstance
          userInstance = new User(userObj)
          @users[userObj.id] = userInstance
        userInstance.addRsvp(eventId, userObj.rsvp_status)
        userInstance
      getAllScores: ->
        _.forEach(@users, (user) -> user.calcScore())
      getAllGenders: (cb) ->
        self = @
        return cb(self.users) if @loadedGenders
        namesToIds = _.reduce(this.users, (memo, user) ->
          return unless user.first_name
          name = user.first_name.toLowerCase().trim().split(' ')[0]
          unless memo[name] then memo[name] = []
          memo[name].push(user.id)
          memo
        , {})
        genders.getBulk(Object.keys(namesToIds), (namesToGenders) ->
          _.forEach(namesToGenders, (gender, name) ->
            _.forEach(namesToIds[name], (id) -> self.users[id].gender = gender)
          )
          self.loadedGenders = true
          cb(self.users)
        )
      removeAll: ->
        self = @
        _.forEach(Object.keys(@users), (id) -> delete self.users[id])
])

ev.service('FbEvent', [
  'Facebook'
  'UserStore'
  (Facebook, UserStore) ->
    class FbEvent
      constructor: (fbObj, cb) ->
        @rsvpTypes = ['attending', 'declined', 'unsure', 'not_replied']
        self = @
        Facebook.api("/#{fbObj.id}", # Get more detailed event info
          fields: 'id,description,location,name,owner,privacy,start_time,timezone,updated_time,venue,cover'
        , (res) ->
          _.merge(self, res)
          self.invited = []
          Facebook.api("/#{self.id}/invited",
            fields: 'id,first_name,name,link,picture,rsvp_status,gender'
            limit: 5000
          , (res) ->
            self.invited = _.map(res.data, (userObj) ->
              UserStore.addUserObjByEvent(self.id, userObj)
            )
            self.invitedCount = self.invited.length
            cb(self)
          )
        )

      _usersWithRsvp: (rsvp) ->
        self = @
        _.filter(@invited, (user) ->
          user.events[self.id] is rsvp
        )

      _addRsvpGroups: ->
        self = @
        _.forEach(@rsvpTypes, (rsvp) ->
          self[rsvp] = self._usersWithRsvp(rsvp)
          self[rsvp + 'Count'] = self[rsvp].length
        )

      _genderCountsFor: (list) ->
        self = @
        # gender count
        gc = {f: 0, m: 0, n: 0}
        _.assign(gc, _.countBy(list, 'gender'))
        if gc.f is 0
          gc.ratio = 0
          gc.isFemaleToMale = true
        else if gc.m is 0
          gc.ratio = 0
          gc.isFemaleToMale = false
        else
          gc.isFemaleToMale = gc.f >= gc.m
          gc.ratio = gc.f/gc.m
          gc.ratio = 1/gc.ratio unless gc.isFemaleToMale
          gc.ratio = Math.round(gc.ratio * 100)/100
        _.forEach(['f', 'm', 'n'], (gender) ->
          gc["#{gender}Cent"] = Math.round((gc[gender] / self.invitedCount) * 1000)/10
        )
        gc

      generateAllEventStats: ->
        self = @
        @_addRsvpGroups()
        @genderCounts = _.reduce(['invited', 'attending'], (memo, rsvp) ->
          memo[rsvp] = self._genderCountsFor(self[rsvp])
          memo
        , {})
])
