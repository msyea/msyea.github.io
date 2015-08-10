---
---
$ ->
  for pair in location.search.substr(1).split('&')
    pair = pair.split('=')
    query[pair[0]] = decodeURIComponent(pair[1].replace('+', ' '))
  $('#search input[name=q]').val(query['q']) if query['q']
