sub vcl_recv {
  # Use the director
  set req.backend = balance;
  # Simplify variations to increase hit count
  if (req.http.Accept-Encoding) {
    # revisit this list
    if (req.url ~ "\.(jpg|png|gif|gz|tgz|bz2|tbz|mp3|ogg)$") {
      # No point in compressing these
      remove req.http.Accept-Encoding;
    } elsif (req.http.Accept-Encoding ~ "gzip") {
      set req.http.Accept-Encoding = "gzip";
    } elsif (req.http.Accept-Encoding ~ "deflate") {
      set req.http.Accept-Encoding = "deflate";
    } else {
      # unknown algorithm
      remove req.http.Accept-Encoding;
    }
  }
}
sub vcl_fetch {
  # Cache content for 30m beyond ttl in case backend is down
  if (! req.backend.healthy) {
    set req.grace = 30m;
  } else {
    set req.grace = 15s;
  }
  # Normalize namespaces for our domains
#  if (req.http.host ~ "(?i)^(www.)?domain.com") {
#    set req.http.host = "domain.com";
#  }
  # Force long ttl on heavy, static assets
  if (req.url ~ "\.(gif|jpg|jpeg|swf|css|js|flv|mp3|mp4|pdf|ico|png)(\?.*|)$") {
    set beresp.ttl = 1d;
  }
  # No need to relay cookies for static assets
  if (req.url ~ "\.(gif|jpg|jpeg|swf|css|js|flv|mp3|mp4|pdf|ico|png)(\?.*|)$") {
    unset req.http.cookie;
    set req.url = regsub(req.url, "\?.*$", "");
  }
  # gzip anything we can
  if (beresp.http.content-type ~ "text") {
    set beresp.do_gzip = true;
  }
}
sub vcl_deliver {
  # Set a header for easy identification in case of multiple frontends
  set resp.http.X-Served-By = server.hostname;
  # Set header to indicate cache hit/miss
  if (obj.hits > 0) {
    set resp.http.X-Cache = "HIT";
  } else {
    set resp.http.X-Cache = "MISS";
  }
}
