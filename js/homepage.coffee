---
---
$ ->
  hash = document.location.hash
  prefix = 'x-'
  $('.nav-tabs a[href='+hash.replace(prefix,'')+']').tab('show') if hash
  $('.nav-tabs a').on 'shown.bs.tab',
  (e) ->
    window.location.hash = e.target.hash.replace('#', '#' + prefix)

setupGallery = ($node, galleryId) ->
  galleryId = if galleryId then galleryId else $node.data().id
  $.get 'https://api.flickr.com/services/rest', {
    method: 'flickr.photosets.getPhotos',
    api_key: 'cb182a89bedc6167adc3af4135f8aa7c',
    user_id: '137169348@N03',
    photoset_id: galleryId,
    format: 'json',
    nojsoncallback: '1',
    extras: 'description',
    media: 'photos'
    },
    (d) ->
      $node.find('.carousel-indicators').empty()
      $node.find('.carousel-inner').empty()
      d.photoset.photo.forEach (p, i) ->
        $node.find('.carousel-indicators').append $('<li/>', {
          'data-target': $node,
          'data-slide-to': i,
          'class': if !i then 'active' else ''
          })
        $node.find('.carousel-inner').append $('<div/>', {
          'class': if !i then 'item active' else 'item'
          }).append($('<img/>', {
            src: 'https://farm' + p.farm + '.staticflickr.com/' + p.server + '/'  + p.id + '_'  + p.secret + '_b.jpg',
            alt: p.title
            }),
            $('<div/>', {
              'class': 'carousel-caption'
              'html': '<h3><a href="https://www.flickr.com/photos/137169348@N03/'  + p.id + '/in/album-' + galleryId + '">' + p.title + '</a></h3><p>' + p.description._content + '</p>'
              }))

$ ->
  if $('#gallery').length
    setupGallery($('#gallery'))
