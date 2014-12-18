ev = angular.module('evenn')

ev.service('genderize', [
  '$http'
  ($http) ->
    shortGenders = { 'male': 'm', 'female': 'f' }
    resToGender = (response) ->
      if response
        if response.probability > 0.8
          shortGenders[response.gender]
        else
          'n'
      else
        null

    # ['rory', 'sarah', 'alex'] => ['m', 'f', 'n']
    getBulk: (names, cb) ->
      queryString = _.map(names, (name, index) -> "name[#{index}]=#{name}").join('&')
      $http.get("http://api.genderize.io?#{queryString}").success((data) ->
        cb(_.reduce(data, (memo, res) ->
          memo[res.name] = resToGender(res)
          memo
        , {}))
      )
])

ev.service('UserStore', [
  'genderize'
  (genderize) ->
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
        genderize.getBulk(Object.keys(namesToIds), (namesToGenders) ->
          _.forEach(namesToGenders, (gender, name) ->
            _.forEach(namesToIds[name], (id) -> self.users[id].gender = gender)
          )
          self.loadedGenders = true
          cb(self.users)
        )
])

ev.service('FbEvent', [
  'Facebook'
  'UserStore'
  (Facebook, UserStore) ->
    class FbEvent
      constructor: (fbObj, cb) ->
        self = @
        Facebook.api("/#{fbObj.id}", # Get more detailed event info
          fields: 'id,description,location,name,owner,privacy,start_time,timezone,updated_time,venue,cover'
        , (res) ->
          _.merge(self, res)
          self.invited = []
          Facebook.api("/#{self.id}/invited",
            fields: 'id,first_name,name,link,picture,rsvp_status,gender'
            limit: 1000
          , (res) ->
            self.invited = _.map(res.data, (userObj) ->
              UserStore.addUserObjByEvent(self.id, userObj)
            )
            cb(self)
          )
        )

      going: ->
        return @_going if @_going
        self = @
        @_going = _.filter(@invited, (user) ->
          user.events[self.id] is 'attending'
        )

      genderCounts: ->
        return @_counts if @_counts
        @_counts = _.countBy(@invited, 'gender')
        @_counts.ratio = Math.round(@_counts.f/@_counts.m * 100)/100
])
