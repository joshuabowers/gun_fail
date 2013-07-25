# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/

map = null
$ ->
  if $("meta[name='context']").attr("content") == "incidents"
    google.maps.visualRefresh = true
    map = new google.maps.Map($('#map-canvas')[0], {
      zoom: 8,
      disableDefaultUI: true,
      mapTypeId: google.maps.MapTypeId.ROADMAP
      })
    visible_markers = {}
    info_windows = {}
    heatmap_data = new google.maps.MVCArray([])
    heatmap = new google.maps.visualization.HeatmapLayer({
      data: heatmap_data,
      radius: 35
    })
      
    if navigator.geolocation
      navigator.geolocation.getCurrentPosition (position) ->
        pos = new google.maps.LatLng(position.coords.latitude, position.coords.longitude)
        map.setCenter(pos)
    else
      # Google Maps geocoded center for the United States.
      map.setCenter(new google.maps.LatLng(37.09024, -95.712891))
      
    $("#markers-layer-toggle").change ->
      bound_map = if $("#markers-layer-toggle").prop("checked") then map else null
      _.each(visible_markers, (marker) -> marker.setMap(bound_map))
    $("#heatmap-layer-toggle").change ->
      bound_map = if $("#heatmap-layer-toggle").prop("checked") then map else null
      heatmap.setMap(bound_map)
        
    create_info_window = (location, incidents, marker) ->
      info_window_content = $('.info-window.template').clone().removeClass('template')
      incident_template = $('.incident.template').clone().removeClass('template')
      for field in ["formatted_address"]
        info_window_content.find(".#{field}").html(incidents[0][field])
      info_window_content.find(".number_of_incidents").html(incidents.length)
      for incident in incidents
        template = incident_template.clone()
        template.find(".occurred_at a").html(incident["occurred_at"]).attr("href", incident["source_url"])
        template.find(".description").html(incident["description"])
        info_window_content.find("dl").append(template.children().unwrap())
      info_window = new google.maps.InfoWindow {content: info_window_content.html()}
      info_windows[location] = false
      google.maps.event.addListener marker, 'click', ->
        info_windows[location] = !info_windows[location]
        unless info_windows[location]
          info_window.close()
        else
          info_window.open(map, marker)
      google.maps.event.addListener map, 'click', ->
        info_windows[location] = false
        info_window.close()
          
        
    google.maps.event.addListener map, 'idle', ->
      if map.getBounds()
        sent_data = {bounds: map.getBounds().toUrlValue()}
        $("#debug-info .zoom-level").html("Zoom Level: #{map.getZoom()}")
        $.getJSON $("meta[name='incidents_path']").attr("content"), sent_data, (clustered) ->
          touched_marker_coords = []
          for location, incidents of clustered
            touched_marker_coords.push(location)
            unless visible_markers[location]
              heatmap_data.push({location: new google.maps.LatLng(eval(location).reverse()...), weight: incidents.length})
              marker = new google.maps.Marker {
                position: new google.maps.LatLng(eval(location).reverse()...),
                map: if $("#markers-layer-toggle").prop("checked") then map else null,
                title: "Total incidents: #{incidents.length}"
              }
              create_info_window location, incidents, marker
              visible_markers[location] = marker
          # stale_markers = _.chain(visible_markers).keys().difference(touched_marker_ids).value()
          # for stale_marker in stale_markers
          #   visible_markers[stale_marker].setMap(null)
          #   delete visible_markers[stale_marker]
      
