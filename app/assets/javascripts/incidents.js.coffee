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
    visible_markers = {}
      
    if navigator.geolocation
      navigator.geolocation.getCurrentPosition (position) ->
        pos = new google.maps.LatLng(position.coords.latitude, position.coords.longitude)
        map.setCenter(pos)
        
    create_info_window = (incident, marker) ->
      info_window_content = $('.info-window.template').clone().removeClass('template')
      for field in ["city", "state", "occurred_at", "description"]
        info_window_content.find(".#{field}").html(incident[field])
      info_window = new google.maps.InfoWindow
      google.maps.event.addListener marker, 'click', ->
        info_window.setContent(info_window_content.html())
        info_window.open(map, marker)      
        
    google.maps.event.addListener map, 'idle', ->
      if map.getBounds()
        sent_data = {bounds: map.getBounds().toUrlValue()}
        $.getJSON $("meta[name='incidents_path']").attr("content"), sent_data, (incidents) ->
          touched_marker_ids = []
          for incident in incidents
            touched_marker_ids.push(incident._id)
            unless visible_markers[incident._id]
              marker = new google.maps.Marker {
                position: new google.maps.LatLng(incident.coordinates.reverse()...),
                map: map,
                title: "#{incident.city}, #{incident.state}: #{incident.description.slice(0, 15)}..."
              }
              create_info_window incident, marker
              visible_markers[incident._id] = marker
          stale_markers = _.chain(visible_markers).keys().difference(touched_marker_ids).value()
          for stale_marker in stale_markers
            visible_markers[stale_marker].setMap(null)
            delete visible_markers[stale_marker]
      
