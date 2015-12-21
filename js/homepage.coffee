---
---
$ ->
  hash = document.location.hash
  prefix = 'tab-'
  $('.nav-tabs a[href='+hash.replace(prefix,'')+']').tab('show') if hash
  $('.nav-tabs a').on 'shown.bs.tab',
  (e) ->
    window.location.hash = e.target.hash.replace('#', '#' + prefix)
