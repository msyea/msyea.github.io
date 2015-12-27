---
---
$ ->
  hash = document.location.hash
  prefix = 'x-'
  $('.nav-tabs a[href='+hash.replace(prefix,'')+']').tab('show') if hash
  $('.nav-tabs a').on 'shown.bs.tab',
  (e) ->
    window.location.hash = e.target.hash.replace('#', '#' + prefix)

$ ->
  $.get 'https://api.flickr.com/services/rest', {
    method: 'flickr.photosets.getPhotos',
    api_key: 'cb182a89bedc6167adc3af4135f8aa7c',
    user_id: '137169348@N03',
    photoset_id: 72157662772567116,
    format: 'json',
    nojsoncallback: 1
    }, (d) ->
    console.log d
