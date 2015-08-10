$(function() {
  var query = {};
  location.search.substr(1).split('&').forEach(function(pair) {
    pair = pair.split('=');
    query[pair[0]] = decodeURIComponent(pair[1].replace('+', ' '));
  });
  if (query['q']) {
    $('#search input[name=q]').val(query['q']);
  }
});
