# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/

map = null
$ ->
  if $("meta[name='context']").attr("content") == "incidents"
    google.maps.visualRefresh = true
    map = new google.maps.Map($('#map-canvas')[0], {
      zoom: 8,
      mapTypeId: google.maps.MapTypeId.ROADMAP
      })
      
    if navigator.geolocation
      navigator.geolocation.getCurrentPosition (position) ->
        pos = new google.maps.LatLng(position.coords.latitude, position.coords.longitude)
        map.setCenter(pos)
