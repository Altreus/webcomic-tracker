#!/usr/bin/env perl
use Mojolicious::Lite -signatures;
use Mojo::Feed;
use Mojo::Date;
use Mojo::SQLite;

my $sqlite = Mojo::SQLite->new('comics.db');

get '/' => sub ($c) {
    my $comics = $sqlite->db->query('SELECT * FROM comic');

    my @comics;
    while (my $comic = $comics->hash) {
        my $feed = Mojo::Feed->new( url => $comic->{feed_url} );
        $feed->entries->each(sub {
            $sqlite->db->query('INSERT OR IGNORE INTO url (comic_name, url, pubdate, opened) VALUES (?,?,?,?)',
                $comic->{name}, $_->id, Mojo::Date->new($_->published)->to_datetime, 0
            );
        });

        push @comics, { name => $comic->{name} };
    }
    $c->stash( comics => \@comics );
    $c->render(template => 'index');
};

get '/goto' => sub ($c) {
    my $q = $sqlite->db->query(<<~'SQL', $c->param('comic'));
        SELECT * FROM url
        WHERE comic_name = ?
        AND opened = 1
        ORDER BY datetime(pubdate) DESC
        LIMIT 1
        SQL
    my $latest_entry = $q->hash;

    unless ($latest_entry) {
        # If no latest entry, none has been opened, so get the first one by date
        my $q = $sqlite->db->query(<<~'SQL', $c->param('comic'));
            SELECT * FROM url
            WHERE comic_name = ?
            ORDER BY datetime(pubdate) ASC LIMIT 1
            SQL
        $latest_entry = $q->hash;
    }

    # Set everything currently in the DB as opened.
    $sqlite->db->query(<<~'SQL', $c->param('comic'));
        UPDATE url SET opened = 1 WHERE comic_name = ?
        SQL

    # Redirect to the last-opened URL
    $c->redirect_to($latest_entry->{url});
};

app->start;
__DATA__

@@ index.html.ep
% layout 'default';
% title 'Welcome';
<h1>Welcome to the Mojolicious real-time web framework!</h1>
<% for my $c (@$comics) { %>
    <p><a href="/goto?comic=<%= $c->{name} %>"><%= $c->{name} %></a></p>
<% } %>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head><title><%= title %></title></head>
  <body><%= content %></body>
</html>
